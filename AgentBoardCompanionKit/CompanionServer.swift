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

/// Pure throttle rule for the transcript capture step (extracted so it's
/// testable without the actor/lock plumbing in `CompanionServer`).
enum TranscriptCaptureThrottle {
    static let interval: TimeInterval = 10

    static func shouldCapture(lastCaptureAt: Date?, now: Date) -> Bool {
        guard let lastCaptureAt else { return true }
        return now.timeIntervalSince(lastCaptureAt) >= interval
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
    /// Required by NWListener.start(queue:) and NWConnection.start(queue:).
    /// Network framework demands a DispatchQueue for its internal callbacks;
    /// handlers hop back via Task { await ... } where actor isolation is needed.
    private let queue = DispatchQueue(label: "com.agentboard.modern.companion")

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Guards mutable lifecycle state. The class is @unchecked Sendable because
    /// Network framework callbacks fire on `queue` while public API can be
    /// invoked from any actor; without this lock, start/stop/refresh-loop
    /// setter races (including a deinit racing with stop) could nil-deref the
    /// listener or leak the refresh task.
    private struct LifecycleState: Sendable {
        var listener: NWListener?
        var refreshTask: Task<Void, Never>?
        var lastTranscriptCaptureAt: Date?
    }

    private let lifecycle = OSAllocatedUnfairLock(initialState: LifecycleState())

    public init(
        configuration: CompanionServerConfiguration,
        store: CompanionSQLiteStore,
        probe: CompanionLocalProbe = CompanionLocalProbe()
    ) {
        self.configuration = configuration
        self.store = store
        self.probe = probe
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    deinit {
        // deinit is nonisolated and can fire on any thread — must use the lock
        // to safely tear down listener + refreshTask.
        let snapshot = lifecycle.withLock { state -> LifecycleState in
            let copy = state
            state.listener = nil
            state.refreshTask = nil
            return copy
        }
        snapshot.refreshTask?.cancel()
        snapshot.listener?.cancel()
    }

    public func start() throws {
        // Build the listener inside the lock so two concurrent start() calls
        // don't both create listeners. NWListener.start(queue:) is called
        // outside the lock since it doesn't touch our state.
        let listenerToStart: NWListener?
        do {
            listenerToStart = try lifecycle.withLock { state -> NWListener? in
                guard state.listener == nil else { return nil }
                let port = NWEndpoint.Port(rawValue: configuration.port) ?? 8742
                let newListener = try NWListener(using: .tcp, on: port)
                newListener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection: connection)
                }
                newListener.stateUpdateHandler = { [logger] state in
                    switch state {
                    case .ready:
                        logger.info("Companion server ready.")
                    case let .failed(error):
                        logger.error("Companion listener failed: \(error.localizedDescription, privacy: .public)")
                    default:
                        break
                    }
                }
                state.listener = newListener
                return newListener
            }
        } catch {
            throw error
        }
        guard let listener = listenerToStart else { return }
        listener.start(queue: queue)

        startRefreshLoop()
        Task { [weak self] in
            try? await self?.refreshProbeSnapshot()
        }
    }

    public func stop() {
        let snapshot = lifecycle.withLock { state -> LifecycleState in
            let copy = state
            state.listener = nil
            state.refreshTask = nil
            return copy
        }
        snapshot.refreshTask?.cancel()
        snapshot.listener?.cancel()
    }

    private func startRefreshLoop() {
        let task = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await self.refreshProbeSnapshot()
                try? await Task.sleep(for: .seconds(max(5, self.configuration.refreshInterval)))
            }
        }
        let previous = lifecycle.withLock { state -> Task<Void, Never>? in
            let prior = state.refreshTask
            state.refreshTask = task
            return prior
        }
        previous?.cancel()
    }

    private func refreshProbeSnapshot() async throws {
        let snapshot = await probe.snapshot()
        try await store.replaceSessions(snapshot.sessions)
        try await store.replaceAgents(snapshot.agents)
        await captureTranscriptsIfDue(sessions: snapshot.sessions)
        await broker.publish(CompanionEvent(kind: .sessionsChanged))
        await broker.publish(CompanionEvent(kind: .agentsChanged))
        await broker.publish(CompanionEvent(kind: .snapshotRefreshed))
    }

    /// Best-effort transcript capture: throttled to roughly once per
    /// `TranscriptCaptureThrottle.interval` regardless of how often the probe
    /// snapshot itself runs, and never allowed to block session/agent
    /// discovery — failures are logged and skipped.
    private func captureTranscriptsIfDue(sessions: [AgentSession]) async {
        let now = Date()
        let shouldCapture = lifecycle.withLock { state -> Bool in
            guard TranscriptCaptureThrottle.shouldCapture(lastCaptureAt: state.lastTranscriptCaptureAt, now: now) else {
                return false
            }
            state.lastTranscriptCaptureAt = now
            return true
        }
        guard shouldCapture else { return }

        for session in sessions {
            guard let content = await probe.captureOutput(for: session) else { continue }
            do {
                try await store.upsertTranscript(sessionID: session.id, content: content, isFinal: false)
            } catch {
                logger
                    .error(
                        "Failed to persist transcript for \(session.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
            }
        }

        do {
            try await store.finalizeTranscriptsExcept(activeSessionIDs: sessions.map(\.id))
        } catch {
            logger.error("Failed to finalize transcripts: \(error.localizedDescription, privacy: .public)")
        }
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
            try await route(request: request, over: connection)
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

    private func route(request: HTTPRequest, over connection: NWConnection) async throws {
        switch (request.method, request.pathComponents) {
        case ("GET", ["health"]):
            try sendJSON(["status": "ok"], over: connection)

        case ("GET", ["v1", "sessions"]):
            try sendJSON(await store.listSessions(), over: connection)

        case let (method, components)
            where components.count == 4 &&
            components[0] == "v1" &&
            components[1] == "sessions":
            try await handleSessionAction(
                method: method,
                sessionID: components[2],
                action: components[3],
                over: connection
            )

        case ("GET", ["v1", "agents"]):
            try sendJSON(await store.listAgents(), over: connection)

        case ("GET", ["v1", "conversations"]):
            try sendJSON(await store.listConversations(), over: connection)

        case let ("GET", components)
            where components.count == 4 &&
            components[0] == "v1" &&
            components[1] == "conversations" &&
            components[3] == "messages" &&
            UUID(uuidString: components[2]) != nil:
            try sendJSON(await store.loadMessages(conversationID: UUID(uuidString: components[2])!), over: connection)

        case ("POST", ["v1", "conversations", "sync"]):
            try await handleConversationAction(
                action: "sync",
                conversationID: nil,
                body: request.body,
                over: connection
            )

        case let ("DELETE", components)
            where components.count == 3 &&
            components[0] == "v1" &&
            components[1] == "conversations" &&
            UUID(uuidString: components[2]) != nil:
            try await store.deleteConversation(id: UUID(uuidString: components[2])!)
            try sendJSON(["ok": true], over: connection)
            await broker.publish(CompanionEvent(kind: .conversationsChanged))

        case let ("POST", components)
            where components.count == 4 &&
            components[0] == "v1" &&
            components[1] == "conversations" &&
            components[2] == "delete":
            try await handleConversationAction(
                action: "delete",
                conversationID: UUID(uuidString: components[3]),
                body: request.body,
                over: connection
            )

        case ("GET", ["v1", "events"]):
            await registerSSESubscriber(over: connection)

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
    }

    private func registerSSESubscriber(over connection: NWConnection) async {
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
    }

    // MARK: - Conversation Actions

    private func handleConversationAction(
        action: String,
        conversationID: UUID?,
        body: Data,
        over connection: NWConnection
    ) async throws {
        switch action {
        case "sync":
            guard let payload = try? decoder.decode(ConversationSyncPayload.self, from: body) else {
                try sendJSON(["error": "invalid_body"], over: connection)
                return
            }
            try await store.replaceConversations(payload.conversations)
            for conv in payload.conversations {
                if let messages = payload.messagesByConversation[conv.id] {
                    try await store.saveConversationSnapshot(
                        conversation: conv,
                        messages: messages
                    )
                }
            }
            try sendJSON(["ok": true], over: connection)
            await broker.publish(CompanionEvent(kind: .conversationsChanged))

        case "delete":
            guard let id = conversationID else {
                try sendJSON(["error": "invalid_id"], over: connection)
                return
            }
            try await store.deleteConversation(id: id)
            try sendJSON(["ok": true], over: connection)
            await broker.publish(CompanionEvent(kind: .conversationsChanged))

        default:
            try sendJSON(["error": "not_found"], over: connection)
        }
    }

    private func handleSessionAction(
        method: String,
        sessionID: String,
        action: String,
        over connection: NWConnection
    ) async throws {
        let sessions = try await store.listSessions()
        let session = sessions.first { $0.id == sessionID }
        switch (method, action) {
        case ("GET", "output"):
            let output: String
            if let session {
                output = await probe.captureOutput(for: session) ?? session.lastOutput ?? ""
            } else {
                output = ""
            }
            try sendJSON(["output": output], over: connection)
        case ("GET", "transcript"):
            if let transcript = try await store.transcript(sessionID: sessionID) {
                try sendJSON(
                    SessionTranscript(
                        content: transcript.content,
                        updatedAt: transcript.updatedAt,
                        isFinal: transcript.isFinal
                    ),
                    over: connection
                )
            } else {
                try sendJSON(["error": "not_found"], over: connection)
            }
        case ("POST", "nudge"):
            let ok: Bool
            if let session { ok = await probe.nudge(session: session) } else { ok = false }
            try sendJSON(["ok": ok], over: connection)
            await broker.publish(CompanionEvent(kind: .sessionsChanged))
        case ("POST", "stop"):
            let ok: Bool
            if let session { ok = await probe.stop(session: session) } else { ok = false }
            try sendJSON(["ok": ok], over: connection)
            await broker.publish(CompanionEvent(kind: .sessionsChanged))
        default:
            try sendJSON(["error": "not_found"], over: connection)
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
