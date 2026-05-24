import Foundation
import SQLite3

// swiftformat:disable:next modifierOrder
nonisolated private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Read-only access to the Hermes kanban database (`~/.hermes/kanban.db`).
/// Follows Scarf's `HermesDataService` pattern: open read-only, never write,
/// map direct from SQLite rows to Swift structs.
public actor KanbanDataService {
    public enum ServiceError: LocalizedError {
        case openFailed(String)
        case queryFailed(String)

        public var errorDescription: String? {
            switch self {
            case let .openFailed(msg): "Cannot open kanban database: \(msg)"
            case let .queryFailed(msg): "Kanban query failed: \(msg)"
            }
        }
    }

    private let databasePath: String
    // swiftlint:disable:next modifier_order
    private nonisolated(unsafe) var db: OpaquePointer?
    private(set) var lastError: String?

    // MARK: - Init

    /// Defaults to `~/.hermes/kanban.db`.
    public init(databasePath: String? = nil) {
        self.databasePath = databasePath
            ?? (NSHomeDirectory() + "/.hermes/kanban.db")
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - Open / Close

    public func open() throws {
        guard db == nil else { return }

        let result = sqlite3_open_v2(
            databasePath,
            &db,
            SQLITE_OPEN_READONLY,
            nil
        )

        guard result == SQLITE_OK else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2 returned \(result)"
            throw ServiceError.openFailed(msg)
        }

        // Enable WAL for concurrent readers
        _ = execute("PRAGMA journal_mode=WAL")
    }

    public func close() {
        guard let db else { return }
        sqlite3_close(db)
        self.db = nil
    }

    /// Re-open for freshness. Local read-only close+reopen is essentially free.
    @discardableResult
    public func refresh() throws -> Bool {
        close()
        try open()
        return true
    }

    // MARK: - Tasks

    public func fetchTasks(
        status: KanbanStatus? = nil,
        tenant: String? = nil,
        excludeArchived: Bool = true
    ) throws -> [KanbanTask] {
        let db = try requireDB()

        var clauses: [String] = []
        if excludeArchived { clauses.append("status != 'archived'") }
        if status != nil { clauses.append("status = ?") }
        if tenant != nil { clauses.append("tenant = ?") }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        let sql = """
        SELECT id, title, body, assignee, status, priority, created_by,
               created_at, started_at, completed_at, workspace_kind,
               workspace_path, tenant, result, skills
        FROM tasks
        \(whereSQL)
        ORDER BY created_at DESC
        LIMIT 500
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ServiceError.queryFailed(errorMessage(db))
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        var bindIdx: Int32 = 1
        if let status { bind(status.rawValue, to: bindIdx, in: stmt)
            bindIdx += 1
        }
        if let tenant { bind(tenant, to: bindIdx, in: stmt)
            bindIdx += 1
        }

        var tasks: [KanbanTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            tasks.append(taskFromRow(stmt!))
        }

        return tasks
    }

    public func fetchTask(id: String) throws -> KanbanTask? {
        let db = try requireDB()
        let sql = """
        SELECT id, title, body, assignee, status, priority, created_by,
               created_at, started_at, completed_at, workspace_kind,
               workspace_path, tenant, result, skills
        FROM tasks
        WHERE id = ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ServiceError.queryFailed(errorMessage(db))
        }
        defer { sqlite3_finalize(stmt) }

        bind(id, to: 1, in: stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        return taskFromRow(stmt!)
    }

    // MARK: - Links

    public func fetchLinks(for taskID: String) throws -> (parents: [String], children: [String]) {
        let db = try requireDB()

        var parents: [String] = []
        var parentStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT parent_id FROM task_links WHERE child_id = ?", -1, &parentStmt, nil) ==
            SQLITE_OK {
            defer { sqlite3_finalize(parentStmt) }
            bind(taskID, to: 1, in: parentStmt)
            while sqlite3_step(parentStmt) == SQLITE_ROW {
                parents.append(string(parentStmt, index: 0))
            }
        }

        var children: [String] = []
        var childStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT child_id FROM task_links WHERE parent_id = ?", -1, &childStmt, nil) ==
            SQLITE_OK {
            defer { sqlite3_finalize(childStmt) }
            bind(taskID, to: 1, in: childStmt)
            while sqlite3_step(childStmt) == SQLITE_ROW {
                children.append(string(childStmt, index: 0))
            }
        }

        return (parents, children)
    }

    // MARK: - Comments

    public func fetchComments(for taskID: String) throws -> [KanbanComment] {
        let db = try requireDB()
        let sql = """
        SELECT id, task_id, author, body, created_at
        FROM task_comments
        WHERE task_id = ?
        ORDER BY created_at ASC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ServiceError.queryFailed(errorMessage(db))
        }
        defer { sqlite3_finalize(stmt) }

        bind(taskID, to: 1, in: stmt)

        var comments: [KanbanComment] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            comments.append(
                KanbanComment(
                    id: int(stmt, index: 0),
                    taskID: string(stmt, index: 1),
                    author: string(stmt, index: 2),
                    body: string(stmt, index: 3),
                    createdAt: date(stmt, index: 4)
                )
            )
        }

        return comments
    }

    // MARK: - Runs

    public func fetchRuns(for taskID: String) throws -> [KanbanRun] {
        let db = try requireDB()
        let sql = """
        SELECT id, task_id, profile, status, started_at, ended_at,
               outcome, summary, error
        FROM task_runs
        WHERE task_id = ?
        ORDER BY started_at DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ServiceError.queryFailed(errorMessage(db))
        }
        defer { sqlite3_finalize(stmt) }

        bind(taskID, to: 1, in: stmt)

        var runs: [KanbanRun] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            runs.append(
                KanbanRun(
                    id: int(stmt, index: 0),
                    taskID: string(stmt, index: 1),
                    profile: nullableString(stmt, index: 2),
                    status: string(stmt, index: 3),
                    startedAt: date(stmt, index: 4),
                    endedAt: nullableDate(stmt, index: 5),
                    outcome: nullableString(stmt, index: 6).flatMap(KanbanRunOutcome.init(rawValue:)),
                    summary: nullableString(stmt, index: 7),
                    error: nullableString(stmt, index: 8)
                )
            )
        }

        return runs
    }

    // MARK: - Stats

    public func fetchStats() throws -> [KanbanStatus: Int] {
        let db = try requireDB()
        let sql = "SELECT status, COUNT(*) FROM tasks GROUP BY status"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ServiceError.queryFailed(errorMessage(db))
        }
        defer { sqlite3_finalize(stmt) }

        var stats: [KanbanStatus: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let status = KanbanStatus(rawValue: string(stmt, index: 0)) {
                stats[status] = int(stmt, index: 1)
            }
        }

        return stats
    }

    // MARK: - Row Parsing

    private func taskFromRow(_ stmt: OpaquePointer) -> KanbanTask {
        KanbanTask(
            id: string(stmt, index: 0),
            title: string(stmt, index: 1),
            body: nullableString(stmt, index: 2),
            assignee: nullableString(stmt, index: 3),
            status: KanbanStatus(rawValue: string(stmt, index: 4)) ?? .todo,
            priority: int(stmt, index: 5),
            createdBy: nullableString(stmt, index: 6),
            createdAt: date(stmt, index: 7),
            startedAt: nullableDate(stmt, index: 8),
            completedAt: nullableDate(stmt, index: 9),
            workspaceKind: KanbanWorkspaceKind(rawValue: string(stmt, index: 10)) ?? .scratch,
            workspacePath: nullableString(stmt, index: 11),
            tenant: nullableString(stmt, index: 12),
            result: nullableString(stmt, index: 13),
            skills: parseSkills(nullableString(stmt, index: 14))
        )
    }

    // MARK: - Helpers

    private func requireDB() throws -> OpaquePointer {
        if db == nil { try open() }
        guard let db else { throw ServiceError.openFailed("kanban.db not open") }
        return db
    }

    private func execute(_ sql: String) -> Int32 {
        guard let db else { return -1 }
        return sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func errorMessage(_ handle: OpaquePointer?) -> String {
        if let handle, let cString = sqlite3_errmsg(handle) {
            return String(cString: cString)
        }
        return "Unknown SQLite error"
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func string(_ stmt: OpaquePointer?, index: Int32) -> String {
        guard let value = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: value)
    }

    private func nullableString(_ stmt: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return string(stmt, index: index)
    }

    private func int(_ stmt: OpaquePointer?, index: Int32) -> Int {
        Int(sqlite3_column_int(stmt, index))
    }

    private func date(_ stmt: OpaquePointer?, index: Int32) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(stmt, index))
    }

    private func nullableDate(_ stmt: OpaquePointer?, index: Int32) -> Date? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return date(stmt, index: index)
    }

    private func parseSkills(_ json: String?) -> [String]? {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        let decoded = try? JSONDecoder().decode([String].self, from: data)
        return decoded?.isEmpty == false ? decoded : nil
    }
}
