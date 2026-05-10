@testable import AgentBoardCore
import Foundation
import Testing

@Suite("AgentsStore summary derivation (kanban picker data source)")
struct AgentsStoreSummariesTests {
    @Test func buildAgentSummariesReturnsEmptyForNoTasks() {
        let summaries = AgentsStore.buildAgentSummaries(from: [])
        #expect(summaries.isEmpty)
    }

    @Test func buildAgentSummariesReturnsOneSummaryPerDistinctAssignee() {
        let tasks = [
            makeTask(id: "1", assignee: "daneel"),
            makeTask(id: "2", assignee: "daneel"),
            makeTask(id: "3", assignee: "quentin")
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        let names = summaries.map(\.name)
        #expect(names.count == 2)
        #expect(Set(names) == ["daneel", "quentin"])
    }

    @Test func buildAgentSummariesFiltersTasksWithNilAssignee() {
        let tasks = [
            makeTask(id: "1", assignee: "daneel"),
            makeTask(id: "2", assignee: nil)
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        #expect(summaries.map(\.name) == ["daneel"])
    }

    @Test func buildAgentSummariesFiltersEmptyAndWhitespaceAssignees() {
        // The kanban picker must never show a blank entry to the user.
        // External writers (CLI, db backups) may produce whitespace-only assignees.
        let tasks = [
            makeTask(id: "1", assignee: "daneel"),
            makeTask(id: "2", assignee: ""),
            makeTask(id: "3", assignee: "   "),
            makeTask(id: "4", assignee: "\t\n")
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        #expect(summaries.map(\.name) == ["daneel"])
    }

    @Test func buildAgentSummariesSortsAlphabeticallyCaseInsensitive() {
        let tasks = [
            makeTask(id: "1", assignee: "Quentin"),
            makeTask(id: "2", assignee: "alice"),
            makeTask(id: "3", assignee: "Daneel")
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        #expect(summaries.map(\.name) == ["alice", "Daneel", "Quentin"])
    }

    @Test func buildAgentSummariesMarksAgentOnlineWhenTaskRunning() {
        let tasks = [
            makeTask(id: "1", assignee: "daneel", status: .running)
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        let summary = summaries.first
        #expect(summary?.health == .online)
        #expect(summary?.activeTaskCount == 1)
    }

    @Test func buildAgentSummariesMarksAgentIdleWhenNoRunningTasks() {
        let tasks = [
            makeTask(id: "1", assignee: "daneel", status: .todo),
            makeTask(id: "2", assignee: "daneel", status: .done)
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        let summary = summaries.first
        #expect(summary?.health == .idle)
        #expect(summary?.activeTaskCount == 0)
    }

    // MARK: - Helpers

    private func makeTask(
        id: String,
        assignee: String?,
        status: KanbanStatus = .todo
    ) -> KanbanTask {
        KanbanTask(
            id: id,
            title: "Task \(id)",
            assignee: assignee,
            status: status
        )
    }
}
