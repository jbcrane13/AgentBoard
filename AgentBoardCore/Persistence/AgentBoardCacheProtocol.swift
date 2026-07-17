import Foundation

/// Read+write protocol over the local SwiftData cache. Stores depend on this
/// protocol rather than the concrete `AgentBoardCache` so test fakes can stand
/// in without a real `ModelContainer`. The concrete `AgentBoardCache` conforms
/// to it via an extension in AgentBoardCache.swift.
@MainActor
public protocol AgentBoardCacheProtocol: SessionsCacheStoring, Sendable {
    // MARK: - Conversations (ChatStore)

    func loadConversations() throws -> [ChatConversation]
    func loadMessages(conversationID: UUID) throws -> [ConversationMessage]
    func saveConversationSnapshot(
        conversation: ChatConversation,
        messages: [ConversationMessage]
    ) throws
    func deleteConversation(id: UUID) throws

    // MARK: - Work items (WorkStore)

    func loadWorkItems() throws -> [WorkItem]
    func replaceWorkItems(_ items: [WorkItem]) throws

    // MARK: - Sessions + agent summaries (SessionsStore / AgentsStore)

    // loadSessions/replaceSessions are inherited from SessionsCacheStoring.
    func loadAgentSummaries() throws -> [AgentSummary]
    func replaceAgentSummaries(_ agents: [AgentSummary]) throws

    // MARK: - Kanban tasks (AgentsStore)

    func loadKanbanTasks() throws -> [KanbanTask]
    func replaceKanbanTasks(_ tasks: [KanbanTask]) throws
}
