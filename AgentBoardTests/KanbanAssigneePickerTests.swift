import AgentBoardCore
import Foundation
import Testing

/// End-to-end round-trip tests for the kanban "Assigned agent" Picker
/// introduced in `AgentsScreen.createTaskSheet` (issue #88). These walk
/// the full path: Picker tag → `KanbanCreateDraft.assignee` → `KanbanTask`
/// → `displayAssignee`, so a regression anywhere in that chain shows up
/// as a user-visible string mismatch.
@Suite("Kanban assignee picker round-trip (issue #88)")
struct KanbanAssigneePickerTests {
    @Test func unassignedTagRoundTripsToUnassignedDisplayString() {
        // Picker renders Text("Unassigned").tag("") — the empty tag must
        // travel through the draft and surface as the literal "unassigned"
        // copy on the task row, not an empty space.
        let pickedTag = ""
        let draft = KanbanCreateDraft(
            title: "Investigate flake",
            assignee: pickedTag.trimmedOrNil
        )
        let task = KanbanTask(
            id: "t-1",
            title: draft.title,
            assignee: draft.assignee
        )
        #expect(draft.assignee == nil)
        #expect(task.displayAssignee == "unassigned")
    }

    @Test func agentNameTagRoundTripsToAgentDisplayString() {
        // Picker renders Text(agent.name).tag(agent.name) — that name must
        // make it onto the task row unchanged.
        let pickedTag = "claude"
        let draft = KanbanCreateDraft(
            title: "Investigate flake",
            assignee: pickedTag.trimmedOrNil
        )
        let task = KanbanTask(
            id: "t-1",
            title: draft.title,
            assignee: draft.assignee
        )
        #expect(draft.assignee == "claude")
        #expect(task.displayAssignee == "claude")
    }

    @Test func headerDefaultPicksFirstSummaryWhenAvailable() {
        // The header's + button initializes draftAssignee to
        // `summaries.first?.name ?? ""`. With one or more summaries, the
        // default selection must resolve to that first agent's name.
        let summaries = [
            AgentSummary(
                id: "claude",
                name: "Claude",
                health: .idle,
                activeTaskCount: 0,
                activeSessionCount: 0,
                recentActivity: ""
            ),
            AgentSummary(
                id: "codex",
                name: "Codex",
                health: .online,
                activeTaskCount: 1,
                activeSessionCount: 1,
                recentActivity: ""
            )
        ]
        let pickedTag = summaries.first?.name ?? ""
        let draft = KanbanCreateDraft(
            title: "Investigate flake",
            assignee: pickedTag.trimmedOrNil
        )
        #expect(draft.assignee == "Claude")
    }

    @Test func headerDefaultFallsBackToUnassignedWhenSummariesEmpty() {
        // When AgentsStore.summaries is empty, the header initializer's
        // `?? ""` fallback kicks in and the resulting draft is unassigned.
        let summaries: [AgentSummary] = []
        let pickedTag = summaries.first?.name ?? ""
        let draft = KanbanCreateDraft(
            title: "Investigate flake",
            assignee: pickedTag.trimmedOrNil
        )
        #expect(draft.assignee == nil)
    }
}
