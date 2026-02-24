import Foundation

protocol GatewayClientServing: Actor {
    var isConnected: Bool { get }
    var events: AsyncStream<GatewayEvent> { get }

    func connect(url: URL, token: String?) async throws
    func disconnect()
    func sendChat(sessionKey: String, message: String, thinking: String?) async throws
    func chatHistory(sessionKey: String, limit: Int) async throws -> GatewayChatHistory
    func abortChat(sessionKey: String, runId: String?) async throws
    func listSessions(activeMinutes: Int?, limit: Int?) async throws -> [GatewaySession]
    func createSession(
        label: String?,
        projectPath: String?,
        agentType: String?,
        beadId: String?,
        prompt: String?
    ) async throws -> GatewaySession
    func patchSession(key: String, thinkingLevel: String?) async throws
    func agentIdentity(sessionKey: String?) async throws -> GatewayAgentIdentity
}

protocol OpenClawServicing: Actor {
    var isConnected: Bool { get async }
    var events: AsyncStream<GatewayEvent> { get async }

    func configure(gatewayURLString: String?, token: String?) throws
    func connect() async throws
    func disconnect() async
    func sendChat(sessionKey: String, message: String, thinking: String?) async throws
    func chatHistory(sessionKey: String, limit: Int) async throws -> GatewayChatHistory
    func abortChat(sessionKey: String, runId: String?) async throws
    func listSessions(activeMinutes: Int?, limit: Int?) async throws -> [GatewaySession]
    func createSession(
        label: String?,
        projectPath: String?,
        agentType: String?,
        beadId: String?,
        prompt: String?
    ) async throws -> GatewaySession
    func patchSession(key: String, thinkingLevel: String?) async throws
    func agentIdentity(sessionKey: String?) async throws -> GatewayAgentIdentity
}

// Legacy type kept for AgentsView compatibility — will be replaced by GatewaySession
struct OpenClawRemoteSession: Identifiable, Sendable {
    let id: String
    let name: String
    let status: String?
    let model: String?
    let projectPath: String?
    let beadID: String?
    let totalTokens: Int?
    let estimatedCostUSD: Double?
    let startedAt: Date?
    let updatedAt: Date?
}

enum OpenClawServiceError: LocalizedError {
    case invalidGatewayURL
    case notConnected
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidGatewayURL:
            return "Invalid OpenClaw gateway URL."
        case .notConnected:
            return "Not connected to OpenClaw gateway."
        case .requestFailed(let message):
            return message
        }
    }
}

/// Wraps GatewayClient for use by AppState. Manages connection lifecycle and
/// provides typed methods for chat, sessions, and agent identity.
actor OpenClawService {
    private let client: any GatewayClientServing
    private var gatewayURL: URL = URL(string: "http://127.0.0.1:18789")!
    private var authToken: String?

    init(client: any GatewayClientServing = GatewayClient()) {
        self.client = client
    }

    var isConnected: Bool {
        get async { await client.isConnected }
    }

    /// Configure the gateway URL and token.
    func configure(gatewayURLString: String?, token: String?) throws {
        let normalized = (gatewayURLString?.isEmpty == false)
            ? gatewayURLString!
            : "http://127.0.0.1:18789"

        guard let url = URL(string: normalized) else {
            throw OpenClawServiceError.invalidGatewayURL
        }

        gatewayURL = url
        authToken = token?.isEmpty == true ? nil : token
    }

    /// Connect to the gateway via WebSocket RPC.
    func connect() async throws {
        try await client.connect(url: gatewayURL, token: authToken)
    }

    /// Disconnect from the gateway.
    func disconnect() async {
        await client.disconnect()
    }

    /// Event stream from the gateway (chat events, etc.)
    var events: AsyncStream<GatewayEvent> {
        get async { await client.events }
    }

    // MARK: - Chat

    /// Send a chat message to a session.
    func sendChat(sessionKey: String, message: String, thinking: String? = nil) async throws {
        try await client.sendChat(sessionKey: sessionKey, message: message, thinking: thinking)
    }

    /// Load chat history for a session.
    func chatHistory(sessionKey: String, limit: Int = 200) async throws -> GatewayChatHistory {
        try await client.chatHistory(sessionKey: sessionKey, limit: limit)
    }

    /// Abort a running generation.
    func abortChat(sessionKey: String, runId: String? = nil) async throws {
        try await client.abortChat(sessionKey: sessionKey, runId: runId)
    }

    // MARK: - Sessions

    /// List sessions from the gateway.
    func listSessions(activeMinutes: Int? = nil, limit: Int? = nil) async throws -> [GatewaySession] {
        try await client.listSessions(activeMinutes: activeMinutes, limit: limit)
    }

    /// Create a new session via the gateway.
    func createSession(
        label: String? = nil,
        projectPath: String? = nil,
        agentType: String? = nil,
        beadId: String? = nil,
        prompt: String? = nil
    ) async throws -> GatewaySession {
        try await client.createSession(
            label: label,
            projectPath: projectPath,
            agentType: agentType,
            beadId: beadId,
            prompt: prompt
        )
    }

    /// Update session settings (thinking level).
    func patchSession(key: String, thinkingLevel: String?) async throws {
        try await client.patchSession(key: key, thinkingLevel: thinkingLevel)
    }

    // MARK: - Agent Identity

    /// Get agent identity for a session.
    func agentIdentity(sessionKey: String? = nil) async throws -> GatewayAgentIdentity {
        try await client.agentIdentity(sessionKey: sessionKey)
    }
}

extension GatewayClient: GatewayClientServing {}
extension OpenClawService: OpenClawServicing {}
