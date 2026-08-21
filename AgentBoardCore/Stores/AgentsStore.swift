import Foundation
import Observation
import os

@MainActor
@Observable
public final class AgentsStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "AgentsStore")
    private var kanbanData: any KanbanDataReading
    private var cliWriter: any KanbanCLIWriting
    private let cache: any AgentBoardCacheProtocol
    private let settingsStore: SettingsStore

    public private(set) var tasks: [KanbanTask] = []
    public private(set) var summaries: [AgentSummary] = []
    public private(set) var isLoading = false
    public var errorMessage: String?
    public var statusMessage: String?

    private var didBootstrap = false
    private var lastFingerprint: String = ""

    private static let localLiveUpdateInterval: Duration = .seconds(2)
    /// `fetchLatestEventID()` on the remote HTTP backend
    /// (`HTTPKanbanBackend`) pays for a full `GET /board` — the dashboard
    /// has no lighter "did anything change" endpoint — so every poll
    /// transfers the whole board over the network. 2s (the local SQLite
    /// cadence, an indexed `MAX(id)` read) would hammer a remote dashboard
    /// host for no benefit; 15s keeps the board reasonably live without
    /// doing that.
    private static let remoteLiveUpdateInterval: Duration = .seconds(15)
    /// Failure backoff floor. Never shorter than the locality's normal
    /// cadence — the remote 15s cadence already throttles network cost, so
    /// backing off to a flat 30s only matters when it's longer than that.
    private static let minimumBackoffInterval: Duration = .seconds(30)
    private var liveUpdateTask: Task<Void, Never>?
    private var lastKnownEventID: Int?
    /// Internal (not `private`) so tests can assert the cadence follows
    /// `backendLocality`, matching `pollForChanges()`'s testability rationale.
    var liveUpdatePollInterval: Duration
    private var hasLoggedLiveUpdateFailure = false
    public private(set) var backendLocality: KanbanBackendLocality

    public init(
        kanbanData: any KanbanDataReading = KanbanDataService(),
        cliWriter: any KanbanCLIWriting = KanbanCLIWriter(),
        cache: any AgentBoardCacheProtocol,
        settingsStore: SettingsStore,
        backendLocality: KanbanBackendLocality = .local
    ) {
        self.kanbanData = kanbanData
        self.cliWriter = cliWriter
        self.cache = cache
        self.settingsStore = settingsStore
        self.backendLocality = backendLocality
        liveUpdatePollInterval = Self.normalLiveUpdateInterval(for: backendLocality)
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

        // Load the cache first so the board renders instantly, then refresh
        // from kanban.db for the live snapshot.
        do {
            let cachedTasks = try cache.loadKanbanTasks()
            if !cachedTasks.isEmpty {
                tasks = cachedTasks
                summaries = Self.buildAgentSummaries(from: tasks)
                lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            }
        } catch {
            logger.error("Failed to load kanban cache: \(error.localizedDescription, privacy: .public)")
        }

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

                do {
                    try cache.replaceKanbanTasks(tasks)
                } catch {
                    logger.error("Failed to persist kanban cache: \(error.localizedDescription, privacy: .public)")
                }
            }
            // Data unchanged — skip SwiftUI invalidation and the cache write

            errorMessage = nil
            if tasks.isEmpty {
                statusMessage = "No kanban tasks yet. Create one below or via `hermes kanban create`."
            } else {
                statusMessage = nil
            }
        } catch {
            logger.error("Failed to refresh kanban: \(error.localizedDescription, privacy: .public)")
            // Keep any cached/previous tasks visible rather than clearing the board.
            if tasks.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = nil
                statusMessage = "Showing cached tasks — kanban refresh failed."
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
            upsert(task)
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

    /// Recent kanban events for a task (for the detail sheet's Events section).
    public func fetchEvents(for taskID: String) async throws -> [KanbanEvent] {
        try await kanbanData.fetchEvents(taskID: taskID)
    }

    // MARK: - Backend Selection

    /// Swap the active kanban backend + writer + their shared locality —
    /// called by `AgentBoardAppModel` whenever the active Hermes profile's
    /// dashboard configuration changes (bootstrap, profile switch, or a
    /// saved dashboard URL edit). The writer must always travel together
    /// with the reader: they're selected as a pair by
    /// `KanbanBackendFactory.makeBackend`, and swapping only the reader
    /// here would silently let the board read one Hermes host while writes
    /// (create/comment/complete/block/...) landed on a different one — the
    /// exact drift `KanbanCLIWriter` always spawning the *local* `hermes`
    /// binary caused before this fix (issue #207). Resets the live-update
    /// baseline so the first poll against the new backend doesn't compare
    /// an event id from one data source against a baseline recorded from
    /// another.
    public func updateBackend(
        _ kanbanData: any KanbanDataReading,
        writer: any KanbanCLIWriting,
        locality: KanbanBackendLocality
    ) {
        self.kanbanData = kanbanData
        cliWriter = writer
        backendLocality = locality
        liveUpdatePollInterval = Self.normalLiveUpdateInterval(for: locality)
        hasLoggedLiveUpdateFailure = false
        lastKnownEventID = nil
    }

    // MARK: - Live Updates

    /// Starts a background loop that polls `task_events` and triggers a
    /// full `refresh()` only when the latest event id has advanced. Cadence
    /// follows `backendLocality`: 2s for the local SQLite backend (a cheap
    /// indexed `MAX(id)` read), 15s for the remote HTTP backend (see
    /// `remoteLiveUpdateInterval`). Falls back to a quiet ≥30s poll after
    /// the first failure (e.g. `kanban.db` missing on iOS, Hermes not
    /// installed, or the remote dashboard unreachable) — poll failures
    /// never surface in `errorMessage`; `refresh()`'s existing error
    /// surface stays authoritative.
    public func startLiveUpdates() {
        liveUpdateTask?.cancel()
        liveUpdateTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: self.liveUpdatePollInterval)
                guard !Task.isCancelled else { return }
                await self.pollForChanges()
            }
        }
    }

    public func stopLiveUpdates() {
        liveUpdateTask?.cancel()
        liveUpdateTask = nil
    }

    /// Single live-update poll iteration. Factored out of the sleep loop so
    /// tests can drive one iteration directly. Returns whether it triggered
    /// a `refresh()`.
    ///
    /// Cost note: `fetchLatestEventID()` and the `refresh()` it triggers
    /// here are two separate calls. On the local SQLite backend that's
    /// cheap — an indexed `MAX(id)` plus a full task read. On the remote
    /// HTTP backend (`HTTPKanbanBackend`) both calls are a full
    /// `GET /board`, so a changed event id costs two board fetches instead
    /// of one. `KanbanDataReading` has no "fetch tasks and report whether
    /// they changed" call that would let this reuse the id-check fetch, and
    /// widening that protocol is out of scope here, so the double fetch is
    /// accepted and documented rather than eliminated.
    @discardableResult
    func pollForChanges() async -> Bool {
        do {
            let latest = try await kanbanData.fetchLatestEventID()
            recordLiveUpdatePollSuccess()

            guard latest != lastKnownEventID else { return false }
            let isFirstObservation = lastKnownEventID == nil
            lastKnownEventID = latest
            guard !isFirstObservation else { return false }

            await refresh()
            return true
        } catch {
            recordLiveUpdatePollFailure(error)
            return false
        }
    }

    private static func normalLiveUpdateInterval(for locality: KanbanBackendLocality) -> Duration {
        switch locality {
        case .local: localLiveUpdateInterval
        case .remote: remoteLiveUpdateInterval
        }
    }

    private func recordLiveUpdatePollSuccess() {
        liveUpdatePollInterval = Self.normalLiveUpdateInterval(for: backendLocality)
        hasLoggedLiveUpdateFailure = false
    }

    private func recordLiveUpdatePollFailure(_ error: Error) {
        liveUpdatePollInterval = max(Self.minimumBackoffInterval, Self.normalLiveUpdateInterval(for: backendLocality))
        guard !hasLoggedLiveUpdateFailure else { return }
        hasLoggedLiveUpdateFailure = true
        logger.error("Kanban live-update poll failed: \(error.localizedDescription, privacy: .public)")
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

    /// Build lightweight agent summaries from task assignees. `activeTaskCount`
    /// is the live signal for #157 (running kanban tasks for this agent —
    /// Hermes works tasks inline in long-lived per-profile daemons, so there's
    /// no session record to join against). Client-built summaries don't carry
    /// session counts — only companion-built summaries (via
    /// `CompanionLocalProbe`, from real process/tmux probing) populate
    /// `activeSessionCount`; it's always 0 here.
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
