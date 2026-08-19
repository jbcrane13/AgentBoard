import Foundation

/// `KanbanDataReading` conformer backed by a **remote** Hermes dashboard's
/// bundled kanban plugin API instead of the local `~/.hermes/kanban.db`.
/// `KanbanDataService` (the SQLite-backed conformer) is untouched — this is
/// an alternate implementation of the same protocol, selected by whoever
/// wires up `AgentsStore` for a remote-gateway profile.
public actor HTTPKanbanBackend: KanbanDataReading {
    private let client: HermesDashboardClient
    /// Populated on every board fetch. Nothing in this conformer reads it
    /// back — `fetchLatestEventID()` always re-fetches for freshness — but
    /// it's kept as actor state per the design contract so a future caller
    /// (e.g. a cheaper "did anything change" check) has it without another
    /// round trip.
    private var cachedLatestEventID: Int?

    public init(client: HermesDashboardClient) {
        self.client = client
    }

    /// There is no persistent local handle to reopen — every fetch already
    /// hits the network fresh — so this is a no-op that reports success.
    @discardableResult
    public func refresh() async throws -> Bool {
        true
    }

    /// `GET /board` returns only the eight non-archived board columns, so this
    /// backend structurally cannot see archived tasks. Rather than silently
    /// return a subset for `excludeArchived: false` — verified against the
    /// remote host, which has 7 archived tasks the board endpoint omits — this
    /// refuses the query. No production caller asks for archived tasks; the
    /// protocol's `fetchTasks()` convenience passes `excludeArchived: true`.
    public func fetchTasks(
        status: KanbanStatus?,
        tenant: String?,
        excludeArchived: Bool
    ) async throws -> [KanbanTask] {
        guard excludeArchived else {
            throw HermesDashboardClient.DashboardError.unsupportedQuery(
                "the dashboard board endpoint omits archived tasks; "
                    + "excludeArchived: false cannot be served over HTTP"
            )
        }
        let board = try await fetchBoard()
        let tasks = (board.columns ?? []).flatMap { $0.tasks ?? [] }.compactMap { $0.toKanbanTask() }
        return tasks.filter { task in
            // Defensive: the board endpoint has no archived column today, but
            // filter anyway so a future Hermes that adds one cannot leak
            // archived tasks into a caller that asked to exclude them.
            if task.status == .archived { return false }
            if let status, task.status != status { return false }
            if let tenant, task.tenant != tenant { return false }
            return true
        }
    }

    public func fetchLatestEventID() async throws -> Int {
        try await fetchBoard().latestEventID ?? 0
    }

    public func fetchLinks(for taskID: String) async throws -> (parents: [String], children: [String]) {
        let detail = try await fetchDetail(taskID: taskID)
        return detail.links?.resolved ?? ([], [])
    }

    /// Ascending by `createdAt`, matching `KanbanDataService.fetchComments`'s
    /// `ORDER BY created_at ASC`.
    public func fetchComments(for taskID: String) async throws -> [KanbanComment] {
        let detail = try await fetchDetail(taskID: taskID)
        let comments = (detail.comments ?? []).compactMap { $0.toKanbanComment() }
        return comments.sorted { $0.createdAt < $1.createdAt }
    }

    /// Descending by `startedAt`, matching `KanbanDataService.fetchRuns`'s
    /// `ORDER BY started_at DESC`.
    public func fetchRuns(for taskID: String) async throws -> [KanbanRun] {
        let detail = try await fetchDetail(taskID: taskID)
        let runs = (detail.runs ?? []).compactMap { $0.toKanbanRun() }
        return runs.sorted { $0.startedAt > $1.startedAt }
    }

    /// Descending by `createdAt`, ties broken by descending `id`, then capped
    /// to `limit` — matching `KanbanDataService.fetchEvents`'s
    /// `ORDER BY created_at DESC, id DESC LIMIT ?`. The tie-break matters:
    /// Hermes writes several events (e.g. `spawned`/`claimed`) within the same
    /// epoch second, and without it the two backends disagree on their order.
    public func fetchEvents(taskID: String, limit: Int) async throws -> [KanbanEvent] {
        let detail = try await fetchDetail(taskID: taskID)
        let events = (detail.events ?? []).compactMap { $0.toKanbanEvent() }
            .sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
        return Array(events.prefix(limit))
    }

    // MARK: - Requests

    /// `GET /board` is the only endpoint carrying `latest_event_id`, so
    /// `fetchLatestEventID()` pays for a full task-list fetch it doesn't
    /// otherwise need — a real tradeoff against `KanbanDataService`'s
    /// dedicated `SELECT COALESCE(MAX(id), 0) FROM task_events`, accepted
    /// because the plugin API has no lighter-weight endpoint for it.
    private func fetchBoard() async throws -> DashboardBoardResponse {
        let board = try await client.get("api/plugins/kanban/board", as: DashboardBoardResponse.self)
        cachedLatestEventID = board.latestEventID
        return board
    }

    private func fetchDetail(taskID: String) async throws -> DashboardTaskDetailResponse {
        try await client.get("api/plugins/kanban/tasks/\(taskID)", as: DashboardTaskDetailResponse.self)
    }
}
