@testable import AgentBoardCore
import Foundation
import Testing

/// Contract tests for `AgentBoardAppModel.activeSessionCounts(from:tasks:)`
/// (issue #144). `AgentSession` has no agent-name field of its own — `source`
/// is the host machine name and `model` is the coding-tool name (Codex,
/// Claude, ...), neither of which shares a namespace with `KanbanTask
/// .assignee` (e.g. "daneel", "quentin"). The only structurally valid join is
/// `session.linkedTaskID -> KanbanTask.id -> .assignee`, so these tests
/// exercise that join directly rather than `AgentBoardAppModel`, which needs
/// a full set of live stores to construct.
@Suite("AgentBoardAppModel.activeSessionCounts (issue #144)")
struct AgentBoardAppModelActiveSessionCountsTests {
    @Test func countsRunningSessionsByLinkedTaskAssignee() {
        let tasks = [makeTask(id: "task-1", assignee: "daneel")]
        let sessions = [
            makeSession(id: "s1", status: .running, linkedTaskID: "task-1"),
            makeSession(id: "s2", status: .running, linkedTaskID: "task-1")
        ]

        let counts = AgentBoardAppModel.activeSessionCounts(from: sessions, tasks: tasks)

        #expect(counts["daneel"] == 2)
    }

    @Test func onlyRunningSessionsCount() {
        let tasks = [makeTask(id: "task-1", assignee: "daneel")]
        let sessions = [
            makeSession(id: "s1", status: .running, linkedTaskID: "task-1"),
            makeSession(id: "s2", status: .idle, linkedTaskID: "task-1"),
            makeSession(id: "s3", status: .stopped, linkedTaskID: "task-1")
        ]

        let counts = AgentBoardAppModel.activeSessionCounts(from: sessions, tasks: tasks)

        #expect(counts["daneel"] == 1)
    }

    @Test func sessionsWithNoLinkedTaskContributeToNoCount() {
        let sessions = [makeSession(id: "s1", status: .running, linkedTaskID: nil)]

        let counts = AgentBoardAppModel.activeSessionCounts(from: sessions, tasks: [])

        #expect(counts.isEmpty)
    }

    @Test func sessionLinkedToUnknownTaskIdIsIgnored() {
        let tasks = [makeTask(id: "task-1", assignee: "daneel")]
        let sessions = [makeSession(id: "s1", status: .running, linkedTaskID: "does-not-exist")]

        let counts = AgentBoardAppModel.activeSessionCounts(from: sessions, tasks: tasks)

        #expect(counts.isEmpty)
    }

    @Test func linkedTaskWithNilAssigneeContributesToNoCount() {
        let tasks = [makeTask(id: "task-1", assignee: nil)]
        let sessions = [makeSession(id: "s1", status: .running, linkedTaskID: "task-1")]

        let counts = AgentBoardAppModel.activeSessionCounts(from: sessions, tasks: tasks)

        #expect(counts.isEmpty)
    }

    @Test func keysByTrimmedAssigneeMatchingAgentsStoreNamespace() {
        let tasks = [makeTask(id: "task-1", assignee: "  daneel  ")]
        let sessions = [makeSession(id: "s1", status: .running, linkedTaskID: "task-1")]

        let counts = AgentBoardAppModel.activeSessionCounts(from: sessions, tasks: tasks)

        #expect(counts["daneel"] == 1)
    }

    @Test func distinctAgentsCountedSeparately() {
        let tasks = [
            makeTask(id: "task-1", assignee: "daneel"),
            makeTask(id: "task-2", assignee: "quentin")
        ]
        let sessions = [
            makeSession(id: "s1", status: .running, linkedTaskID: "task-1"),
            makeSession(id: "s2", status: .running, linkedTaskID: "task-2"),
            makeSession(id: "s3", status: .running, linkedTaskID: "task-2")
        ]

        let counts = AgentBoardAppModel.activeSessionCounts(from: sessions, tasks: tasks)

        #expect(counts["daneel"] == 1)
        #expect(counts["quentin"] == 2)
    }

    // MARK: - Helpers

    private func makeTask(id: String, assignee: String?) -> KanbanTask {
        KanbanTask(id: id, title: "Task \(id)", assignee: assignee)
    }

    private func makeSession(
        id: String,
        status: AgentSessionStatus,
        linkedTaskID: String?
    ) -> AgentSession {
        AgentSession(id: id, source: "Test Machine", status: status, linkedTaskID: linkedTaskID)
    }
}
