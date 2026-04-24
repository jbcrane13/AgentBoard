@testable import AgentBoard
import Foundation
import Testing

actor StubOpenClawService: OpenClawServicing {
    var isConnected: Bool {
        true
    }

    var events: AsyncStream<GatewayEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func configure(gatewayURLString _: String?, token _: String?) throws {}
    func connect() async throws {}
    func disconnect() async {}
    func sendChat(sessionKey _: String, message _: String, thinking _: String?) async throws {}
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

actor StubHermesChatService: HermesChatServicing {
    var configuredURL: String?
    var configuredAPIKey: String?
    var lastMessage: String?
    var lastHistory: [ChatMessage] = []
    var chunks: [String]

    init(chunks: [String] = ["Hello", " world"]) {
        self.chunks = chunks
    }

    func configure(gatewayURLString: String?, apiKey: String?) throws {
        configuredURL = gatewayURLString
        configuredAPIKey = apiKey
    }

    func healthCheck() async throws -> Bool {
        true
    }

    func fetchModels() async throws -> [String] {
        ["hermes-agent"]
    }

    func streamChat(
        message: String,
        history: [ChatMessage],
        model _: String?
    ) async throws -> AsyncThrowingStream<String, Error> {
        lastMessage = message
        lastHistory = history

        return AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}

@MainActor
struct AppStateHermesChatTests {
    @Test("sendChatMessage streams Hermes replies into the shared chat state")
    func sendChatMessageStreamsHermesReply() async throws {
        let hermes = StubHermesChatService()
        let state = AppState(
            openClawService: StubOpenClawService(),
            hermesChatService: hermes,
            bootstrapOnInit: false,
            startBackgroundLoops: false
        )
        state.appConfig.chatBackend = ChatBackend.hermes.rawValue
        state.appConfig.hermesGatewayURL = "http://hermes.test:8642"
        state.agentName = "Hermes"

        await state.sendChatMessage("Hello Hermes")
        try await Task.sleep(for: .milliseconds(50))

        #expect(state.chatMessages.count == 2)
        #expect(state.chatMessages[0].role == .user)
        #expect(state.chatMessages[1].role == .assistant)
        #expect(state.chatMessages[1].content == "Hello world")
        #expect(state.isChatStreaming == false)

        let sentMessage = await hermes.lastMessage
        let sentHistory = await hermes.lastHistory
        #expect(sentMessage == "Hello Hermes")
        #expect(sentHistory.isEmpty)
    }
}
