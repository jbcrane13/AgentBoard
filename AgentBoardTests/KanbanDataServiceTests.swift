import AgentBoardCore
import Foundation
import SQLite3
import Testing

/// Exercises `KanbanDataService` against a real on-disk SQLite database whose
/// schema mirrors the subset of `~/.hermes/kanban.db` the app reads. Guards the
/// column ordering in the `SELECT` lists — an off-by-one there silently shifts
/// every mapped field and no fake-backed test would notice.
@Suite("KanbanDataService")
struct KanbanDataServiceTests {
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Epoch seconds, matching the INTEGER date convention in kanban.db.
    private static let createdAt = 1_700_000_000
    private static let heartbeatAt = 1_700_000_500

    private static func makeDatabase() throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("kanban-\(UUID().uuidString).db")
            .path

        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }

        let schema = """
        CREATE TABLE tasks (
            id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT, assignee TEXT,
            status TEXT NOT NULL, priority INTEGER DEFAULT 0, created_by TEXT,
            created_at INTEGER NOT NULL, started_at INTEGER, completed_at INTEGER,
            workspace_kind TEXT NOT NULL DEFAULT 'scratch', workspace_path TEXT,
            tenant TEXT, result TEXT, skills TEXT,
            last_heartbeat_at INTEGER,
            consecutive_failures INTEGER NOT NULL DEFAULT 0,
            last_failure_error TEXT, branch_name TEXT, model_override TEXT,
            session_id TEXT, goal_mode INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE task_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT, task_id TEXT NOT NULL,
            run_id INTEGER, kind TEXT NOT NULL, payload TEXT,
            created_at INTEGER NOT NULL
        );
        INSERT INTO tasks (
            id, title, status, priority, created_at, workspace_kind,
            last_heartbeat_at, consecutive_failures, last_failure_error,
            branch_name, model_override, session_id, goal_mode
        ) VALUES (
            't_rich', 'Rich task', 'running', 2, \(createdAt), 'worktree',
            \(heartbeatAt), 3, 'spawn timed out',
            'agentboard/t_rich', 'sonnet', 'sess_42', 1
        );
        INSERT INTO tasks (id, title, status, created_at, workspace_kind)
        VALUES ('t_bare', 'Bare task', 'ready', \(createdAt - 10), 'scratch');
        INSERT INTO task_events (task_id, kind, payload, created_at)
        VALUES ('t_rich', 'created', NULL, \(createdAt));
        INSERT INTO task_events (task_id, kind, payload, created_at)
        VALUES ('t_rich', 'claimed', '{"by":"argus"}', \(createdAt + 60));
        INSERT INTO task_events (task_id, kind, payload, created_at)
        VALUES ('t_bare', 'created', NULL, \(createdAt + 120));
        """
        #expect(sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK)
        return path
    }

    // MARK: - Rich task columns

    @Test func fetchTasksMapsRichColumnsFromTheirSelectPositions() async throws {
        let service = try KanbanDataService(databasePath: Self.makeDatabase())
        let tasks = try await service.fetchTasks()

        let rich = try #require(tasks.first { $0.id == "t_rich" })
        #expect(rich.title == "Rich task")
        #expect(rich.status == .running)
        #expect(rich.priority == 2)
        #expect(rich.workspaceKind == .worktree)
        #expect(rich.lastHeartbeatAt == Date(timeIntervalSince1970: TimeInterval(Self.heartbeatAt)))
        #expect(rich.consecutiveFailures == 3)
        #expect(rich.lastFailureError == "spawn timed out")
        #expect(rich.branchName == "agentboard/t_rich")
        #expect(rich.modelOverride == "sonnet")
        #expect(rich.sessionID == "sess_42")
        #expect(rich.goalMode)
    }

    @Test func fetchTasksLeavesRichColumnsAtDefaultsWhenNull() async throws {
        let service = try KanbanDataService(databasePath: Self.makeDatabase())
        let tasks = try await service.fetchTasks()

        let bare = try #require(tasks.first { $0.id == "t_bare" })
        #expect(bare.lastHeartbeatAt == nil)
        #expect(bare.consecutiveFailures == 0)
        #expect(bare.lastFailureError == nil)
        #expect(bare.branchName == nil)
        #expect(bare.modelOverride == nil)
        #expect(bare.sessionID == nil)
        #expect(!bare.goalMode)
    }

    @Test func fetchTaskByIDMapsTheSameColumnsAsFetchTasks() async throws {
        let service = try KanbanDataService(databasePath: Self.makeDatabase())

        let task = try #require(try await service.fetchTask(id: "t_rich"))
        #expect(task.branchName == "agentboard/t_rich")
        #expect(task.sessionID == "sess_42")
        #expect(task.modelOverride == "sonnet")
        #expect(task.consecutiveFailures == 3)
        #expect(task.goalMode)
    }

    // MARK: - Events

    @Test func fetchLatestEventIDReturnsHighestRowID() async throws {
        let service = try KanbanDataService(databasePath: Self.makeDatabase())
        #expect(try await service.fetchLatestEventID() == 3)
    }

    @Test func fetchLatestEventIDIsZeroForAnEmptyEventLog() async throws {
        let path = try Self.makeDatabase()
        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        #expect(sqlite3_exec(db, "DELETE FROM task_events", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let service = KanbanDataService(databasePath: path)
        #expect(try await service.fetchLatestEventID() == 0)
    }

    @Test func fetchEventsReturnsNewestFirstForTheRequestedTaskOnly() async throws {
        let service = try KanbanDataService(databasePath: Self.makeDatabase())
        let events = try await service.fetchEvents(taskID: "t_rich")

        #expect(events.count == 2)
        #expect(events.map(\.kind) == ["claimed", "created"])
        #expect(events[0].payload == #"{"by":"argus"}"#)
        #expect(events[1].payload == nil)
        #expect(events[1].createdAt == Date(timeIntervalSince1970: TimeInterval(Self.createdAt)))
    }

    @Test func fetchEventsHonoursTheLimit() async throws {
        let service = try KanbanDataService(databasePath: Self.makeDatabase())
        let events = try await service.fetchEvents(taskID: "t_rich", limit: 1)

        #expect(events.count == 1)
        #expect(events[0].kind == "claimed")
    }
}
