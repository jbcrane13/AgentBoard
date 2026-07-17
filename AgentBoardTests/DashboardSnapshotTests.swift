import AgentBoardCore
import Foundation
import Testing

@Suite("DashboardSnapshot")
struct DashboardSnapshotTests {
    @Test func emptyInputsProduceAllZeroCounts() {
        let snapshot = DashboardSnapshot.build(
            kanbanTasks: [],
            workItems: [],
            sessions: [],
            conversations: [],
            chatConnection: .disconnected
        )

        #expect(snapshot.kanban == DashboardSnapshot.KanbanSummary(running: 0, ready: 0, blocked: 0, done: 0, total: 0))
        #expect(snapshot.work == DashboardSnapshot.WorkSummary(todo: 0, inProgress: 0, resolved: 0))
        #expect(snapshot.sessions == DashboardSnapshot.SessionsSummary(active: 0, total: 0, syncStatus: .offline))
        #expect(snapshot.runningTaskTitles.isEmpty)
        #expect(snapshot.recentConversations.isEmpty)
        #expect(snapshot.chatConnection == .disconnected)
    }

    @Test func kanbanCountsBucketByStatus() {
        let tasks = [
            makeTask(id: "1", status: .running),
            makeTask(id: "2", status: .running),
            makeTask(id: "3", status: .ready),
            makeTask(id: "4", status: .blocked),
            makeTask(id: "5", status: .done),
            makeTask(id: "6", status: .triage),
            makeTask(id: "7", status: .todo),
            makeTask(id: "8", status: .archived)
        ]

        let snapshot = DashboardSnapshot.build(
            kanbanTasks: tasks,
            workItems: [],
            sessions: [],
            conversations: [],
            chatConnection: .disconnected
        )

        #expect(snapshot.kanban == DashboardSnapshot.KanbanSummary(running: 2, ready: 1, blocked: 1, done: 1, total: 8))
    }

    @Test func workCountsBucketByBoardColumn() {
        let items = [
            makeWorkItem(number: 1, status: .ready),
            makeWorkItem(number: 2, status: .inProgress),
            makeWorkItem(number: 3, status: .review),
            makeWorkItem(number: 4, status: .blocked),
            makeWorkItem(number: 5, status: .done)
        ]

        let snapshot = DashboardSnapshot.build(
            kanbanTasks: [],
            workItems: items,
            sessions: [],
            conversations: [],
            chatConnection: .disconnected
        )

        #expect(snapshot.work == DashboardSnapshot.WorkSummary(todo: 1, inProgress: 3, resolved: 1))
    }

    @Test func sessionCountsTreatRunningAsActive() {
        let sessions = [
            makeSession(id: "a", status: .running),
            makeSession(id: "b", status: .running),
            makeSession(id: "c", status: .idle),
            makeSession(id: "d", status: .stopped)
        ]

        let snapshot = DashboardSnapshot.build(
            kanbanTasks: [],
            workItems: [],
            sessions: sessions,
            conversations: [],
            chatConnection: .connected
        )

        #expect(snapshot.sessions == DashboardSnapshot.SessionsSummary(active: 2, total: 4, syncStatus: .offline))
        #expect(snapshot.chatConnection == .connected)
    }

    @Test func runningTaskTitlesCapAtThreeAndPreserveOrder() {
        let tasks = [
            makeTask(id: "1", title: "First", status: .running),
            makeTask(id: "2", title: "Second", status: .running),
            makeTask(id: "3", title: "Third", status: .running),
            makeTask(id: "4", title: "Fourth", status: .running),
            makeTask(id: "5", title: "Ready one", status: .ready)
        ]

        let snapshot = DashboardSnapshot.build(
            kanbanTasks: tasks,
            workItems: [],
            sessions: [],
            conversations: [],
            chatConnection: .disconnected
        )

        #expect(snapshot.runningTaskTitles == ["First", "Second", "Third"])
    }

    @Test func recentConversationsAreSortedByUpdatedAtDescendingAndCappedAtThree() {
        let now = Date.now
        let conversations = [
            ChatConversation(title: "Oldest", updatedAt: now.addingTimeInterval(-300)),
            ChatConversation(title: "Newest", updatedAt: now),
            ChatConversation(title: "Middle", updatedAt: now.addingTimeInterval(-100)),
            ChatConversation(title: "Fourth", updatedAt: now.addingTimeInterval(-200))
        ]

        let snapshot = DashboardSnapshot.build(
            kanbanTasks: [],
            workItems: [],
            sessions: [],
            conversations: conversations,
            chatConnection: .disconnected
        )

        #expect(snapshot.recentConversations.map(\.title) == ["Newest", "Middle", "Fourth"])
    }

    // MARK: - Fixtures

    private func makeTask(id: String, title: String = "Task", status: KanbanStatus) -> KanbanTask {
        KanbanTask(id: id, title: title, status: status)
    }

    private func makeWorkItem(number: Int, status: WorkState) -> WorkItem {
        WorkItem(
            repository: ConfiguredRepository(owner: "jbcrane13", name: "AgentBoard"),
            issueNumber: number,
            title: "Item \(number)",
            bodySummary: "",
            isClosed: status.isTerminal,
            assignees: [],
            milestone: nil,
            labels: [],
            status: status,
            priority: .p2,
            agentHint: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeSession(id: String, status: AgentSessionStatus) -> AgentSession {
        AgentSession(id: id, source: "test", status: status)
    }
}
