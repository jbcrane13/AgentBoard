import AgentBoardCore
import Foundation
import SQLite3

// swiftformat:disable:next modifierOrder
nonisolated private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private final class SQLiteHandle: @unchecked Sendable {
    var raw: OpaquePointer?

    deinit {
        if let raw {
            sqlite3_close(raw)
        }
    }
}

public actor CompanionSQLiteStore {
    public enum StoreError: LocalizedError {
        case openFailed(String)
        case prepareFailed(String)
        case stepFailed(String)
        case notFound

        public var errorDescription: String? {
            switch self {
            case let .openFailed(message):
                "Unable to open the companion database: \(message)"
            case let .prepareFailed(message):
                "Unable to prepare the companion database query: \(message)"
            case let .stepFailed(message):
                "Unable to update the companion database: \(message)"
            case .notFound:
                "The requested companion record was not found."
            }
        }
    }

    private let databaseURL: URL
    private let handle = SQLiteHandle()

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let result = sqlite3_open_v2(
            databaseURL.path,
            &handle.raw,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard result == SQLITE_OK else {
            throw StoreError.openFailed(Self.sqliteMessage(handle.raw))
        }
    }

    public func initializeSchema() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY NOT NULL,
                source TEXT NOT NULL,
                status TEXT NOT NULL,
                linked_task_id TEXT,
                repo_owner TEXT,
                repo_name TEXT,
                issue_number INTEGER,
                model TEXT,
                started_at REAL NOT NULL,
                last_seen_at REAL NOT NULL
            );
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS agents (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                health TEXT NOT NULL,
                active_task_count INTEGER NOT NULL,
                active_session_count INTEGER NOT NULL,
                recent_activity TEXT NOT NULL,
                updated_at REAL NOT NULL
            );
            """
        )

        runMigrations()
    }

    private func runMigrations() {
        let sessionMigrations = [
            "ALTER TABLE sessions ADD COLUMN pid INTEGER;",
            "ALTER TABLE sessions ADD COLUMN tmux_session TEXT;",
            "ALTER TABLE sessions ADD COLUMN tmux_pane_id TEXT;",
            "ALTER TABLE sessions ADD COLUMN last_output TEXT;"
        ]
        for sql in sessionMigrations {
            try? execute(sql)
        }
    }

    // MARK: - Sessions

    public func replaceSessions(_ sessions: [AgentSession]) throws {
        try execute("DELETE FROM sessions;")

        for session in sessions {
            let statement = try prepare(
                """
                INSERT INTO sessions (
                    id, source, status, linked_task_id, repo_owner, repo_name, issue_number,
                    model, started_at, last_seen_at, pid, tmux_session, tmux_pane_id, last_output
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(statement) }

            bind(session.id, to: 1, in: statement)
            bind(session.source, to: 2, in: statement)
            bind(session.status.rawValue, to: 3, in: statement)
            bind(session.linkedTaskID, to: 4, in: statement)
            bind(session.workItem?.repository.owner, to: 5, in: statement)
            bind(session.workItem?.repository.name, to: 6, in: statement)
            if let issueNumber = session.workItem?.issueNumber {
                sqlite3_bind_int(statement, 7, Int32(issueNumber))
            } else {
                sqlite3_bind_null(statement, 7)
            }
            bind(session.model, to: 8, in: statement)
            sqlite3_bind_double(statement, 9, session.startedAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 10, session.lastSeenAt.timeIntervalSince1970)
            if let pid = session.pid {
                sqlite3_bind_int(statement, 11, Int32(pid))
            } else {
                sqlite3_bind_null(statement, 11)
            }
            bind(session.tmuxSession, to: 12, in: statement)
            bind(session.tmuxPaneID, to: 13, in: statement)
            bind(session.lastOutput, to: 14, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
            }
        }
    }

    public func listSessions() throws -> [AgentSession] {
        let statement = try prepare(
            """
            SELECT id, source, status, linked_task_id, repo_owner, repo_name, issue_number,
                   model, started_at, last_seen_at, pid, tmux_session, tmux_pane_id, last_output
            FROM sessions
            ORDER BY last_seen_at DESC;
            """
        )
        defer { sqlite3_finalize(statement) }

        var sessions: [AgentSession] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let issueNumber = sqlite3_column_type(statement, 6) == SQLITE_NULL ? nil : int(statement, index: 6)
            let owner = nullableString(statement, index: 4)
            let name = nullableString(statement, index: 5)
            let pid = sqlite3_column_type(statement, 10) == SQLITE_NULL ? nil : int(statement, index: 10)

            sessions.append(
                AgentSession(
                    id: string(statement, index: 0),
                    source: string(statement, index: 1),
                    status: AgentSessionStatus(rawValue: string(statement, index: 2)) ?? .idle,
                    linkedTaskID: nullableString(statement, index: 3),
                    workItem: {
                        guard let owner, let name, let issueNumber else { return nil }
                        return WorkReference(
                            repository: ConfiguredRepository(owner: owner, name: name),
                            issueNumber: issueNumber
                        )
                    }(),
                    model: nullableString(statement, index: 7),
                    startedAt: date(statement, index: 8),
                    lastSeenAt: date(statement, index: 9),
                    pid: pid,
                    tmuxSession: nullableString(statement, index: 11),
                    tmuxPaneID: nullableString(statement, index: 12),
                    lastOutput: nullableString(statement, index: 13)
                )
            )
        }

        return sessions
    }

    // MARK: - Agents

    public func replaceAgents(_ agents: [AgentSummary]) throws {
        try execute("DELETE FROM agents;")

        for agent in agents {
            let statement = try prepare(
                """
                INSERT INTO agents (
                    id, name, health, active_task_count, active_session_count, recent_activity, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(statement) }

            bind(agent.id, to: 1, in: statement)
            bind(agent.name, to: 2, in: statement)
            bind(agent.health.rawValue, to: 3, in: statement)
            sqlite3_bind_int(statement, 4, Int32(agent.activeTaskCount))
            sqlite3_bind_int(statement, 5, Int32(agent.activeSessionCount))
            bind(agent.recentActivity, to: 6, in: statement)
            sqlite3_bind_double(statement, 7, agent.updatedAt.timeIntervalSince1970)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
            }
        }
    }

    public func listAgents() throws -> [AgentSummary] {
        let statement = try prepare(
            """
            SELECT id, name, health, active_task_count, active_session_count, recent_activity, updated_at
            FROM agents
            ORDER BY active_session_count DESC, name ASC;
            """
        )
        defer { sqlite3_finalize(statement) }

        var agents: [AgentSummary] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            agents.append(
                AgentSummary(
                    id: string(statement, index: 0),
                    name: string(statement, index: 1),
                    health: AgentHealthStatus(rawValue: string(statement, index: 2)) ?? .idle,
                    activeTaskCount: int(statement, index: 3),
                    activeSessionCount: int(statement, index: 4),
                    recentActivity: string(statement, index: 5),
                    updatedAt: date(statement, index: 6)
                )
            )
        }

        return agents
    }

    // MARK: - Helpers

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(handle.raw, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle.raw, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(Self.sqliteMessage(handle.raw))
        }
        return statement
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func string(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private func nullableString(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return string(statement, index: index)
    }

    private func int(_ statement: OpaquePointer?, index: Int32) -> Int {
        Int(sqlite3_column_int(statement, index))
    }

    private func date(_ statement: OpaquePointer?, index: Int32) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private static func sqliteMessage(_ handle: OpaquePointer?) -> String {
        if let handle, let cString = sqlite3_errmsg(handle) {
            return String(cString: cString)
        }
        return "Unknown SQLite error."
    }
}
