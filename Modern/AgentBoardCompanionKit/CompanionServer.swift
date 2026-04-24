import AgentBoardCore
import Foundation
@preconcurrency import Network
import os

public struct CompanionServerConfiguration: Codable, Sendable {
    public var host: String
    public var port: UInt16
    public var bearerToken: String?
    public var databasePath: String
    public var refreshInterval: TimeInterval

    public init(
        host: String = "0.0.0.0",
        port: UInt16 = 8742,
        bearerToken: String? = nil,
        databasePath: String,
        refreshInterval: TimeInterval = 15
    ) {
        self.host = host
        self.port = port
        self.bearerToken = bearerToken
        self.databasePath = databasePath
        self.refreshInterval = refreshInterval
    }

    public var baseURL: String {
        "http://127.0.0.1:\(port)"
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    var pathComponents: [String] {
        path
            .split(separator: "/")
            .map(String.init)
    }

    static func parse(from data: Data) -> HTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator),
              let headerString = String(data: data[..<range.lowerBound], encoding: .utf8) else {
            return nil
        }

        let bodyStart = range.upperBound
        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            headers[String(parts[0]).lowercased()] = String(parts[1]).trimmingCharacters(in: .whitespaces)
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard data.count >= bodyStart + contentLength else { return nil }

        let body = Data(data[bodyStart ..< bodyStart + contentLength])
        return HTTPRequest(
            method: String(requestParts[0]),
            path: String(requestParts[1]),
            headers: headers,
            body: body
        )
    }
}

private struct HTTPResponse {
    let statusCode: Int
    let reason: String
    let headers: [String: String]
    let body: Data

    func serialized() -> Data {
        var output = "HTTP/1.1 \(statusCode) \(reason)\r\n"
        for (key, value) in headers {
            output += "\(key): \(value)\r\n"
        }
        output += "Content-Length: \(body.count)\r\n\r\n"

        var data = Data(output.utf8)
        data.append(body)
        return data
    }
}

private final class SSESubscriber: @unchecked Sendable {
    let id = UUID()
    private let connection: NWConnection
    private let encoder: JSONEncoder

    init(connection: NWConnection) {
        self.connection = connection
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func send(event: CompanionEvent) {
        guard let payload = try? encoder.encode(event) else { return }
        var data = Data("data: ".utf8)
        data.append(payload)
        data.append(Data("\n\n".utf8))
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func close() {
        connection.cancel()
    }
}

private actor CompanionEventBroker {
    private var subscribers: [UUID: SSESubscriber] = [:]

    func register(_ subscriber: SSESubscriber) {
        subscribers[subscriber.id] = subscriber
    }

    func unregister(id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    func publish(_ event: CompanionEvent) {
        for subscriber in subscribers.values {
            subscriber.send(event: event)
        }
    }
}

public final class CompanionServer: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "CompanionServer")
    private let configuration: CompanionServerConfiguration
    private let store: CompanionSQLiteStore
    private let probe: CompanionLocalProbe
    private let broker = CompanionEventBroker()
    private let queue = DispatchQueue(label: "com.agentboard.modern.companion")

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var listener: NWListener?
    private var refreshTask: Task<Void, Never>?

    public init(
        configuration: CompanionServerConfiguration,
        store: CompanionSQLiteStore,
        probe: CompanionLocalProbe = CompanionLocalProbe()
    ) {
        self.configuration = configuration
        self.store = store
        self.probe = probe
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    deinit {
        stop()
    }

    public func start() throws {
        guard listener == nil else { return }

        let port = NWEndpoint.Port(rawValue: configuration.port) ?? 8742
        let listener = try NWListener(using: .tcp, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection: connection)
        }
        listener.stateUpdateHandler = { [logger] state in
            switch state {
            case .ready:
                logger.info("Companion server ready.")
            case let .failed(error):
                logger.error("Companion listener failed: \(error.localizedDescription, privacy: .public)")
            default:
                break
            }
        }
        listener.start(queue: queue)
        self.listener = listener

        startRefreshLoop()
        Task { [weak self] in
            try? await self?.refreshProbeSnapshot()
        }
    }

    public func stop() {
        refreshTask?.cancel()
        listener?.cancel()
        listener = nil
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await self.refreshProbeSnapshot()
                try? await Task.sleep(for: .seconds(max(5, self.configuration.refreshInterval)))
            }
        }
    }

    private func refreshProbeSnapshot() async throws {
        let tasks = try await store.listTasks()
        let snapshot = await probe.snapshot(tasks: tasks)
        try await store.replaceSessions(snapshot.sessions)
        try await store.replaceAgents(snapshot.agents)
        await broker.publish(CompanionEvent(kind: .sessionsChanged))
        await broker.publish(CompanionEvent(kind: .agentsChanged))
        await broker.publish(CompanionEvent(kind: .snapshotRefreshed))
    }

    private func accept(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection
            .receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
                guard let self else {
                    connection.cancel()
                    return
                }

                var combined = buffer
                if let content {
                    combined.append(content)
                }

                if let request = HTTPRequest.parse(from: combined) {
                    Task { [weak self] in
                        await self?.respond(to: request, over: connection)
                    }
                    return
                }

                if isComplete || error != nil {
                    connection.cancel()
                    return
                }

                self.receiveRequest(on: connection, buffer: combined)
            }
    }

    private func respond(to request: HTTPRequest, over connection: NWConnection) async {
        guard isAuthorized(request) else {
            send(
                response: HTTPResponse(
                    statusCode: 401,
                    reason: "Unauthorized",
                    headers: ["Content-Type": "application/json"],
                    body: Data(#"{"error":"unauthorized"}"#.utf8)
                ),
                over: connection
            )
            return
        }

        do {
            switch (request.method, request.pathComponents) {
            case ("GET", ["health"]):
                try sendJSON(["status": "ok"], over: connection)

            case ("GET", ["v1", "tasks"]):
                try sendJSON(await store.listTasks(), over: connection)

            case ("POST", ["v1", "tasks"]):
                let draft = try decoder.decode(AgentTaskDraft.self, from: request.body)
                let task = try await store.createTask(draft)
                try sendJSON(task, over: connection)
                await broker.publish(CompanionEvent(kind: .tasksChanged))

            case let ("PATCH", components)
                where components.count == 3 &&
                components[0] == "v1" &&
                components[1] == "tasks":
                let id = components[2]
                let patch = try decoder.decode(AgentTaskPatch.self, from: request.body)
                let task = try await store.updateTask(id: id, patch: patch)
                try sendJSON(task, over: connection)
                await broker.publish(CompanionEvent(kind: .tasksChanged))

            case ("GET", ["v1", "sessions"]):
                try sendJSON(await store.listSessions(), over: connection)

            case ("GET", ["v1", "agents"]):
                try sendJSON(await store.listAgents(), over: connection)

            case ("GET", ["v1", "events"]):
                let subscriber = SSESubscriber(connection: connection)
                connection.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .cancelled, .failed:
                        Task { await self?.broker.unregister(id: subscriber.id) }
                    default:
                        break
                    }
                }
                sendSSEHeaders(over: connection)
                await broker.register(subscriber)
                subscriber.send(event: CompanionEvent(kind: .snapshotRefreshed))

            default:
                send(
                    response: HTTPResponse(
                        statusCode: 404,
                        reason: "Not Found",
                        headers: ["Content-Type": "application/json"],
                        body: Data(#"{"error":"not_found"}"#.utf8)
                    ),
                    over: connection
                )
            }
        } catch {
            logger.error("Companion request failed: \(error.localizedDescription, privacy: .public)")
            send(
                response: HTTPResponse(
                    statusCode: 500,
                    reason: "Server Error",
                    headers: ["Content-Type": "application/json"],
                    body: Data(#"{"error":"internal_server_error"}"#.utf8)
                ),
                over: connection
            )
        }
    }

    private func isAuthorized(_ request: HTTPRequest) -> Bool {
        guard let token = configuration.bearerToken?.trimmedOrNil else { return true }
        return request.headers["authorization"] == "Bearer \(token)"
    }

    private func sendJSON<Value: Encodable>(_ value: Value, over connection: NWConnection) throws {
        let body = try encoder.encode(value)
        send(
            response: HTTPResponse(
                statusCode: 200,
                reason: "OK",
                headers: ["Content-Type": "application/json"],
                body: body
            ),
            over: connection
        )
    }

    private func sendSSEHeaders(over connection: NWConnection) {
        let header = HTTPResponse(
            statusCode: 200,
            reason: "OK",
            headers: [
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive"
            ],
            body: Data()
        ).serialized()

        connection.send(content: header, completion: .contentProcessed { _ in })
    }

    private func send(response: HTTPResponse, over connection: NWConnection) {
        connection.send(content: response.serialized(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
