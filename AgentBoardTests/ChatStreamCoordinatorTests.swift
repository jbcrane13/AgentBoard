@testable import AgentBoardCore
import Foundation
import Testing

@Suite("ChatStreamCoordinator — outbound message assembly")
struct ChatStreamCoordinatorTests {
    @Test
    func buildOutboundMessagesReturnsDisplayMessagesUnchangedWhenNoCapabilitiesActive() {
        let conversationID = UUID()
        let displayMessages = [
            ConversationMessage(conversationID: conversationID, role: .user, content: "Hi")
        ]

        let outbound = ChatStreamCoordinator.buildOutboundMessages(
            displayMessages: displayMessages,
            capabilities: [],
            conversationID: conversationID
        )

        #expect(outbound == displayMessages)
    }

    @Test
    func buildOutboundMessagesPrependsSyntheticSystemMessageWithSortedInstructions() {
        let conversationID = UUID()
        let displayMessages = [
            ConversationMessage(conversationID: conversationID, role: .user, content: "Hi")
        ]

        let outbound = ChatStreamCoordinator.buildOutboundMessages(
            displayMessages: displayMessages,
            capabilities: [.web, .thinking],
            conversationID: conversationID
        )

        #expect(outbound.count == 2)
        #expect(outbound[0].role == .system)
        #expect(outbound[0].content.hasPrefix("Capability overrides (client-side): "))
        #expect(outbound[0].content.contains(ChatCapability.thinking.promptInstruction))
        #expect(outbound[0].content.contains(ChatCapability.web.promptInstruction))
        #expect(outbound[1] == displayMessages[0])
    }
}
