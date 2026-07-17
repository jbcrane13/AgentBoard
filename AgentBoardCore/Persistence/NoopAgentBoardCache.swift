import Foundation

/// Cache-less fallback used when SwiftData container creation fails even
/// in-memory. Reads return nothing; writes are dropped. Keeps the app
/// launchable instead of crashing in AgentBoardBootstrap.
@MainActor
public final class NoopAgentBoardCache: AgentBoardCacheProtocol {
    public init() {}

    public func loadConversations() throws -> [ChatConversation] {
        []
    }

    public func loadMessages(conversationID _: UUID) throws -> [ConversationMessage] {
        []
    }

    public func saveConversationSnapshot(
        conversation _: ChatConversation,
        messages _: [ConversationMessage]
    ) throws {}
    public func deleteConversation(id _: UUID) throws {}

    public func loadWorkItems() throws -> [WorkItem] {
        []
    }

    public func replaceWorkItems(_: [WorkItem]) throws {}

    public func loadSessions() throws -> [AgentSession] {
        []
    }

    public func replaceSessions(_: [AgentSession]) throws {}
    public func loadAgentSummaries() throws -> [AgentSummary] {
        []
    }

    public func replaceAgentSummaries(_: [AgentSummary]) throws {}

    public func loadKanbanTasks() throws -> [KanbanTask] {
        []
    }

    public func replaceKanbanTasks(_: [KanbanTask]) throws {}
}
