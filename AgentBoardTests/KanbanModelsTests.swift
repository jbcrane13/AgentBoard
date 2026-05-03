import AgentBoardCore
import Foundation
import Testing

@Suite("KanbanModels")
struct KanbanModelsTests {
    // MARK: - KanbanStatus

    @Test func kanbanStatusTitleMatchesUserCopy() {
        #expect(KanbanStatus.triage.title == "Triage")
        #expect(KanbanStatus.todo.title == "Todo")
        #expect(KanbanStatus.ready.title == "Ready")
        #expect(KanbanStatus.running.title == "In Progress")
        #expect(KanbanStatus.blocked.title == "Blocked")
        #expect(KanbanStatus.done.title == "Done")
        #expect(KanbanStatus.archived.title == "Archived")
    }

    @Test func kanbanStatusBoardColumnsExcludesArchived() {
        let columns = KanbanStatus.boardColumns
        #expect(!columns.contains(.archived))
    }

    @Test func kanbanStatusBoardColumnsContainsAllNonArchivedStatuses() {
        let columns = KanbanStatus.boardColumns
        #expect(columns.contains(.triage))
        #expect(columns.contains(.todo))
        #expect(columns.contains(.ready))
        #expect(columns.contains(.running))
        #expect(columns.contains(.blocked))
        #expect(columns.contains(.done))
    }

    @Test func kanbanStatusBoardColumnsArePersistedInUIOrder() {
        // Order is observable in the kanban board UI.
        #expect(KanbanStatus.boardColumns == [
            .triage, .todo, .ready, .running, .blocked, .done
        ])
    }

    // MARK: - KanbanTask priority/assignee display

    @Test func kanbanTaskDisplayPriorityMapsP0ThroughP3() {
        #expect(makeTask(priority: 0).displayPriority == "P0")
        #expect(makeTask(priority: 1).displayPriority == "P1")
        #expect(makeTask(priority: 2).displayPriority == "P2")
        #expect(makeTask(priority: 3).displayPriority == "P3")
    }

    @Test func kanbanTaskDisplayPriorityClampsLargePriorityToP3() {
        // The kanban CLI treats anything beyond P2 as P3 for display.
        #expect(makeTask(priority: 7).displayPriority == "P3")
        #expect(makeTask(priority: 99).displayPriority == "P3")
    }

    @Test func kanbanTaskDisplayAssigneeFallsBackToUnassignedWhenNil() {
        #expect(makeTask(assignee: nil).displayAssignee == "unassigned")
    }

    @Test func kanbanTaskDisplayAssigneeReturnsAssigneeName() {
        #expect(makeTask(assignee: "daneel").displayAssignee == "daneel")
    }

    // MARK: - KanbanRun.duration

    @Test func kanbanRunDurationIsNilWhenStillRunning() {
        let run = KanbanRun(
            id: 1,
            taskID: "t-1",
            status: "running",
            startedAt: .now
        )
        #expect(run.duration == nil)
    }

    @Test func kanbanRunDurationComputesElapsedWhenEnded() throws {
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 1125)
        let run = KanbanRun(
            id: 1,
            taskID: "t-1",
            status: "completed",
            startedAt: start,
            endedAt: end
        )
        let duration = try #require(run.duration)
        #expect(duration == 125)
    }

    // MARK: - KanbanCreateDraft

    @Test func kanbanCreateDraftDefaultsAreSensible() {
        let draft = KanbanCreateDraft(title: "Investigate flake")
        #expect(draft.title == "Investigate flake")
        #expect(draft.body == nil)
        #expect(draft.assignee == nil)
        #expect(draft.priority == 0)
        #expect(draft.tenant == nil)
        #expect(draft.parentIDs.isEmpty)
    }

    @Test func kanbanCreateDraftEncodesAndDecodesAllFields() throws {
        let draft = KanbanCreateDraft(
            title: "Investigate flake",
            body: "Repro steps...",
            assignee: "daneel",
            priority: 2,
            tenant: "core",
            parentIDs: ["task-1", "task-2"]
        )
        let data = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(KanbanCreateDraft.self, from: data)
        #expect(decoded == draft)
    }

    // MARK: - Codable round-trip for status & outcome

    @Test func kanbanStatusEncodesUsingRawValue() throws {
        let data = try JSONEncoder().encode(KanbanStatus.running)
        let decoded = try JSONDecoder().decode(KanbanStatus.self, from: data)
        #expect(decoded == .running)
        let raw = String(data: data, encoding: .utf8)
        #expect(raw == "\"running\"")
    }

    @Test func kanbanRunOutcomeUsesSnakeCaseRawValues() throws {
        // "timed_out", "spawn_failed", and "gave_up" are persisted to disk.
        let outcomes: [KanbanRunOutcome] = [.timedOut, .spawnFailed, .gaveUp]
        let expectedRaw = ["timed_out", "spawn_failed", "gave_up"]
        for (outcome, expected) in zip(outcomes, expectedRaw) {
            let data = try JSONEncoder().encode(outcome)
            let raw = String(data: data, encoding: .utf8)
            #expect(raw == "\"\(expected)\"")
        }
    }

    // MARK: - Helpers

    private func makeTask(
        priority: Int = 0,
        assignee: String? = nil
    ) -> KanbanTask {
        KanbanTask(
            id: "task-\(priority)-\(assignee ?? "")",
            title: "Sample",
            assignee: assignee,
            priority: priority
        )
    }
}
