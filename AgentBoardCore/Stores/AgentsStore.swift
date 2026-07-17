import Foundation
import Observation
import os

@MainActor
@Observable
public final class AgentsStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "AgentsStore")
    private let kanbanData: any KanbanDataReading
    private let cliWriter: any KanbanCLIWriting
    private let settingsStore: SettingsStore

    public private(set) var tasks: [KanbanTask] = []
    public private(set) var summaries: [AgentSummary] = []
    public private(set) var isLoading = false
    public var errorMessage: String?
    public var statusMessage: String?

    private var didBootstrap = false
    private var lastFingerprint: String = ""

    public init(
        kanbanData: any KanbanDataReading = KanbanDataService(),
        cliWriter: any KanbanCLIWriting = KanbanCLIWriter(),
        settingsStore: SettingsStore
    ) {
        self.kanbanData = kanbanData
        self.cliWriter = cliWriter
        self.settingsStore = settingsStore
    }

    // MARK: - Computed

    /// Tasks grouped by agent assignee for the agent summary rail.
    public var tasksByAgent: [(agent: AgentSummary, tasks: [KanbanTask])] {
        summaries.map { summary in
            (
                summary,
                tasks.filter {
                    $0.assignee?.compare(summary.name, options: .caseInsensitive) == .orderedSame ||
                        $0.assignee?.compare(summary.id, options: .caseInsensitive) == .orderedSame
                }
            )
        }
    }

    /// Tasks grouped by status for kanban columns.
    public var tasksByStatus: [(status: KanbanStatus, tasks: [KanbanTask])] {
        KanbanStatus.boardColumns.map { status in
            (status, tasks.filter { $0.status == status })
        }
    }

    // MARK: - Bootstrap

    public func bootstrap() async {
        guard !didBootstrap else { return }

        // Always refresh from kanban.db — no cache layer for kanban tasks yet.
        await refresh()
        didBootstrap = true
    }

    // MARK: - Refresh

    public func refresh() async {
        isLoading = true

        do {
            // Refresh the read connection (close + reopen for fresh snapshot)
            try await kanbanData.refresh()
            let freshTasks = try await kanbanData.fetchTasks()

            // Build pseudo agent summaries from task assignees (companion still
            // handles real agent health / session data separately)
            let freshSummaries = Self.buildAgentSummaries(from: freshTasks)

            let newFingerprint = fingerprint(tasks: freshTasks, summaries: freshSummaries)
            if newFingerprint != lastFingerprint {
                tasks = freshTasks
                summaries = freshSummaries
                lastFingerprint = newFingerprint
            }
            // Data unchanged — skip SwiftUI invalidation

            errorMessage = nil
            if tasks.isEmpty {
                statusMessage = "No kanban tasks yet. Create one below or via `hermes kanban create`."
            } else {
                statusMessage = nil
            }
        } catch {
            logger.error("Failed to refresh kanban: \(error.localizedDescription, privacy: .public)")
            if tasks.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Create Task

    public func createTask(_ draft: KanbanCreateDraft) async {
        do {
            let task = try await cliWriter.create(draft)
            upsert(task)
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            statusMessage = "Created task \"\(task.title)\"."
            errorMessage = nil
        } catch {
            logger.error("Failed to create kanban task: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Task (reassign, comment)

    public func updateTaskAssignee(id: String, newAssignee: String) async {
        guard var task = tasks.first(where: { $0.id == id }) else { return }
        do {
            try await cliWriter.assign(taskID: id, assignee: newAssignee)
            task.assignee = newAssignee
            upsert(task)
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            statusMessage = "Reassigned \"\(task.title)\" to \(newAssignee)."
            errorMessage = nil
        } catch {
            logger.error("Failed to reassign task: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func commentOnTask(id: String, body: String) async {
        do {
            try await cliWriter.comment(taskID: id, body: body)
            statusMessage = "Comment added."
            errorMessage = nil
        } catch {
            logger.error("Failed to comment: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Complete / Block / Archive

    public func completeTask(id: String, summary: String) async {
        guard var task = tasks.first(where: { $0.id == id }) else { return }
        do {
            try await cliWriter.complete(taskID: id, summary: summary)
            task.status = .done
            task.completedAt = .now
            task.result = summary
            upsert(task)
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            statusMessage = "Completed \"\(task.title)\"."
            errorMessage = nil
        } catch {
            logger.error("Failed to complete task: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func blockTask(id: String, reason: String) async {
        guard var task = tasks.first(where: { $0.id == id }) else { return }
        do {
            try await cliWriter.block(taskID: id, reason: reason)
            task.status = .blocked
            upsert(task)
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            statusMessage = "Blocked \"\(task.title)\"."
            errorMessage = nil
        } catch {
            logger.error("Failed to block task: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Board Drag-and-Drop

    /// Move a task to `target` via drag-and-drop. Illegal drops (per
    /// `KanbanBoardMove.forDrag`) never touch the CLI — they just surface a
    /// rejection message. Legal drops update optimistically, then revert and
    /// surface an error if the CLI write fails.
    public func moveTask(id: String, to target: KanbanStatus) async {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        let previousStatus = task.status

        guard let move = KanbanBoardMove.forDrag(from: previousStatus, to: target) else {
            statusMessage = KanbanBoardMove.rejectionMessage(from: previousStatus, to: target)
            return
        }

var updated = task
updated.status = target
if move == .complete {
    updated.completedAt = .now
    updated.result = "Completed from board"
}
upsert(updated)
lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
        do {
            switch move {
            case .promote:
                try await cliWriter.promote(taskID: id)
            case .block:
                try await cliWriter.block(taskID: id, reason: "Blocked from board")
            case .unblock:
                try await cliWriter.unblock(taskID: id)
            case .complete:
                try await cliWriter.complete(taskID: id, summary: "Completed from board")
            }
            statusMessage = "Moved \"\(task.title)\" to \(target.title)."
            errorMessage = nil
        } catch {
            logger.error("Failed to move task: \(error.localizedDescription, privacy: .public)")
            var reverted = updated
            reverted.status = previousStatus
            upsert(reverted)
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            errorMessage = error.localizedDescription
        }
    }

    public func archiveTask(id: String) async {
        do {
            try await cliWriter.archive(taskID: id)
            tasks.removeAll { $0.id == id }
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            statusMessage = "Task archived."
            errorMessage = nil
        } catch {
            logger.error("Failed to archive task: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Detail Enrichment

    /// Fetch comments + runs for a specific task (for detail sheet).
    public func fetchComments(for taskID: String) async throws -> [KanbanComment] {
        try await kanbanData.fetchComments(for: taskID)
    }

    public func fetchRuns(for taskID: String) async throws -> [KanbanRun] {
        try await kanbanData.fetchRuns(for: taskID)
    }

    /// Fetch parent/child IDs for a task.
    public func fetchLinks(for taskID: String) async throws -> (parents: [String], children: [String]) {
        try await kanbanData.fetchLinks(for: taskID)
    }

    // MARK: - Internal

    private func upsert(_ task: KanbanTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        tasks.sort { $0.createdAt > $1.createdAt }
    }

    /// Build lightweight agent summaries from task assignees.
    /// The companion service still owns actual agent health / session data.
    /// Internal so the kanban picker data source can be unit tested directly.
    nonisolated static func buildAgentSummaries(from tasks: [KanbanTask]) -> [AgentSummary] {
        let assignees = Set(tasks.compactMap { $0.assignee?.trimmedOrNil })

        return assignees.map { name in
            // Filter by trimmed value so tasks whose assignee carries
            // surrounding whitespace (CLI/db writes) still count toward the
            // matching summary's totals and recent activity.
            let agentTasks = tasks.filter { $0.assignee?.trimmedOrNil == name }
            let activeCount = agentTasks.filter { $0.status == .running }.count
            let recentTask = agentTasks.max(by: { $0.createdAt < $1.createdAt })

            return AgentSummary(
                id: name.lowercased(),
                name: name,
                health: activeCount > 0 ? .online : .idle,
                activeTaskCount: activeCount,
                activeSessionCount: 0,
                recentActivity: recentTask?.title ?? "No recent activity",
                updatedAt: recentTask?.createdAt ?? .now
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func fingerprint(tasks: [KanbanTask], summaries: [AgentSummary]) -> String {
        let taskFP = tasks.map { "\($0.id):\($0.status.rawValue):\($0.title)" }.joined(separator: "|")
        let summaryFP = summaries.map { "\($0.id):\($0.activeSessionCount)" }.joined(separator: "|")
        return "\(taskFP)||\(summaryFP)"
    }
}
