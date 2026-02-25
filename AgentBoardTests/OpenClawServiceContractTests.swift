import Foundation
import Testing
@testable import AgentBoard

actor MockGatewayClient: GatewayClientServing {
    var isConnected: Bool = false
    var events: AsyncStream<GatewayEvent> = AsyncStream { continuation in
        continuation.finish()
    }

    var sendChatError: Error?
    var lastSentChat: (sessionKey: String, message: String, thinking: String?)?
    var nextSessions: [GatewaySession] = []

    // Tracking for forwarding tests
    var chatHistoryRequests: [(sessionKey: String, limit: Int)] = []
    var abortChatRequests: [(sessionKey: String, runId: String?)] = []
    var patchSessionRequests: [(key: String, thinkingLevel: String?)] = []
    var agentIdentityRequests: [String?] = []
    var createSessionRequests: [(label: String?, agentType: String?, beadId: String?)] = []

    // Setters for test setup — actor properties can't be assigned from outside the actor.
    func setNextSessions(_ sessions: [GatewaySession]) { nextSessions = sessions }
    func setSendChatError(_ error: Error?) { sendChatError = error }

    func connect(url: URL, token: String?) async throws {
        isConnected = true
    }

    func disconnect() {
        isConnected = false
    }

    func sendChat(sessionKey: String, message: String, thinking: String?) async throws {
        if let sendChatError {
            throw sendChatError
        }
        lastSentChat = (sessionKey: sessionKey, message: message, thinking: thinking)
    }

    func chatHistory(sessionKey: String, limit: Int) async throws -> GatewayChatHistory {
        chatHistoryRequests.append((sessionKey: sessionKey, limit: limit))
        return GatewayChatHistory(messages: [], thinkingLevel: nil)
    }

    func abortChat(sessionKey: String, runId: String?) async throws {
        abortChatRequests.append((sessionKey: sessionKey, runId: runId))
    }

    func listSessions(activeMinutes: Int?, limit: Int?) async throws -> [GatewaySession] {
        nextSessions
    }

    func createSession(
        label: String?,
        projectPath: String?,
        agentType: String?,
        beadId: String?,
        prompt: String?
    ) async throws -> GatewaySession {
        createSessionRequests.append((label: label, agentType: agentType, beadId: beadId))
        return GatewaySession(
            id: "new-session",
            key: "new-session",
            label: label,
            agentId: agentType,
            model: nil,
            status: "active",
            lastActiveAt: Date(),
            thinkingLevel: nil
        )
    }

    func patchSession(key: String, thinkingLevel: String?) async throws {
        patchSessionRequests.append((key: key, thinkingLevel: thinkingLevel))
    }

    func agentIdentity(sessionKey: String?) async throws -> GatewayAgentIdentity {
        agentIdentityRequests.append(sessionKey)
        return GatewayAgentIdentity(agentId: "codex", name: "AgentBoard Assistant", avatar: nil)
    }
}

@Suite("OpenClawService Contract Tests")
struct OpenClawServiceContractTests {
    @Test("configure rejects invalid gateway URLs")
    func configureRejectsInvalidURL() async {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)

        do {
            try await service.configure(gatewayURLString: "http://", token: nil)
            Issue.record("Expected invalidGatewayURL error.")
        } catch OpenClawServiceError.invalidGatewayURL {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendChat forwards request to gateway client")
    func sendChatForwardsToClient() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        try await service.configure(gatewayURLString: "http://127.0.0.1:18789", token: "token")

        try await service.sendChat(sessionKey: "main", message: "hello", thinking: "high")

        let sent = await client.lastSentChat
        #expect(sent?.sessionKey == "main")
        #expect(sent?.message == "hello")
        #expect(sent?.thinking == "high")
    }

    @Test("listSessions returns gateway client payload")
    func listSessionsReturnsClientData() async throws {
        let client = MockGatewayClient()
        await client.setNextSessions([
            GatewaySession(
                id: "main",
                key: "main",
                label: "Main",
                agentId: "codex",
                model: "gpt-5.3-codex",
                status: "active",
                lastActiveAt: Date(),
                thinkingLevel: "low"
            )
        ])
        let service = OpenClawService(client: client)

        let sessions = try await service.listSessions(activeMinutes: 60, limit: 5)
        #expect(sessions.count == 1)
        #expect(sessions[0].key == "main")
        #expect(sessions[0].thinkingLevel == "low")
    }

    @Test("sendChat surfaces gateway errors to callers")
    func sendChatSurfacesGatewayErrors() async throws {
        let client = MockGatewayClient()
        await client.setSendChatError(URLError(.notConnectedToInternet))
        let service = OpenClawService(client: client)

        do {
            try await service.sendChat(sessionKey: "main", message: "fail")
            Issue.record("Expected sendChat to throw.")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("configure with nil URL falls back to default http://127.0.0.1:18789")
    func configureNilURLFallsBackToDefault() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        // nil URL → should not throw and use default
        try await service.configure(gatewayURLString: nil, token: nil)
        // Connect to verify it used a valid URL (would throw if URL was nil/invalid)
        try await service.connect()
        let connected = await client.isConnected
        #expect(connected == true)
    }

    @Test("configure with empty string URL falls back to default")
    func configureEmptyStringURLFallsBackToDefault() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        try await service.configure(gatewayURLString: "", token: nil)
        try await service.connect()
        let connected = await client.isConnected
        #expect(connected == true)
    }

    @Test("configure with empty token sets nil auth")
    func configureEmptyTokenSetsNilAuth() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        // Empty token should be treated as nil (no auth)
        try await service.configure(gatewayURLString: "http://127.0.0.1:18789", token: "")
        // Should still connect successfully with nil token
        try await service.connect()
        let connected = await client.isConnected
        #expect(connected == true)
    }

    @Test("chatHistory forwards sessionKey and limit to gateway client")
    func chatHistoryForwardsToClient() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        try await service.configure(gatewayURLString: "http://127.0.0.1:18789", token: nil)

        _ = try await service.chatHistory(sessionKey: "main", limit: 50)

        let requests = await client.chatHistoryRequests
        #expect(requests.count == 1)
        #expect(requests[0].sessionKey == "main")
        #expect(requests[0].limit == 50)
    }

    @Test("abortChat forwards sessionKey and runId to gateway client")
    func abortChatForwardsToClient() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        try await service.configure(gatewayURLString: "http://127.0.0.1:18789", token: nil)

        try await service.abortChat(sessionKey: "main", runId: "run-xyz")

        let requests = await client.abortChatRequests
        #expect(requests.count == 1)
        #expect(requests[0].sessionKey == "main")
        #expect(requests[0].runId == "run-xyz")
    }

    @Test("patchSession forwards key and thinkingLevel to gateway client")
    func patchSessionForwardsToClient() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        try await service.configure(gatewayURLString: "http://127.0.0.1:18789", token: nil)

        try await service.patchSession(key: "main", thinkingLevel: "high")

        let requests = await client.patchSessionRequests
        #expect(requests.count == 1)
        #expect(requests[0].key == "main")
        #expect(requests[0].thinkingLevel == "high")
    }

    @Test("agentIdentity forwards sessionKey to gateway client")
    func agentIdentityForwardsToClient() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        try await service.configure(gatewayURLString: "http://127.0.0.1:18789", token: nil)

        let identity = try await service.agentIdentity(sessionKey: "my-session")

        let requests = await client.agentIdentityRequests
        #expect(requests.count == 1)
        #expect(requests[0] == "my-session")
        #expect(identity.name == "AgentBoard Assistant")
    }

    @Test("agentIdentity with nil sessionKey passes nil to gateway client")
    func agentIdentityNilSessionKeyPassedThrough() async throws {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)
        try await service.configure(gatewayURLString: "http://127.0.0.1:18789", token: nil)

        _ = try await service.agentIdentity(sessionKey: nil)

        let requests = await client.agentIdentityRequests
        #expect(requests.count == 1)
        #expect(requests[0] == nil)
    }

    @Test("OpenClawServiceError descriptions are non-empty and descriptive")
    func openClawServiceErrorDescriptions() {
        #expect(OpenClawServiceError.invalidGatewayURL.errorDescription?.isEmpty == false)
        #expect(OpenClawServiceError.notConnected.errorDescription?.isEmpty == false)
        #expect(OpenClawServiceError.requestFailed("oops").errorDescription?.contains("oops") == true)
    }
}
