@testable import AgentBoard
import Foundation
import Testing

actor FailingOpenClawService: OpenClawServicing {
    var isConnected: Bool {
        false
    }

    var events: AsyncStream<GatewayEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func configure(gatewayURLString _: String?, token _: String?) throws {}
    func connect() async throws {}
    func disconnect() async {}

    func sendChat(sessionKey _: String, message _: String, thinking _: String?) async throws {
        throw URLError(.notConnectedToInternet)
    }

    func chatHistory(sessionKey _: String, limit _: Int) async throws -> GatewayChatHistory {
        GatewayChatHistory(messages: [], thinkingLevel: nil)
    }

    func abortChat(sessionKey _: String, runId _: String?) async throws {}

    func listSessions(activeMinutes _: Int?, limit _: Int?) async throws -> [GatewaySession] {
        []
    }

    func createSession(
        label _: String?,
        projectPath _: String?,
        agentType _: String?,
        beadId _: String?,
        prompt _: String?
    ) async throws -> GatewaySession {
        GatewaySession(
            id: "main",
            key: "main",
            label: nil,
            agentId: nil,
            model: nil,
            status: "active",
            lastActiveAt: Date(),
            thinkingLevel: nil
        )
    }

    func patchSession(key _: String, thinkingLevel _: String?) async throws {}

    func agentIdentity(sessionKey _: String?) async throws -> GatewayAgentIdentity {
        GatewayAgentIdentity(agentId: nil, name: "Assistant", avatar: nil)
    }
}

@MainActor
struct AppStateOpenClawErrorTests {
    @Test("sendChatMessage surfaces gateway failures to UI state")
    func sendChatMessageSurfacesError() async {
        let state = AppState(
            openClawService: FailingOpenClawService(),
            bootstrapOnInit: false,
            startBackgroundLoops: false
        )

        await state.sendChatMessage("hello")

        #expect(state.errorMessage != nil)
        #expect(!(state.errorMessage?.isEmpty ?? true))
        #expect(state.isChatStreaming == false)
        #expect(state.chatMessages.count == 2)
        #expect(state.chatMessages[1].role == .assistant)
        #expect(state.chatMessages[1].content.contains("Failed to send message"))
    }
}
