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
        GatewayChatHistory(messages: [], thinkingLevel: nil)
    }

    func abortChat(sessionKey: String, runId: String?) async throws {}

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
        GatewaySession(
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

    func patchSession(key: String, thinkingLevel: String?) async throws {}

    func agentIdentity(sessionKey: String?) async throws -> GatewayAgentIdentity {
        GatewayAgentIdentity(agentId: "codex", name: "AgentBoard Assistant", avatar: nil)
    }
}

@Suite("OpenClawService Contract Tests")
struct OpenClawServiceContractTests {
    @Test("configure rejects invalid gateway URLs")
    func configureRejectsInvalidURL() async {
        let client = MockGatewayClient()
        let service = OpenClawService(client: client)

        do {
            try await service.configure(gatewayURLString: "://broken-url", token: nil)
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
        await client.nextSessions = [
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
        ]
        let service = OpenClawService(client: client)

        let sessions = try await service.listSessions(activeMinutes: 60, limit: 5)
        #expect(sessions.count == 1)
        #expect(sessions[0].key == "main")
        #expect(sessions[0].thinkingLevel == "low")
    }

    @Test("sendChat surfaces gateway errors to callers")
    func sendChatSurfacesGatewayErrors() async throws {
        let client = MockGatewayClient()
        await client.sendChatError = URLError(.notConnectedToInternet)
        let service = OpenClawService(client: client)

        do {
            try await service.sendChat(sessionKey: "main", message: "fail")
            Issue.record("Expected sendChat to throw.")
        } catch {
            #expect(error.localizedDescription.lowercased().contains("internet"))
        }
    }
}
