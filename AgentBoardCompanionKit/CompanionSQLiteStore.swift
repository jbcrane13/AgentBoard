// swiftlint:disable file_length
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

// swiftlint:disable:next type_body_length
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

        try execute(
            """
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                model_id TEXT,
                updated_at REAL NOT NULL,
                hermes_session_id TEXT
            );
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS conversation_messages (
                id TEXT PRIMARY KEY NOT NULL,
                conversation_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at REAL NOT NULL,
                is_streaming INTEGER NOT NULL DEFAULT 0,
                attachments_json TEXT,
                FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS session_transcripts (
                session_id TEXT PRIMARY KEY NOT NULL,
                content TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                is_final INTEGER NOT NULL DEFAULT 0
            );
            """
        )

        runMigrations()
    }

    private func runMigrations() {
        guard let sessionColumns = try? existingSessionColumns() else { return }

        let sessionMigrations: [(column: String, type: String)] = [
            ("pid", "INTEGER"),
            ("tmux_session", "TEXT"),
            ("tmux_pane_id", "TEXT"),
            ("last_output", "TEXT")
        ]
        for (column, type) in sessionMigrations {
            guard !sessionColumns.contains(column) else { continue }
            try? execute("ALTER TABLE sessions ADD COLUMN \(column) \(type);")
        }

        if let messageColumns = try? existingColumns(table: "conversation_messages"),
           !messageColumns.contains("attachments_json") {
            try? execute("ALTER TABLE conversation_messages ADD COLUMN attachments_json TEXT;")
        }

        if let conversationColumns = try? existingColumns(table: "conversations"),
           !conversationColumns.contains("hermes_session_id") {
            try? execute("ALTER TABLE conversations ADD COLUMN hermes_session_id TEXT;")
        }
    }

    private func existingSessionColumns() throws -> Set<String> {
        try existingColumns(table: "sessions")
    }

    private func existingColumns(table: String) throws -> Set<String> {
        let statement = try prepare("PRAGMA table_info(\(table));")
        defer { sqlite3_finalize(statement) }

        var columns: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            columns.insert(string(statement, index: 1)) // column 1 = name
        }
        return columns
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

    // MARK: - Conversations

    public func replaceConversations(_ conversations: [ChatConversation]) throws {
        try execute("DELETE FROM conversation_messages;")
        try execute("DELETE FROM conversations;")

        for conversation in conversations {
            let statement = try prepare(
                """
                INSERT INTO conversations (id, title, model_id, updated_at, hermes_session_id)
                VALUES (?, ?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(statement) }

            bind(conversation.id.uuidString, to: 1, in: statement)
            bind(conversation.title, to: 2, in: statement)
            bind(conversation.modelID, to: 3, in: statement)
            sqlite3_bind_double(statement, 4, conversation.updatedAt.timeIntervalSince1970)
            bind(conversation.hermesSessionID, to: 5, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
            }
        }
    }

    public func listConversations() throws -> [ChatConversation] {
        let statement = try prepare(
            """
            SELECT id, title, model_id, updated_at, hermes_session_id
            FROM conversations
            ORDER BY updated_at DESC;
            """
        )
        defer { sqlite3_finalize(statement) }

        var conversations: [ChatConversation] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = UUID(uuidString: string(statement, index: 0)) else { continue }
            conversations.append(
                ChatConversation(
                    id: id,
                    title: string(statement, index: 1),
                    modelID: nullableString(statement, index: 2),
                    updatedAt: date(statement, index: 3),
                    hermesSessionID: nullableString(statement, index: 4)
                )
            )
        }

        return conversations
    }

    public func saveConversationSnapshot(conversation: ChatConversation, messages: [ConversationMessage]) throws {
        let deleteConv = try prepare("DELETE FROM conversations WHERE id = ?;")
        defer { sqlite3_finalize(deleteConv) }
        bind(conversation.id.uuidString, to: 1, in: deleteConv)
        guard sqlite3_step(deleteConv) == SQLITE_DONE else {
            throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
        }

        let deleteMsgs = try prepare("DELETE FROM conversation_messages WHERE conversation_id = ?;")
        defer { sqlite3_finalize(deleteMsgs) }
        bind(conversation.id.uuidString, to: 1, in: deleteMsgs)
        guard sqlite3_step(deleteMsgs) == SQLITE_DONE else {
            throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
        }

        let insertConv = try prepare(
            """
            INSERT INTO conversations (id, title, model_id, updated_at, hermes_session_id)
            VALUES (?, ?, ?, ?, ?);
            """
        )
        defer { sqlite3_finalize(insertConv) }

        bind(conversation.id.uuidString, to: 1, in: insertConv)
        bind(conversation.title, to: 2, in: insertConv)
        bind(conversation.modelID, to: 3, in: insertConv)
        sqlite3_bind_double(insertConv, 4, conversation.updatedAt.timeIntervalSince1970)
        bind(conversation.hermesSessionID, to: 5, in: insertConv)

        guard sqlite3_step(insertConv) == SQLITE_DONE else {
            throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
        }

        for message in messages {
            let insertMsg = try prepare(
                """
                INSERT INTO conversation_messages (
                    id, conversation_id, role, content, created_at, is_streaming, attachments_json
                )
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(insertMsg) }

            bind(message.id.uuidString, to: 1, in: insertMsg)
            bind(message.conversationID.uuidString, to: 2, in: insertMsg)
            bind(message.role.rawValue, to: 3, in: insertMsg)
            bind(message.content, to: 4, in: insertMsg)
            sqlite3_bind_double(insertMsg, 5, message.createdAt.timeIntervalSince1970)
            sqlite3_bind_int(insertMsg, 6, message.isStreaming ? 1 : 0)
            bind(attachmentsJSON(for: message), to: 7, in: insertMsg)

            guard sqlite3_step(insertMsg) == SQLITE_DONE else {
                throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
            }
        }
    }

    public func loadMessages(conversationID: UUID) throws -> [ConversationMessage] {
        let statement = try prepare(
            """
            SELECT id, conversation_id, role, content, created_at, is_streaming, attachments_json
            FROM conversation_messages
            WHERE conversation_id = ?
            ORDER BY created_at ASC;
            """
        )
        defer { sqlite3_finalize(statement) }

        bind(conversationID.uuidString, to: 1, in: statement)

        var messages: [ConversationMessage] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let id = UUID(uuidString: string(statement, index: 0)),
                let cid = UUID(uuidString: string(statement, index: 1)),
                let role = MessageRole(rawValue: string(statement, index: 2)) else { continue }

            messages.append(
                ConversationMessage(
                    id: id,
                    conversationID: cid,
                    role: role,
                    content: string(statement, index: 3),
                    createdAt: date(statement, index: 4),
                    isStreaming: sqlite3_column_int(statement, 5) != 0,
                    attachments: attachments(from: nullableString(statement, index: 6))
                )
            )
        }

        return messages
    }

    public func deleteConversation(id: UUID) throws {
        let deleteMsgs = try prepare("DELETE FROM conversation_messages WHERE conversation_id = ?;")
        defer { sqlite3_finalize(deleteMsgs) }
        bind(id.uuidString, to: 1, in: deleteMsgs)
        guard sqlite3_step(deleteMsgs) == SQLITE_DONE else {
            throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
        }

        let deleteConv = try prepare("DELETE FROM conversations WHERE id = ?;")
        defer { sqlite3_finalize(deleteConv) }
        bind(id.uuidString, to: 1, in: deleteConv)
        guard sqlite3_step(deleteConv) == SQLITE_DONE else {
            throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
        }
    }

    // MARK: - Session transcripts

    public func upsertTranscript(sessionID: String, content: String, isFinal: Bool) throws {
        let statement = try prepare(
            """
            INSERT INTO session_transcripts (session_id, content, updated_at, is_final)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(session_id) DO UPDATE SET
                content = excluded.content,
                updated_at = excluded.updated_at,
                is_final = excluded.is_final;
            """
        )
        defer { sqlite3_finalize(statement) }

        bind(sessionID, to: 1, in: statement)
        bind(content, to: 2, in: statement)
        sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))
        sqlite3_bind_int(statement, 4, isFinal ? 1 : 0)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
        }
    }

    public func transcript(sessionID: String) throws -> (content: String, updatedAt: Date, isFinal: Bool)? {
        let statement = try prepare(
            "SELECT content, updated_at, is_final FROM session_transcripts WHERE session_id = ?;"
        )
        defer { sqlite3_finalize(statement) }

        bind(sessionID, to: 1, in: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return (
            content: string(statement, index: 0),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1))),
            isFinal: sqlite3_column_int(statement, 2) != 0
        )
    }

    public func finalizeTranscriptsExcept(activeSessionIDs: [String]) throws {
        guard !activeSessionIDs.isEmpty else {
            try execute("UPDATE session_transcripts SET is_final = 1 WHERE is_final = 0;")
            return
        }

        let placeholders = activeSessionIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try prepare(
            "UPDATE session_transcripts SET is_final = 1 WHERE is_final = 0 AND session_id NOT IN (\(placeholders));"
        )
        defer { sqlite3_finalize(statement) }

        for (index, sessionID) in activeSessionIDs.enumerated() {
            bind(sessionID, to: Int32(index + 1), in: statement)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.stepFailed(Self.sqliteMessage(handle.raw))
        }
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

    private func attachmentsJSON(for message: ConversationMessage) -> String? {
        guard !message.attachments.isEmpty,
              let data = try? JSONEncoder().encode(message.attachments) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func attachments(from json: String?) -> [ChatAttachment] {
        guard let json,
              let data = json.data(using: .utf8),
              let attachments = try? JSONDecoder().decode([ChatAttachment].self, from: data) else {
            return []
        }
        return attachments
    }

    private static func sqliteMessage(_ handle: OpaquePointer?) -> String {
        if let handle, let cString = sqlite3_errmsg(handle) {
            return String(cString: cString)
        }
        return "Unknown SQLite error."
    }
}
