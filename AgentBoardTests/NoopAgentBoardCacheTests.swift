@testable import AgentBoardCore
import Foundation
import Testing

@MainActor
struct NoopAgentBoardCacheTests {
    @Test
    func allReadsReturnEmptyAndWritesDoNotThrow() throws {
        let cache = NoopAgentBoardCache()

        #expect(try cache.loadConversations().isEmpty)
        #expect(try cache.loadMessages(conversationID: UUID()).isEmpty)
        #expect(try cache.loadWorkItems().isEmpty)
        #expect(try cache.loadSessions().isEmpty)
        #expect(try cache.loadAgentSummaries().isEmpty)

        try cache.replaceWorkItems([])
        try cache.replaceSessions([])
        try cache.replaceAgentSummaries([])
        try cache.deleteConversation(id: UUID())
    }
}
