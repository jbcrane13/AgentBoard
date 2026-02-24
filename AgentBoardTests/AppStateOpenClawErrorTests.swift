import Foundation
import Testing
@testable import AgentBoard

actor FailingOpenClawService: OpenClawServicing {
    var isConnected: Bool { false }
    var events: AsyncStream<GatewayEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func configure(gatewayURLString: String?, token: String?) throws {}
    func connect() async throws {}
    func disconnect() async {}

    func sendChat(sessionKey: String, message: String, thinking: String?) async throws {
        throw URLError(.notConnectedToInternet)
    }

    func chatHistory(sessionKey: String, limit: Int) async throws -> GatewayChatHistory {
        GatewayChatHistory(messages: [], thinkingLevel: nil)
    }

    func abortChat(sessionKey: String, runId: String?) async throws {}

    func listSessions(activeMinutes: Int?, limit: Int?) async throws -> [GatewaySession] {
        []
    }

    func createSession(
        label: String?,
        projectPath: String?,
        agentType: String?,
        beadId: String?,
        prompt: String?
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

    func patchSession(key: String, thinkingLevel: String?) async throws {}

    func agentIdentity(sessionKey: String?) async throws -> GatewayAgentIdentity {
        GatewayAgentIdentity(agentId: nil, name: "Assistant", avatar: nil)
    }
}

@Suite("AppState OpenClaw Error Surfacing")
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
        #expect(state.errorMessage?.lowercased().contains("internet") == true)
        #expect(state.isChatStreaming == false)
        #expect(state.chatMessages.count == 2)
        #expect(state.chatMessages[1].role == .assistant)
        #expect(state.chatMessages[1].content.contains("Failed to send message"))
    }
}
