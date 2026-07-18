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

    // MARK: - Edge cases

    @Test func buildAgentSummariesCountsTasksWithSurroundingWhitespaceAssignee() {
        // CLI/db writes can produce assignees with surrounding whitespace
        // (e.g. "  daneel  "). The Set-of-trimmed-names path must agree with
        // the per-summary task filter so those tasks still count toward the
        // agent's totals — otherwise the picker shows an agent with zero
        // active tasks even when one is running.
        let tasks = [
            makeTask(id: "1", assignee: "  daneel  ", status: .running),
            makeTask(id: "2", assignee: "daneel", status: .todo),
            makeTask(id: "3", assignee: "\tdaneel\n", status: .done)
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        let summary = summaries.first
        #expect(summaries.count == 1)
        #expect(summary?.name == "daneel")
        #expect(summary?.activeTaskCount == 1)
        #expect(summary?.health == .online)
    }

    @Test func buildAgentSummariesPicksRecentActivityFromWhitespacePaddedTask() {
        // recentActivity must reflect the task title even when the assignee
        // is padded — the picker rail surfaces this string under the agent.
        let recentDate = Date(timeIntervalSince1970: 2_000_000_000)
        let olderDate = Date(timeIntervalSince1970: 1_000_000_000)
        let tasks = [
            KanbanTask(
                id: "1",
                title: "older",
                assignee: "daneel",
                createdAt: olderDate
            ),
            KanbanTask(
                id: "2",
                title: "newer",
                assignee: "  daneel  ",
                createdAt: recentDate
            )
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        #expect(summaries.first?.recentActivity == "newer")
    }

    @Test func buildAgentSummariesPreservesDistinctCasingAfterTrimming() {
        // Different casings remain distinct picker entries; trimming must
        // not collapse them into a single summary.
        let tasks = [
            makeTask(id: "1", assignee: "  Claude  "),
            makeTask(id: "2", assignee: "claude")
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        #expect(Set(summaries.map(\.name)) == ["Claude", "claude"])
    }

    // MARK: - Active session count (client-built summaries carry none, #157)

    @Test func buildAgentSummariesActiveSessionCountIsAlwaysZero() {
        // Client-built summaries have no session data to report — only
        // companion-built summaries (CompanionLocalProbe, real process
        // probing) populate activeSessionCount. Running tasks still surface
        // via activeTaskCount (see the health/online tests above).
        let tasks = [
            makeTask(id: "1", assignee: "daneel", status: .running),
            makeTask(id: "2", assignee: "daneel", status: .running)
        ]
        let summaries = AgentsStore.buildAgentSummaries(from: tasks)
        #expect(summaries.first?.activeSessionCount == 0)
        #expect(summaries.first?.activeTaskCount == 2)
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
