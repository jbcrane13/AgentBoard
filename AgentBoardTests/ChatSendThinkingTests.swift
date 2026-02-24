import Foundation
import Testing
@testable import AgentBoard

actor HappyPathOpenClawService: OpenClawServicing {
    var isConnected: Bool { true }
    var events: AsyncStream<GatewayEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    var lastSentChat: (sessionKey: String, message: String, thinking: String?)?
    var abortRequests: [(sessionKey: String, runId: String?)] = []

    func configure(gatewayURLString: String?, token: String?) throws {}
    func connect() async throws {}
    func disconnect() async {}
    func sendChat(sessionKey: String, message: String, thinking: String?) async throws {
        lastSentChat = (sessionKey: sessionKey, message: message, thinking: thinking)
    }

    func chatHistory(sessionKey: String, limit: Int) async throws -> GatewayChatHistory {
        GatewayChatHistory(messages: [], thinkingLevel: nil)
    }

    func abortChat(sessionKey: String, runId: String?) async throws {
        abortRequests.append((sessionKey: sessionKey, runId: runId))
    }

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
        GatewayAgentIdentity(agentId: "codex", name: "Assistant", avatar: nil)
    }
}

@Suite("Chat Send and Thinking Level Tests")
@MainActor
struct ChatSendAndThinkingLevelTests {
    private func makeState() -> AppState {
        let service = HappyPathOpenClawService()
        return AppState(
            openClawService: service,
            bootstrapOnInit: false,
            startBackgroundLoops: false
        )
    }

    private func makeStateWithService() -> (state: AppState, service: HappyPathOpenClawService) {
        let service = HappyPathOpenClawService()
        let state = AppState(
            openClawService: service,
            bootstrapOnInit: false,
            startBackgroundLoops: false
        )
        return (state: state, service: service)
    }

    // MARK: - Send Message Tests

    @Test("sendChatMessage with valid text appends user message")
    func sendChatMessageAppendsUserMessage() async {
        let state = makeState()
        await state.sendChatMessage("Hello, agent!")
        
        #expect(state.chatMessages.count >= 1)
        #expect(state.chatMessages.first?.role == .user)
        #expect(state.chatMessages.first?.content == "Hello, agent!")
    }

    @Test("sendChatMessage creates assistant placeholder for streaming")
    func sendChatMessageCreatesAssistantPlaceholder() async {
        let state = makeState()
        await state.sendChatMessage("Test message")
        
        let assistantMessages = state.chatMessages.filter { $0.role == .assistant }
        #expect(assistantMessages.count >= 1)
        #expect(assistantMessages.first?.content.isEmpty == true)
    }

    @Test("sendChatMessage clears unread count")
    func sendChatMessageClearsUnreadCount() async {
        let state = makeState()
        state.unreadChatCount = 5
        
        await state.sendChatMessage("Hello")
        
        #expect(state.unreadChatCount == 0)
    }

    @Test("sendChatMessage sets isChatStreaming to true")
    func sendChatMessageSetsStreaming() async {
        let state = makeState()
        await state.sendChatMessage("Streaming test")
        
        #expect(state.isChatStreaming == true)
    }

    @Test("sendChatMessage with context bead sets beadContext on messages")
    func sendChatMessageWithBeadContext() async {
        let state = makeState()
        state.selectedBeadID = "AB-123"
        
        await state.sendChatMessage("Work on this bead")
        
        let userMessage = state.chatMessages.first { $0.role == .user }
        #expect(userMessage?.beadContext == "AB-123")
    }

    @Test("sendChatMessage forwards selected thinking level")
    func sendChatMessageForwardsThinkingLevel() async {
        let (state, service) = makeStateWithService()
        await state.setThinkingLevel("high")

        await state.sendChatMessage("Reason deeply")

        let sent = await service.lastSentChat
        #expect(sent?.thinking == "high")
    }

    @Test("sendChatMessage defaults thinking level to off")
    func sendChatMessageDefaultsThinkingToOff() async {
        let (state, service) = makeStateWithService()

        await state.sendChatMessage("Default thinking")

        let sent = await service.lastSentChat
        #expect(sent?.thinking == "off")
    }

    // MARK: - Thinking Level Tests

    @Test("setThinkingLevel updates chatThinkingLevel in memory")
    func setThinkingLevelUpdatesMemory() async {
        let state = makeState()
        
        await state.setThinkingLevel("high")
        
        #expect(state.chatThinkingLevel == "high")
        #expect(state.statusMessage == "Thinking set to high.")
    }

    @Test("setThinkingLevel with nil resets to default")
    func setThinkingLevelResetsToDefault() async {
        let state = makeState()
        state.chatThinkingLevel = "medium"
        
        await state.setThinkingLevel(nil)
        
        #expect(state.chatThinkingLevel == nil)
        #expect(state.statusMessage == "Thinking set to default.")
    }

    @Test("chatThinkingLevel is initially nil")
    func thinkingLevelInitiallyNil() {
        let state = makeState()
        #expect(state.chatThinkingLevel == nil)
    }

    // MARK: - Session Switch Tests

    @Test("switchSession clears current messages")
    func switchSessionClearsMessages() async {
        let state = makeState()
        await state.sendChatMessage("First message")
        #expect(state.chatMessages.count >= 1)
        
        await state.switchSession(to: "new-session")
        
        #expect(state.chatMessages.isEmpty)
    }

    @Test("switchSession updates currentSessionKey")
    func switchSessionUpdatesKey() async {
        let state = makeState()
        #expect(state.currentSessionKey == "main")
        
        await state.switchSession(to: "custom-session")
        
        #expect(state.currentSessionKey == "custom-session")
    }

    @Test("switchSession resets streaming state")
    func switchSessionResetsStreaming() async {
        let state = makeState()
        await state.sendChatMessage("Streaming message")
        #expect(state.isChatStreaming == true)
        
        await state.switchSession(to: "another-session")
        
        #expect(state.isChatStreaming == false)
    }

    @Test("switchSession aborts in-flight run from previous session")
    func switchSessionAbortsInFlightRun() async {
        let (state, service) = makeStateWithService()
        state.currentSessionKey = "main"
        state.chatRunId = "run-123"
        state.isChatStreaming = true

        await state.switchSession(to: "next-session")

        let aborts = await service.abortRequests
        #expect(aborts.count == 1)
        #expect(aborts.first?.sessionKey == "main")
        #expect(aborts.first?.runId == "run-123")
    }

    @Test("switchSession clears chatRunId")
    func switchSessionClearsRunId() async {
        let state = makeState()
        state.chatRunId = "run-123"
        
        await state.switchSession(to: "new-session")
        
        #expect(state.chatRunId == nil)
    }

    // MARK: - Abort Chat Tests

    @Test("abortChat can be called without error")
    func abortChatDoesNotCrash() async {
        let state = makeState()
        await state.sendChatMessage("Message to abort")
        
        await state.abortChat()
    }

    // MARK: - State Query Helpers Integration

    @Test("StateQueryHelpers can query chat messages")
    func stateQueryHelpersChatQueries() async {
        let state = makeState()
        await state.sendChatMessage("Test message")
        
        let helpers = StateQueryHelpers(appState: state)
        
        #expect(helpers.countChatMessages() >= 1)
        #expect(helpers.countMessages(role: .user) == 1)
        #expect(helpers.lastUserMessage()?.content == "Test message")
    }

    @Test("StateQueryHelpers can query streaming state")
    func stateQueryHelpersStreamingState() async {
        let state = makeState()
        await state.sendChatMessage("Streaming test")
        
        let helpers = StateQueryHelpers(appState: state)
        #expect(helpers.isStreaming() == true)
    }

    @Test("StateQueryHelpers can query thinking level")
    func stateQueryHelpersThinkingLevel() async {
        let state = makeState()
        await state.setThinkingLevel("medium")
        
        let helpers = StateQueryHelpers(appState: state)
        #expect(helpers.thinkingLevel() == "medium")
    }

    @Test("StateQueryHelpers can query session key")
    func stateQueryHelpersSessionKey() async {
        let state = makeState()
        await state.switchSession(to: "test-session")
        
        let helpers = StateQueryHelpers(appState: state)
        #expect(helpers.currentSessionKey() == "test-session")
    }
}
