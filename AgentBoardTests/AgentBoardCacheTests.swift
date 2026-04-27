@testable import AgentBoardCore
import Foundation
import Testing

@Suite("AgentBoardCache", .serialized)
@MainActor
struct AgentBoardCacheTests {
    // MARK: - Conversations

    @Test func conversationRoundTrip() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let conv = ChatConversation(title: "Test Session", modelID: "hermes-agent")

        try cache.saveConversationSnapshot(conversation: conv, messages: [])

        let loaded = try cache.loadConversations()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == conv.id)
        #expect(loaded[0].title == conv.title)
        #expect(loaded[0].modelID == conv.modelID)
    }

    @Test func messagesRoundTrip() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let convID = UUID()
        let conv = ChatConversation(id: convID, title: "Chat")
        let messages = [
            ConversationMessage(conversationID: convID, role: .user, content: "Hello"),
            ConversationMessage(conversationID: convID, role: .assistant, content: "World")
        ]

        try cache.saveConversationSnapshot(conversation: conv, messages: messages)

        let loaded = try cache.loadMessages(conversationID: convID)
        #expect(loaded.count == 2)
        #expect(loaded[0].role == .user)
        #expect(loaded[0].content == "Hello")
        #expect(loaded[1].role == .assistant)
        #expect(loaded[1].content == "World")
    }

    @Test func saveConversationSnapshotIsIdempotent() throws {
        let cache = try AgentBoardCache(inMemory: true)
        var conv = ChatConversation(title: "Original")
        try cache.saveConversationSnapshot(conversation: conv, messages: [])

        conv.title = "Updated"
        try cache.saveConversationSnapshot(conversation: conv, messages: [])

        let loaded = try cache.loadConversations()
        #expect(loaded.count == 1)
        #expect(loaded[0].title == "Updated")
    }

    @Test func saveSnapshotReplacesMessages() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let convID = UUID()
        let conv = ChatConversation(id: convID, title: "Chat")

        let initial = [ConversationMessage(conversationID: convID, role: .user, content: "First")]
        try cache.saveConversationSnapshot(conversation: conv, messages: initial)

        let updated = [
            ConversationMessage(conversationID: convID, role: .user, content: "Second"),
            ConversationMessage(conversationID: convID, role: .assistant, content: "Reply")
        ]
        try cache.saveConversationSnapshot(conversation: conv, messages: updated)

        let loaded = try cache.loadMessages(conversationID: convID)
        #expect(loaded.count == 2)
        #expect(loaded[0].content == "Second")
    }

    @Test func deleteConversationRemovesConversationAndMessages() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let convID = UUID()
        let conv = ChatConversation(id: convID, title: "Delete Me")
        let messages = [ConversationMessage(conversationID: convID, role: .user, content: "Bye")]
        try cache.saveConversationSnapshot(conversation: conv, messages: messages)

        try cache.deleteConversation(id: convID)

        let conversations = try cache.loadConversations()
        let remainingMessages = try cache.loadMessages(conversationID: convID)
        #expect(conversations.isEmpty)
        #expect(remainingMessages.isEmpty)
    }

    // MARK: - WorkItems

    @Test func workItemsRoundTrip() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let repo = ConfiguredRepository(owner: "jbcrane13", name: "AgentBoard")
        let item = WorkItem(
            repository: repo,
            issueNumber: 42,
            title: "Ship the board",
            bodySummary: "First line",
            isClosed: false,
            assignees: ["blake"],
            milestone: WorkMilestone(number: 1, title: "v1.0"),
            labels: ["status:ready", "priority:p1"],
            status: .ready,
            priority: .p1,
            agentHint: "codex",
            createdAt: .now,
            updatedAt: .now
        )

        try cache.replaceWorkItems([item])

        let loaded = try cache.loadWorkItems()
        #expect(loaded.count == 1)
        #expect(loaded[0].issueNumber == 42)
        #expect(loaded[0].title == "Ship the board")
        #expect(loaded[0].bodySummary == "First line")
        #expect(loaded[0].assignees == ["blake"])
        #expect(loaded[0].milestone?.number == 1)
        #expect(loaded[0].milestone?.title == "v1.0")
        #expect(loaded[0].status == .ready)
        #expect(loaded[0].priority == .p1)
        #expect(loaded[0].agentHint == "codex")
    }

    @Test func replaceWorkItemsClearsExisting() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let repo = ConfiguredRepository(owner: "org", name: "repo")
        func makeItem(_ number: Int, title: String) -> WorkItem {
            WorkItem(
                repository: repo, issueNumber: number, title: title,
                bodySummary: "", isClosed: false, assignees: [],
                milestone: nil, labels: [], status: .ready, priority: .p2,
                agentHint: nil, createdAt: .now, updatedAt: .now
            )
        }
        let item1 = makeItem(1, title: "One")
        let item2 = makeItem(2, title: "Two")

        try cache.replaceWorkItems([item1, item2])
        try cache.replaceWorkItems([item1])

        let loaded = try cache.loadWorkItems()
        #expect(loaded.count == 1)
        #expect(loaded[0].issueNumber == 1)
    }

    @Test func workItemWithNilMilestoneRoundTrips() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let repo = ConfiguredRepository(owner: "org", name: "repo")
        let item = WorkItem(
            repository: repo, issueNumber: 99, title: "No Milestone",
            bodySummary: "", isClosed: false, assignees: [],
            milestone: nil, labels: [], status: .ready, priority: .p2,
            agentHint: nil, createdAt: .now, updatedAt: .now
        )

        try cache.replaceWorkItems([item])

        let loaded = try cache.loadWorkItems()
        #expect(loaded[0].milestone == nil)
    }

    // MARK: - Tasks

    @Test func tasksRoundTrip() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let ref = WorkReference(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            issueNumber: 7
        )
        let task = AgentTask(
            id: "task-7",
            workItem: ref,
            title: "Fix the crash",
            status: .inProgress,
            priority: .p1,
            assignedAgent: "Claude",
            sessionID: "sess-42",
            note: "Started."
        )

        try cache.replaceTasks([task])

        let loaded = try cache.loadTasks()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "task-7")
        #expect(loaded[0].title == "Fix the crash")
        #expect(loaded[0].status == .inProgress)
        #expect(loaded[0].sessionID == "sess-42")
        #expect(loaded[0].note == "Started.")
    }

    // MARK: - Sessions

    @Test func sessionsRoundTrip() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let ref = WorkReference(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            issueNumber: 5
        )
        let session = AgentSession(
            id: "sess-5",
            source: "Blake's MacBook",
            status: .running,
            linkedTaskID: "task-5",
            workItem: ref,
            model: "hermes-agent",
            pid: 1234,
            tmuxSession: "ab-repo-5",
            lastOutput: "Working..."
        )

        try cache.replaceSessions([session])

        let loaded = try cache.loadSessions()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "sess-5")
        #expect(loaded[0].source == "Blake's MacBook")
        #expect(loaded[0].status == .running)
        #expect(loaded[0].linkedTaskID == "task-5")
        #expect(loaded[0].workItem?.issueNumber == 5)
        #expect(loaded[0].pid == 1234)
        #expect(loaded[0].tmuxSession == "ab-repo-5")
        #expect(loaded[0].lastOutput == "Working...")
    }

    @Test func sessionWithNoWorkItemRoundTrips() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let session = AgentSession(id: "sess-orphan", source: "CLI", status: .idle)

        try cache.replaceSessions([session])

        let loaded = try cache.loadSessions()
        #expect(loaded[0].workItem == nil)
    }

    // MARK: - Agent Summaries

    @Test func agentSummariesRoundTrip() throws {
        let cache = try AgentBoardCache(inMemory: true)
        let summary = AgentSummary(
            id: "codex",
            name: "Codex",
            health: .online,
            activeTaskCount: 3,
            activeSessionCount: 2,
            recentActivity: "Implementing tests."
        )

        try cache.replaceAgentSummaries([summary])

        let loaded = try cache.loadAgentSummaries()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "codex")
        #expect(loaded[0].health == .online)
        #expect(loaded[0].activeTaskCount == 3)
        #expect(loaded[0].recentActivity == "Implementing tests.")
    }
}
