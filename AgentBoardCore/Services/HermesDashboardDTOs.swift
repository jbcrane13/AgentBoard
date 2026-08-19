import Foundation

/// Wire DTOs for the Hermes dashboard's bundled kanban plugin API
/// (`/api/plugins/kanban/*`) and the mapping onto AgentBoard's existing
/// `KanbanTask`/`KanbanComment`/`KanbanRun`/`KanbanEvent` models.
///
/// Every field is optional so a key the dashboard adds, removes, or renames
/// in a future Hermes version degrades gracefully (a missing task field maps
/// to that task's default; a whole malformed record is dropped by the
/// `compactMap` in the `to...()` conversions below) instead of failing the
/// entire decode. Extra keys present in the JSON but absent from these
/// structs are ignored automatically by `JSONDecoder`.

/// Epoch-seconds -> `Date`, matching the INTEGER date convention
/// `KanbanDataService` already uses for the same columns read from SQLite.
enum HermesDashboardDates {
    static func date(fromEpochSeconds seconds: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}

/// Decodes a 0/1 flag regardless of whether the dashboard serialises it as a
/// JSON bool, number, or string. The underlying SQLite column is INTEGER, but
/// the plugin API returns `goal_mode` as a bool — verified live against
/// `GET /api/plugins/kanban/board`. Optionality alone does not cover this:
/// a *type* mismatch throws and would fail the entire board decode.
struct LenientBool: Decodable, Sendable {
    let value: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int != 0
        } else if let string = try? container.decode(String.self) {
            value = ["1", "true", "yes"].contains(string.lowercased())
        } else {
            value = false
        }
    }
}

/// Wraps one element of a heterogeneous array so a single undecodable record
/// is dropped rather than failing its whole container. Without this, one task
/// the app cannot parse blanks the entire board.
struct Failable<Wrapped: Decodable & Sendable>: Decodable, Sendable {
    let wrapped: Wrapped?

    init(from decoder: Decoder) throws {
        wrapped = try? Wrapped(from: decoder)
    }
}

/// Yields a `String` from a JSON value that may be a string *or* structured
/// JSON. `task_events.payload` is TEXT in SQLite, but the dashboard decodes it
/// before serialising, so the API returns an object — verified live. Structured
/// values are re-encoded compactly so the model's `String?` still carries them.
struct LenientJSONString: Decodable, Sendable {
    let value: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let json = try? container.decode(JSONValue.self) {
            value = json.compactJSONString
        } else {
            value = nil
        }
    }
}

/// Minimal recursive JSON value, used only to re-serialise structured payloads.
indirect enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    var compactJSONString: String {
        switch self {
        case let .string(value):
            return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        case let .number(value):
            return value == value.rounded() && abs(value) < 1e15
                ? String(Int(value))
                : String(value)
        case let .bool(value):
            return value ? "true" : "false"
        case .null:
            return "null"
        case let .array(values):
            return "[" + values.map(\.compactJSONString).joined(separator: ",") + "]"
        case let .object(values):
            let pairs = values.sorted { $0.key < $1.key }
                .map { "\"\($0.key)\":\($0.value.compactJSONString)" }
            return "{" + pairs.joined(separator: ",") + "}"
        }
    }
}

// MARK: - GET /api/plugins/kanban/board

struct DashboardBoardResponse: Decodable {
    let columns: [DashboardColumn]?
    let latestEventID: Int?

    enum CodingKeys: String, CodingKey {
        case columns
        case latestEventID = "latest_event_id"
    }
}

struct DashboardColumn: Decodable {
    let name: String?
    private let rawTasks: [Failable<DashboardTask>]?

    var tasks: [DashboardTask]? {
        rawTasks?.compactMap(\.wrapped)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case rawTasks = "tasks"
    }
}

struct DashboardTask: Decodable {
    let id: String?
    let title: String?
    let body: String?
    let assignee: String?
    let status: String?
    let priority: Int?
    let createdBy: String?
    let createdAt: Int?
    let startedAt: Int?
    let completedAt: Int?
    let workspaceKind: String?
    let workspacePath: String?
    let tenant: String?
    let result: String?
    let skills: [String]?
    let lastHeartbeatAt: Int?
    let consecutiveFailures: Int?
    let lastFailureError: String?
    let branchName: String?
    let sessionID: String?
    /// SQLite stores this as an INTEGER `0`/`1`, but the dashboard API returns
    /// a JSON bool — verified live. `LenientBool` accepts either.
    let goalMode: LenientBool?
    let modelOverride: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body, assignee, status, priority
        case createdBy = "created_by"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case workspaceKind = "workspace_kind"
        case workspacePath = "workspace_path"
        case tenant, result, skills
        case lastHeartbeatAt = "last_heartbeat_at"
        case consecutiveFailures = "consecutive_failures"
        case lastFailureError = "last_failure_error"
        case branchName = "branch_name"
        case sessionID = "session_id"
        case goalMode = "goal_mode"
        case modelOverride = "model_override"
    }

    /// Mirrors `KanbanDataService.taskFromRow`'s fallbacks exactly (unmapped
    /// status -> `.todo`, unmapped workspace kind -> `.scratch`) so a remote
    /// and a local read behave identically. Returns `nil` — dropping the
    /// record rather than failing the whole board fetch — when the two
    /// fields every task must have (`id`, `title`) are missing.
    func toKanbanTask() -> KanbanTask? {
        guard let id, let title else { return nil }
        return KanbanTask(
            id: id,
            title: title,
            body: body,
            assignee: assignee,
            status: status.flatMap(KanbanStatus.init(rawValue:)) ?? .todo,
            priority: priority ?? 0,
            createdBy: createdBy,
            createdAt: createdAt.map(HermesDashboardDates.date(fromEpochSeconds:)) ?? .now,
            startedAt: startedAt.map(HermesDashboardDates.date(fromEpochSeconds:)),
            completedAt: completedAt.map(HermesDashboardDates.date(fromEpochSeconds:)),
            workspaceKind: workspaceKind.flatMap(KanbanWorkspaceKind.init(rawValue:)) ?? .scratch,
            workspacePath: workspacePath,
            tenant: tenant,
            result: result,
            skills: skills,
            lastHeartbeatAt: lastHeartbeatAt.map(HermesDashboardDates.date(fromEpochSeconds:)),
            consecutiveFailures: consecutiveFailures ?? 0,
            lastFailureError: lastFailureError,
            branchName: branchName,
            sessionID: sessionID,
            goalMode: goalMode?.value ?? false,
            modelOverride: modelOverride
        )
    }
}

// MARK: - GET /api/plugins/kanban/tasks/{task_id}

struct DashboardTaskDetailResponse: Decodable {
    let comments: [DashboardComment]?
    let runs: [DashboardRun]?
    let links: DashboardLinks?
    let events: [DashboardEvent]?
}

struct DashboardComment: Decodable {
    let id: Int?
    let taskID: String?
    let author: String?
    let body: String?
    let createdAt: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case taskID = "task_id"
        case author, body
        case createdAt = "created_at"
    }

    func toKanbanComment() -> KanbanComment? {
        guard let id, let taskID, let author, let body, let createdAt else { return nil }
        return KanbanComment(
            id: id,
            taskID: taskID,
            author: author,
            body: body,
            createdAt: HermesDashboardDates.date(fromEpochSeconds: createdAt)
        )
    }
}

struct DashboardRun: Decodable {
    let id: Int?
    let taskID: String?
    let profile: String?
    let status: String?
    let startedAt: Int?
    let endedAt: Int?
    let outcome: String?
    let summary: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case taskID = "task_id"
        case profile, status
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case outcome, summary, error
    }

    func toKanbanRun() -> KanbanRun? {
        guard let id, let taskID, let status, let startedAt else { return nil }
        return KanbanRun(
            id: id,
            taskID: taskID,
            profile: profile,
            status: status,
            startedAt: HermesDashboardDates.date(fromEpochSeconds: startedAt),
            endedAt: endedAt.map(HermesDashboardDates.date(fromEpochSeconds:)),
            outcome: outcome.flatMap(KanbanRunOutcome.init(rawValue:)),
            summary: summary,
            error: error
        )
    }
}

struct DashboardEvent: Decodable {
    let id: Int?
    let kind: String?
    let payload: LenientJSONString?
    let createdAt: Int?

    enum CodingKeys: String, CodingKey {
        case id, kind, payload
        case createdAt = "created_at"
    }

    func toKanbanEvent() -> KanbanEvent? {
        guard let id, let kind, let createdAt else { return nil }
        return KanbanEvent(
            id: id,
            kind: kind,
            payload: payload?.value,
            createdAt: HermesDashboardDates.date(fromEpochSeconds: createdAt)
        )
    }
}

/// Verified live: the task-detail `links` object uses `parents`/`children`,
/// each an array of task-id strings. The `parent_ids`/`child_ids` spelling is
/// kept as a tolerated alternative, falling back to empty arrays rather than
/// failing the fetch, since this is an unversioned plugin API.
struct DashboardLinks: Decodable {
    let parents: [String]?
    let children: [String]?
    let parentIDs: [String]?
    let childIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case parents, children
        case parentIDs = "parent_ids"
        case childIDs = "child_ids"
    }

    var resolved: (parents: [String], children: [String]) {
        (parents ?? parentIDs ?? [], children ?? childIDs ?? [])
    }
}
