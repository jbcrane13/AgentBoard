import Foundation

// MARK: - Sendable wrapper for untyped JSON

/// Wraps a `[String: Any]` dictionary so it can cross actor boundaries.
/// The underlying data came from JSONSerialization and is effectively immutable.
struct JSONPayload: @unchecked Sendable {
    let value: [String: Any]
    init(_ value: [String: Any]) { self.value = value }
    subscript(key: String) -> Any? { value[key] }
}

// MARK: - Gateway Event Types

struct GatewayEvent: @unchecked Sendable {
    let event: String
    let payload: [String: Any]
    let seq: Int?

    // Chat event helpers
    var isChatEvent: Bool { event == "chat" }
    var chatSessionKey: String? { payload["sessionKey"] as? String }
    var chatRunId: String? { payload["runId"] as? String }
    var chatState: String? { payload["state"] as? String }
    var chatErrorMessage: String? { payload["errorMessage"] as? String }

    var chatMessageText: String? {
        guard let message = payload["message"] as? [String: Any] else { return nil }
        return GatewayClient.extractText(from: message["content"])
    }
}

struct GatewaySession: Identifiable, Sendable {
    let id: String
    let key: String
    let label: String?
    let agentId: String?
    let model: String?
    let status: String?
    let lastActiveAt: Date?
    let thinkingLevel: String?
}

struct GatewayAgentIdentity: Sendable {
    let agentId: String?
    let name: String
    let avatar: String?
}

struct GatewayChatHistory: Sendable {
    let messages: [GatewayChatMessage]
    let thinkingLevel: String?
}

struct GatewayChatMessage: Sendable {
    let role: String
    let text: String
    let timestamp: Date?
}

// MARK: - Gateway Client

enum GatewayClientError: LocalizedError {
    case notConnected
    case connectionFailed(String)
    case requestFailed(String)
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to OpenClaw gateway."
        case .connectionFailed(let reason):
            return "Gateway connection failed: \(reason)"
        case .requestFailed(let message):
            return message
        case .timeout:
            return "Gateway request timed out."
        case .invalidResponse:
            return "Invalid response from gateway."
        }
    }
}

actor GatewayClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var pendingRequests: [String: CheckedContinuation<JSONPayload, Error>] = [:]
    private var eventContinuation: AsyncStream<GatewayEvent>.Continuation?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    private let session: URLSession

    private(set) var isConnected = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Connect to the gateway WebSocket and perform the connect handshake.
    func connect(url: URL, token: String?) async throws {
        disconnect()

        // Build WebSocket URL (same port, ws:// scheme)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch components?.scheme {
        case "https": components?.scheme = "wss"
        case "http": components?.scheme = "ws"
        case "wss", "ws": break
        default: components?.scheme = "ws"
        }
        // Connect to root path — gateway multiplexes HTTP and WS on the same port
        components?.path = ""

        guard let wsURL = components?.url else {
            throw GatewayClientError.connectionFailed("Invalid gateway URL")
        }

        var wsRequest = URLRequest(url: wsURL)
        wsRequest.timeoutInterval = 15

        // The gateway validates the Origin header on WebSocket upgrade.
        // URLSessionWebSocketTask does not set one by default, so we must
        // provide it explicitly using the gateway's own origin.
        if let origin = components.flatMap({ c -> URL? in
            var o = URLComponents()
            o.scheme = (c.scheme == "wss") ? "https" : "http"
            o.host = c.host
            o.port = c.port
            return o.url
        }) {
            wsRequest.setValue(origin.absoluteString, forHTTPHeaderField: "Origin")
        }

        let task = session.webSocketTask(with: wsRequest)
        task.maximumMessageSize = 16 * 1024 * 1024
        task.resume()
        webSocketTask = task

        // Start receiving messages before the handshake so we catch the
        // connect.challenge event (informational — the gateway does not
        // require the nonce to be echoed back in connect params).
        startReceiving()

        // Send connect handshake
        var connectParams: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "webchat",
                "version": "1.0",
                "platform": "macOS",
                "mode": "webchat",
                "displayName": "AgentBoard",
            ],
            "role": "operator",
            "scopes": ["operator.admin"],
        ]

        if let token, !token.isEmpty {
            connectParams["auth"] = ["token": token]
        }

        let hello = try await request("connect", params: connectParams)
        _ = hello // Hello payload received — connection is established
        isConnected = true

        // Start periodic ping to keep connection alive
        startPingLoop()
    }

    /// Disconnect from the gateway.
    func disconnect() {
        isConnected = false
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        // Fail all pending requests
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: GatewayClientError.notConnected)
        }
        pendingRequests.removeAll()
    }

    // MARK: - RPC

    /// Send a JSON-RPC request and wait for the response.
    func request(_ method: String, params: [String: Any]) async throws -> [String: Any] {
        guard let task = webSocketTask else {
            throw GatewayClientError.notConnected
        }

        let requestId = UUID().uuidString

        let message: [String: Any] = [
            "type": "req",
            "id": requestId,
            "method": method,
            "params": params,
        ]

        let data = try JSONSerialization.data(withJSONObject: message)
        let string = String(data: data, encoding: .utf8) ?? ""

        try await task.send(.string(string))

        let wrapped: JSONPayload = try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation
        }
        return wrapped.value
    }

    // MARK: - Event Stream

    /// Async stream of gateway events (chat, agent, presence, etc.)
    var events: AsyncStream<GatewayEvent> {
        AsyncStream { continuation in
            eventContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    await self?.clearEventContinuation()
                }
            }
        }
    }

    private func clearEventContinuation() {
        eventContinuation = nil
    }

    // MARK: - Convenience Methods

    /// Send a chat message to a session.
    func sendChat(sessionKey: String, message: String) async throws {
        let idempotencyKey = UUID().uuidString
        _ = try await request("chat.send", params: [
            "sessionKey": sessionKey,
            "message": message,
            "deliver": false,
            "idempotencyKey": idempotencyKey,
        ])
    }

    /// Load chat history for a session.
    func chatHistory(sessionKey: String, limit: Int = 200) async throws -> GatewayChatHistory {
        let payload = try await request("chat.history", params: [
            "sessionKey": sessionKey,
            "limit": limit,
        ])

        let thinkingLevel = payload["thinkingLevel"] as? String

        var messages: [GatewayChatMessage] = []
        if let rawMessages = payload["messages"] as? [[String: Any]] {
            for raw in rawMessages {
                let role = raw["role"] as? String ?? "system"
                let text = GatewayClient.extractText(from: raw["content"]) ?? ""
                let timestamp: Date?
                if let ts = raw["timestamp"] as? TimeInterval {
                    timestamp = Date(timeIntervalSince1970: ts / 1000)
                } else if let ts = raw["timestamp"] as? Int {
                    timestamp = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
                } else {
                    timestamp = nil
                }
                messages.append(GatewayChatMessage(role: role, text: text, timestamp: timestamp))
            }
        }

        return GatewayChatHistory(messages: messages, thinkingLevel: thinkingLevel)
    }

    /// Abort a running chat generation.
    func abortChat(sessionKey: String, runId: String? = nil) async throws {
        var params: [String: Any] = ["sessionKey": sessionKey]
        if let runId {
            params["runId"] = runId
        }
        _ = try await request("chat.abort", params: params)
    }

    /// List gateway sessions.
    func listSessions(activeMinutes: Int? = nil, limit: Int? = nil) async throws -> [GatewaySession] {
        var params: [String: Any] = [
            "includeGlobal": true,
            "includeUnknown": false,
        ]
        if let activeMinutes {
            params["activeMinutes"] = activeMinutes
        }
        if let limit {
            params["limit"] = limit
        }

        let payload = try await request("sessions.list", params: params)

        var sessions: [GatewaySession] = []
        if let rawSessions = payload["sessions"] as? [[String: Any]] {
            for raw in rawSessions {
                let key = raw["key"] as? String ?? raw["id"] as? String ?? ""
                guard !key.isEmpty else { continue }
                sessions.append(GatewaySession(
                    id: key,
                    key: key,
                    label: raw["label"] as? String,
                    agentId: raw["agentId"] as? String,
                    model: raw["model"] as? String,
                    status: raw["status"] as? String,
                    lastActiveAt: parseTimestamp(raw["lastActiveAt"] ?? raw["updatedAt"]),
                    thinkingLevel: raw["thinkingLevel"] as? String
                ))
            }
        }

        return sessions
    }

    /// Patch session settings (thinking level, etc.)
    func patchSession(key: String, thinkingLevel: String?) async throws {
        var params: [String: Any] = ["key": key]
        if let thinkingLevel {
            params["thinkingLevel"] = thinkingLevel
        } else {
            params["thinkingLevel"] = NSNull()
        }
        _ = try await request("sessions.patch", params: params)
    }

    /// Get agent identity for a session.
    func agentIdentity(sessionKey: String? = nil) async throws -> GatewayAgentIdentity {
        var params: [String: Any] = [:]
        if let sessionKey {
            params["sessionKey"] = sessionKey
        }

        let payload = try await request("agent.identity.get", params: params)
        return GatewayAgentIdentity(
            agentId: payload["agentId"] as? String,
            name: payload["name"] as? String ?? "Assistant",
            avatar: payload["avatar"] as? String
        )
    }

    // MARK: - Private

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    guard let task = await self.webSocketTask else { break }
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        await self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            await self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        await self.handleDisconnect()
                    }
                    break
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "res":
            handleResponse(json)

        case "event":
            handleEvent(json)

        default:
            break
        }
    }

    private func handleResponse(_ json: [String: Any]) {
        guard let id = json["id"] as? String,
              let continuation = pendingRequests.removeValue(forKey: id) else {
            return
        }

        let ok = json["ok"] as? Bool ?? false
        if ok {
            let payload = json["payload"] as? [String: Any] ?? [:]
            continuation.resume(returning: JSONPayload(payload))
        } else {
            let error = json["error"] as? [String: Any]
            let message = error?["message"] as? String ?? "Request failed"
            continuation.resume(throwing: GatewayClientError.requestFailed(message))
        }
    }

    private func handleEvent(_ json: [String: Any]) {
        guard let event = json["event"] as? String else { return }
        let payload = json["payload"] as? [String: Any] ?? [:]
        let seq = json["seq"] as? Int

        // connect.challenge is informational — no action needed
        if event == "connect.challenge" {
            return
        }

        let gatewayEvent = GatewayEvent(event: event, payload: payload, seq: seq)
        eventContinuation?.yield(gatewayEvent)
    }

    private func handleDisconnect() {
        isConnected = false
        // Fail all pending requests
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: GatewayClientError.notConnected)
        }
        pendingRequests.removeAll()
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                guard let self, !Task.isCancelled else { break }
                guard let task = await self.webSocketTask else { break }
                task.sendPing { error in
                    if error != nil {
                        Task { await self.handleDisconnect() }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Extract text from a gateway message content field (string or array of parts).
    static func extractText(from content: Any?) -> String? {
        if let str = content as? String {
            return str
        }
        if let parts = content as? [[String: Any]] {
            let texts = parts.compactMap { part -> String? in
                guard part["type"] as? String == "text" else { return nil }
                return part["text"] as? String
            }
            return texts.isEmpty ? nil : texts.joined(separator: "\n")
        }
        return nil
    }

    private func parseTimestamp(_ value: Any?) -> Date? {
        if let ms = value as? TimeInterval {
            return Date(timeIntervalSince1970: ms > 1e12 ? ms / 1000 : ms)
        }
        if let ms = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(ms) > 1e12 ? TimeInterval(ms) / 1000 : TimeInterval(ms))
        }
        if let text = value as? String, let ts = TimeInterval(text) {
            return Date(timeIntervalSince1970: ts > 1e12 ? ts / 1000 : ts)
        }
        return nil
    }
}
