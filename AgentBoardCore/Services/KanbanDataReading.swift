import Foundation

/// Read-side protocol over `~/.hermes/kanban.db`. Parallels `KanbanCLIWriting`
/// so that `AgentsStore` can be tested with an in-memory fake instead of
/// pointing the live `KanbanDataService` at `/dev/null`.
public protocol KanbanDataReading: Sendable {
    /// Close + re-open the underlying SQLite handle so the next fetch sees
    /// the latest on-disk state. Returns true if the reopen ran.
    @discardableResult
    func refresh() async throws -> Bool

    /// Fetch kanban tasks, optionally filtered by status and tenant.
    func fetchTasks(
        status: KanbanStatus?,
        tenant: String?,
        excludeArchived: Bool
    ) async throws -> [KanbanTask]

    /// Parent + child task IDs for the given task.
    func fetchLinks(for taskID: String) async throws -> (parents: [String], children: [String])

    /// All comments for a task in chronological order.
    func fetchComments(for taskID: String) async throws -> [KanbanComment]

    /// All runs (execution history) for a task in chronological order.
    func fetchRuns(for taskID: String) async throws -> [KanbanRun]
}

public extension KanbanDataReading {
    /// Convenience form matching `KanbanDataService.fetchTasks()`'s default args.
    func fetchTasks() async throws -> [KanbanTask] {
        try await fetchTasks(status: nil, tenant: nil, excludeArchived: true)
    }
}

extension KanbanDataService: KanbanDataReading {}
