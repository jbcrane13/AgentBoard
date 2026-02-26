import Foundation
import OSLog

private let gatewayLog = Logger(subsystem: "com.agentboard.gateway", category: "GatewayClient")

struct JSONPayload: @unchecked Sendable {
    let value: [String: Any]
    init(_ value: [String: Any]) { self.value = value }
    subscript(key: String) -> Any? { value[key] }
}

struct GatewayEvent: @unchecked Sendable {
    let event: String
    let payload: [String: Any]
    let seq: Int?

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
    private var requestTimeoutTasks: [String: Task<Void, Never>] = [:]
    private var eventSubscribers: [UUID: AsyncStream<GatewayEvent>.Continuation] = [:]
    private var pendingConnectChallenge: CheckedContinuation<String, Error>?
    private var bufferedConnectChallengeNonce: String?
    private var connectChallengeTimeoutTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var tickWatchdogTask: Task<Void, Never>?

    /// Tracks if we're in a reconnecting state (transient disconnect)
    private(set) var isReconnecting = false

    /// Sequence number for event ordering - used to detect missed events on reconnect
    private var lastEventSeq: Int?
    private var lastInboundMessageAt: Date?
    private var tickIntervalMs: Double = 30_000

    private let session: URLSession
    private let connectChallengeTimeoutSeconds: Double = 6
    private let connectRequestTimeoutSeconds: Double = 12
    private let defaultRequestTimeoutSeconds: Double = 15

    private(set) var isConnected = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    func connect(url: URL, token: String?) async throws {
        // On reconnect, don't call disconnect() which finishes subscribers
        // Instead, just clean up the socket without touching subscribers
        if isConnected || isReconnecting {
            gatewayLog.info("Reconnecting to gateway (wasConnected=\(self.isConnected), wasReconnecting=\(self.isReconnecting))")
            receiveTask?.cancel()
            receiveTask = nil
            pingTask?.cancel()
            pingTask = nil
            tickWatchdogTask?.cancel()
            tickWatchdogTask = nil
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            isConnected = false
        } else {
            gatewayLog.info("Connecting to gateway at \(url.absoluteString, privacy: .public)")
        }

        resetConnectChallengeState()

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch components?.scheme {
        case "https": components?.scheme = "wss"
        case "http": components?.scheme = "ws"
        case "wss", "ws": break
        default: components?.scheme = "ws"
        }
        components?.path = ""

        guard let wsURL = components?.url else {
            throw GatewayClientError.connectionFailed("Invalid gateway URL")
        }

        var wsRequest = URLRequest(url: wsURL)
        wsRequest.timeoutInterval = 15

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

        startReceiving()
        do {
            let nonce = try await waitForConnectChallenge(timeoutSeconds: connectChallengeTimeoutSeconds)

            let identity = DeviceIdentity.loadOrCreate()
            let role = "operator"
            let scopes = ["operator.read", "operator.write", "operator.admin"]
            let clientId = "webchat"
            let clientMode = "webchat"
            let signedAtMs = Int64(Date().timeIntervalSince1970 * 1000)

            let payload = identity.buildAuthPayload(
                clientId: clientId,
                clientMode: clientMode,
                role: role,
                scopes: scopes,
                signedAtMs: signedAtMs,
                token: token,
                nonce: nonce
            )
            let signature = identity.sign(payload: payload)

            var connectParams: [String: Any] = [
                "minProtocol": 3,
                "maxProtocol": 3,
                "client": [
                    "id": clientId,
                    "version": "1.0",
                    "platform": "macOS",
                    "mode": clientMode,
                    "displayName": "AgentBoard",
                ],
                "device": [
                    "id": identity.deviceId,
                    "publicKey": identity.publicKeyBase64Url,
                    "signature": signature,
                    "signedAt": signedAtMs,
                    "nonce": nonce,
                ] as [String: Any],
                "role": role,
                "scopes": scopes,
            ]

            if let token, !token.isEmpty {
                connectParams["auth"] = ["token": token]
            }

            let hello = try await request(
                "connect",
                params: connectParams,
                timeoutSeconds: connectRequestTimeoutSeconds
            )
            updateConnectionPolicy(from: hello)
            isConnected = true
            isReconnecting = false  // Clear reconnecting flag on successful connect
            lastInboundMessageAt = Date()
            gatewayLog.notice("Successfully connected to gateway")

            startPingLoop()
            startTickWatchdog()
        } catch {
            cleanupAfterFailedConnect(error: error)
            throw error
        }
    }

    func disconnect() {
        gatewayLog.notice("Disconnecting from gateway (user-initiated)")
        isConnected = false
        isReconnecting = false
        cleanupTransport(error: GatewayClientError.notConnected, closeCode: .normalClosure)
        // Only finish subscribers on explicit disconnect (user action)
        finishAllEventSubscribers()
    }

    func request(
        _ method: String,
        params: [String: Any],
        timeoutSeconds: Double? = nil
    ) async throws -> [String: Any] {
        guard webSocketTask != nil else {
            throw GatewayClientError.notConnected
        }

        let requestId = UUID().uuidString
        let effectiveTimeout = timeoutSeconds ?? defaultRequestTimeoutSeconds

        let message: [String: Any] = [
            "type": "req",
            "id": requestId,
            "method": method,
            "params": params,
        ]

        let data = try JSONSerialization.data(withJSONObject: message)
        let string = String(data: data, encoding: .utf8) ?? ""

        let wrapped: JSONPayload = try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation
            requestTimeoutTasks[requestId] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
                await self?.timeoutRequest(requestId)
            }
            Task { [weak self] in
                await self?.sendRequestMessage(string, requestId: requestId)
            }
        }
        return wrapped.value
    }

    /// Returns a new AsyncStream that receives all gateway events.
    /// Multiple callers can subscribe simultaneously - each receives a unique stream
    /// and events are broadcast to all active subscribers.
    var events: AsyncStream<GatewayEvent> {
        let subscriberId = UUID()

        return AsyncStream { continuation in
            self.eventSubscribers[subscriberId] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    await self?.removeEventSubscriber(id: subscriberId)
                }
            }
        }
    }

    private func removeEventSubscriber(id: UUID) {
        eventSubscribers.removeValue(forKey: id)
    }

    private func broadcastEvent(_ event: GatewayEvent) {
        if eventSubscribers.isEmpty {
            gatewayLog.debug("Event '\(event.event, privacy: .public)' received but no subscribers to receive it")
        }
        for (_, continuation) in eventSubscribers {
            continuation.yield(event)
        }
    }

    /// Finishes all event subscriber streams and clears the subscriber dictionary.
    /// Called only on explicit disconnect (user action), not on transient disconnects.
    private func finishAllEventSubscribers() {
        for (_, continuation) in eventSubscribers {
            continuation.finish()
        }
        eventSubscribers.removeAll()
    }

    func sendChat(sessionKey: String, message: String, thinking: String? = nil) async throws {
        let idempotencyKey = UUID().uuidString
        var params: [String: Any] = [
            "sessionKey": sessionKey,
            "message": message,
            "deliver": false,
            "idempotencyKey": idempotencyKey,
        ]
        if let thinking {
            params["thinking"] = thinking
        }
        _ = try await request("chat.send", params: params)
    }

    func chatHistory(sessionKey: String, limit: Int = 200) async throws -> GatewayChatHistory {
        let payload = try await request("chat.history", params: [
            "sessionKey": sessionKey,
            "limit": limit,
        ])
        return try Self.decodeChatHistoryPayload(payload)
    }

    func abortChat(sessionKey: String, runId: String? = nil) async throws {
        var params: [String: Any] = ["sessionKey": sessionKey]
        if let runId {
            params["runId"] = runId
        }
        _ = try await request("chat.abort", params: params)
    }

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

        return try Self.decodeSessionsPayload(payload)
    }

    func createSession(
        label: String? = nil,
        projectPath: String? = nil,
        agentType: String? = nil,
        beadId: String? = nil,
        prompt: String? = nil
    ) async throws -> GatewaySession {
        var chatParams: [String: Any] = [:]
        if let label { chatParams["sessionLabel"] = label }
        if let prompt { chatParams["message"] = prompt }
        if let agentType { chatParams["agentId"] = agentType }

        let payload = try await request("chat.send", params: chatParams)
        let key = payload["sessionKey"] as? String
            ?? payload["key"] as? String
            ?? payload["id"] as? String
            ?? UUID().uuidString
        return GatewaySession(
            id: key,
            key: key,
            label: payload["label"] as? String ?? label,
            agentId: payload["agentId"] as? String ?? agentType,
            model: payload["model"] as? String,
            status: "active",
            lastActiveAt: Date(),
            thinkingLevel: payload["thinkingLevel"] as? String
        )
    }

    func patchSession(key: String, thinkingLevel: String?) async throws {
        var params: [String: Any] = ["key": key]
        if let thinkingLevel {
            params["thinkingLevel"] = thinkingLevel
        } else {
            params["thinkingLevel"] = NSNull()
        }
        _ = try await request("sessions.patch", params: params)
    }

    func agentIdentity(sessionKey: String? = nil) async throws -> GatewayAgentIdentity {
        var params: [String: Any] = [:]
        if let sessionKey {
            params["sessionKey"] = sessionKey
        }

        let payload = try await request("agent.identity.get", params: params)
        return try Self.decodeAgentIdentityPayload(payload)
    }

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
        guard let data = text.data(using: .utf8) else {
            gatewayLog.error("Received non-UTF8 websocket payload")
            return
        }

        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                gatewayLog.error("Received non-object websocket payload")
                return
            }
            json = parsed
        } catch {
            gatewayLog.error("Failed to parse websocket payload: \(error.localizedDescription, privacy: .public)")
            return
        }

        guard let type = json["type"] as? String else {
            gatewayLog.error("Received websocket payload missing type")
            return
        }
        lastInboundMessageAt = Date()

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
        cancelRequestTimeout(for: id)

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

        if event == "connect.challenge" {
            if let nonce = payload["nonce"] as? String,
               nonce.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                handleConnectChallenge(nonce)
            } else {
                gatewayLog.warning("Received connect.challenge without valid nonce")
            }
            return
        }

        // Detect sequence gap (possible missed events during reconnect)
        if let seq, let lastSeq = lastEventSeq, seq > lastSeq + 1 {
            gatewayLog.warning("Event sequence gap detected: expected \(lastSeq + 1) but got \(seq) - may have missed \(seq - lastSeq - 1) events")
        }
        if let seq {
            lastEventSeq = seq
        }

        let gatewayEvent = GatewayEvent(event: event, payload: payload, seq: seq)
        broadcastEvent(gatewayEvent)
    }






    private func handleDisconnect() {
        let wasConnected = isConnected
        isConnected = false

        gatewayLog.warning("WebSocket disconnected (wasConnected=\(wasConnected))")

        // Determine the disconnect error from close reason if available
        let disconnectError: Error
        if let task = webSocketTask,
           task.closeCode == .policyViolation,
           let reasonData = task.closeReason,
           let reason = String(data: reasonData, encoding: .utf8),
           !reason.isEmpty {
            disconnectError = GatewayClientError.connectionFailed(reason)
        } else {
            disconnectError = GatewayClientError.notConnected
        }

        cleanupTransport(error: disconnectError)
        // Don't finish event subscribers on transient disconnect — streams survive reconnect.
        isReconnecting = true
    }

    private func sendRequestMessage(_ string: String, requestId: String) async {
        guard let task = webSocketTask else {
            failPendingRequest(requestId, error: GatewayClientError.notConnected)
            return
        }

        do {
            try await task.send(.string(string))
        } catch {
            failPendingRequest(requestId, error: GatewayClientError.connectionFailed(error.localizedDescription))
            handleDisconnect()
        }
    }

    private func failPendingRequest(_ requestId: String, error: Error) {
        cancelRequestTimeout(for: requestId)
        guard let continuation = pendingRequests.removeValue(forKey: requestId) else { return }
        continuation.resume(throwing: error)
    }

    private func timeoutRequest(_ requestId: String) {
        guard pendingRequests[requestId] != nil else {
            cancelRequestTimeout(for: requestId)
            return
        }
        failPendingRequest(requestId, error: GatewayClientError.timeout)
    }

    private func waitForConnectChallenge(timeoutSeconds: Double = 6.0) async throws -> String {
        if let nonce = bufferedConnectChallengeNonce {
            bufferedConnectChallengeNonce = nil
            return nonce
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingConnectChallenge = continuation
            connectChallengeTimeoutTask?.cancel()
            connectChallengeTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                await self?.failConnectChallengeWaiter(
                    error: GatewayClientError.connectionFailed("Timed out waiting for connect.challenge")
                )
            }
        }
    }

    private func handleConnectChallenge(_ nonce: String) {
        if let continuation = pendingConnectChallenge {
            pendingConnectChallenge = nil
            connectChallengeTimeoutTask?.cancel()
            connectChallengeTimeoutTask = nil
            continuation.resume(returning: nonce)
            return
        }

        bufferedConnectChallengeNonce = nonce
    }

    private func failConnectChallengeWaiter(error: Error) {
        connectChallengeTimeoutTask?.cancel()
        connectChallengeTimeoutTask = nil
        guard let continuation = pendingConnectChallenge else { return }
        pendingConnectChallenge = nil
        continuation.resume(throwing: error)
    }

    private func resetConnectChallengeState() {
        connectChallengeTimeoutTask?.cancel()
        connectChallengeTimeoutTask = nil
        bufferedConnectChallengeNonce = nil
        failConnectChallengeWaiter(error: GatewayClientError.notConnected)
    }

    private func cancelRequestTimeout(for requestId: String) {
        requestTimeoutTasks.removeValue(forKey: requestId)?.cancel()
    }

    private func cancelAllRequestTimeouts() {
        for (_, task) in requestTimeoutTasks {
            task.cancel()
        }
        requestTimeoutTasks.removeAll()
    }

    private func updateConnectionPolicy(from helloPayload: [String: Any]) {
        guard let policy = helloPayload["policy"] as? [String: Any] else {
            return
        }

        if let tickMs = policy["tickIntervalMs"] as? Double, tickMs > 0 {
            tickIntervalMs = tickMs
        } else if let tickMs = policy["tickIntervalMs"] as? Int, tickMs > 0 {
            tickIntervalMs = Double(tickMs)
        }
    }

    private func cleanupAfterFailedConnect(error: Error) {
        gatewayLog.warning("Gateway connect failed: \(error.localizedDescription, privacy: .public)")
        cleanupTransport(error: error, closeCode: .goingAway)
        isConnected = false
    }

    /// Shared cleanup: cancel background tasks, fail pending requests, tear down socket.
    private func cleanupTransport(
        error: Error,
        closeCode: URLSessionWebSocketTask.CloseCode? = nil
    ) {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        tickWatchdogTask?.cancel()
        tickWatchdogTask = nil
        failConnectChallengeWaiter(error: error)
        bufferedConnectChallengeNonce = nil
        cancelAllRequestTimeouts()

        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: error)
        }
        pendingRequests.removeAll()

        if let closeCode {
            webSocketTask?.cancel(with: closeCode, reason: nil)
        }
        webSocketTask = nil
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
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

    private func startTickWatchdog() {
        tickWatchdogTask?.cancel()
        tickWatchdogTask = Task { [weak self] in
            await self?.runTickWatchdog()
        }
    }

    private func runTickWatchdog() async {
        while !Task.isCancelled {
            let watchdogMs = max(tickIntervalMs, 1_000) * 2
            try? await Task.sleep(nanoseconds: UInt64(watchdogMs * 1_000_000))
            guard !Task.isCancelled else { break }
            guard isConnected else { break }

            guard let lastInboundMessageAt else { continue }
            let elapsedMs = Date().timeIntervalSince(lastInboundMessageAt) * 1_000
            if elapsedMs > watchdogMs {
                gatewayLog.warning("Gateway watchdog missed inbound frames; reconnecting")
                handleDisconnect()
                break
            }
        }
    }

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

    static func decodeChatHistoryPayload(_ payload: [String: Any]) throws -> GatewayChatHistory {
        guard let rawMessages = payload["messages"] as? [[String: Any]] else {
            throw GatewayClientError.invalidResponse
        }

        let messages = rawMessages.map { raw in
            let role = raw["role"] as? String ?? "system"
            let text = extractText(from: raw["content"]) ?? ""
            let timestamp = parseTimestamp(raw["timestamp"])
            return GatewayChatMessage(role: role, text: text, timestamp: timestamp)
        }

        return GatewayChatHistory(
            messages: messages,
            thinkingLevel: payload["thinkingLevel"] as? String
        )
    }

    static func decodeSessionsPayload(_ payload: [String: Any]) throws -> [GatewaySession] {
        guard let rawSessions = payload["sessions"] as? [[String: Any]] else {
            throw GatewayClientError.invalidResponse
        }

        var sessions: [GatewaySession] = []
        sessions.reserveCapacity(rawSessions.count)

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
        return sessions
    }

    static func decodeAgentIdentityPayload(_ payload: [String: Any]) throws -> GatewayAgentIdentity {
        guard let name = payload["name"] as? String,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GatewayClientError.invalidResponse
        }

        return GatewayAgentIdentity(
            agentId: payload["agentId"] as? String,
            name: name,
            avatar: payload["avatar"] as? String
        )
    }

    private static func normalizeTimestamp(_ ts: TimeInterval) -> Date {
        Date(timeIntervalSince1970: ts > 1e12 ? ts / 1000 : ts)
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        if let ts = value as? TimeInterval {
            return normalizeTimestamp(ts)
        }
        if let ms = value as? Int {
            return normalizeTimestamp(TimeInterval(ms))
        }
        if let text = value as? String, let ts = TimeInterval(text) {
            return normalizeTimestamp(ts)
        }
        return nil
    }
}
