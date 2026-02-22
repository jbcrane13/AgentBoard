import Foundation
import Testing
@testable import AgentBoard

@Suite("Chat Send and Thinking Level Tests")
@MainActor
struct ChatSendAndThinkingLevelTests {

    // MARK: - Send Message Tests

    @Test("sendChatMessage with valid text appends user message")
    func sendChatMessageAppendsUserMessage() async {
        let state = AppState()
        await state.sendChatMessage("Hello, agent!")
        
        #expect(state.chatMessages.count >= 1)
        #expect(state.chatMessages.first?.role == .user)
        #expect(state.chatMessages.first?.content == "Hello, agent!")
    }

    @Test("sendChatMessage creates assistant placeholder for streaming")
    func sendChatMessageCreatesAssistantPlaceholder() async {
        let state = AppState()
        await state.sendChatMessage("Test message")
        
        let assistantMessages = state.chatMessages.filter { $0.role == .assistant }
        #expect(assistantMessages.count >= 1)
        #expect(assistantMessages.first?.content.isEmpty == true)
    }

    @Test("sendChatMessage clears unread count")
    func sendChatMessageClearsUnreadCount() async {
        let state = AppState()
        state.unreadChatCount = 5
        
        await state.sendChatMessage("Hello")
        
        #expect(state.unreadChatCount == 0)
    }

    @Test("sendChatMessage sets isChatStreaming to true")
    func sendChatMessageSetsStreaming() async {
        let state = AppState()
        await state.sendChatMessage("Streaming test")
        
        #expect(state.isChatStreaming == true)
    }

    @Test("sendChatMessage with context bead sets beadContext on messages")
    func sendChatMessageWithBeadContext() async {
        let state = AppState()
        state.selectedBeadID = "AB-123"
        
        await state.sendChatMessage("Work on this bead")
        
        let userMessage = state.chatMessages.first { $0.role == .user }
        #expect(userMessage?.beadContext == "AB-123")
    }

    // MARK: - Thinking Level Tests

    @Test("setThinkingLevel updates chatThinkingLevel in memory")
    func setThinkingLevelUpdatesMemory() async {
        let state = AppState()
        
        await state.setThinkingLevel("high")
        
        #expect(state.chatThinkingLevel == "high")
        #expect(state.statusMessage == "Thinking set to high.")
    }

    @Test("setThinkingLevel with nil resets to default")
    func setThinkingLevelResetsToDefault() async {
        let state = AppState()
        state.chatThinkingLevel = "medium"
        
        await state.setThinkingLevel(nil)
        
        #expect(state.chatThinkingLevel == nil)
        #expect(state.statusMessage == "Thinking set to default.")
    }

    @Test("chatThinkingLevel is initially nil")
    func thinkingLevelInitiallyNil() {
        let state = AppState()
        #expect(state.chatThinkingLevel == nil)
    }

    // MARK: - Session Switch Tests

    @Test("switchSession clears current messages")
    func switchSessionClearsMessages() async {
        let state = AppState()
        await state.sendChatMessage("First message")
        #expect(state.chatMessages.count >= 1)
        
        await state.switchSession(to: "new-session")
        
        #expect(state.chatMessages.isEmpty)
    }

    @Test("switchSession updates currentSessionKey")
    func switchSessionUpdatesKey() async {
        let state = AppState()
        #expect(state.currentSessionKey == "main")
        
        await state.switchSession(to: "custom-session")
        
        #expect(state.currentSessionKey == "custom-session")
    }

    @Test("switchSession resets streaming state")
    func switchSessionResetsStreaming() async {
        let state = AppState()
        await state.sendChatMessage("Streaming message")
        #expect(state.isChatStreaming == true)
        
        await state.switchSession(to: "another-session")
        
        #expect(state.isChatStreaming == false)
    }

    @Test("switchSession clears chatRunId")
    func switchSessionClearsRunId() async {
        let state = AppState()
        state.chatRunId = "run-123"
        
        await state.switchSession(to: "new-session")
        
        #expect(state.chatRunId == nil)
    }

    // MARK: - Abort Chat Tests

    @Test("abortChat can be called without error")
    func abortChatDoesNotCrash() async {
        let state = AppState()
        await state.sendChatMessage("Message to abort")
        
        await state.abortChat()
    }

    // MARK: - State Query Helpers Integration

    @Test("StateQueryHelpers can query chat messages")
    func stateQueryHelpersChatQueries() async {
        let state = AppState()
        await state.sendChatMessage("Test message")
        
        let helpers = StateQueryHelpers(appState: state)
        
        #expect(helpers.countChatMessages() >= 1)
        #expect(helpers.countMessages(role: .user) == 1)
        #expect(helpers.lastUserMessage()?.content == "Test message")
    }

    @Test("StateQueryHelpers can query streaming state")
    func stateQueryHelpersStreamingState() async {
        let state = AppState()
        await state.sendChatMessage("Streaming test")
        
        let helpers = StateQueryHelpers(appState: state)
        #expect(helpers.isStreaming() == true)
    }

    @Test("StateQueryHelpers can query thinking level")
    func stateQueryHelpersThinkingLevel() async {
        let state = AppState()
        await state.setThinkingLevel("medium")
        
        let helpers = StateQueryHelpers(appState: state)
        #expect(helpers.thinkingLevel() == "medium")
    }

    @Test("StateQueryHelpers can query session key")
    func stateQueryHelpersSessionKey() async {
        let state = AppState()
        await state.switchSession(to: "test-session")
        
        let helpers = StateQueryHelpers(appState: state)
        #expect(helpers.currentSessionKey() == "test-session")
    }
}
