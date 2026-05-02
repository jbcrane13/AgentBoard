import Foundation

// MARK: - Kanban Status

public enum KanbanStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case triage
    case todo
    case ready
    case running
    case blocked
    case done
    case archived

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .triage: "Triage"
        case .todo: "Todo"
        case .ready: "Ready"
        case .running: "In Progress"
        case .blocked: "Blocked"
        case .done: "Done"
        case .archived: "Archived"
        }
    }

    /// Board columns (non-terminal, non-archived)
    public static var boardColumns: [KanbanStatus] {
        [.triage, .todo, .ready, .running, .blocked, .done]
    }
}

// MARK: - Workspace Kind

public enum KanbanWorkspaceKind: String, Codable, Hashable, Sendable {
    case scratch
    case dir
    case worktree
}

// MARK: - Run Outcome

public enum KanbanRunOutcome: String, Codable, Hashable, Sendable {
    case completed
    case blocked
    case crashed
    case timedOut = "timed_out"
    case spawnFailed = "spawn_failed"
    case gaveUp = "gave_up"
    case reclaimed
}

// MARK: - Kanban Task (mirrors kanban.db `tasks` table)

public struct KanbanTask: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let body: String?
    public var assignee: String?
    public var status: KanbanStatus
    public let priority: Int
    public let createdBy: String?
    public let createdAt: Date
    public let startedAt: Date?
    public var completedAt: Date?
    public let workspaceKind: KanbanWorkspaceKind
    public let workspacePath: String?
    public let tenant: String?
    public var result: String?
    public let skills: [String]?

    public init(
        id: String,
        title: String,
        body: String? = nil,
        assignee: String? = nil,
        status: KanbanStatus = .todo,
        priority: Int = 0,
        createdBy: String? = nil,
        createdAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        workspaceKind: KanbanWorkspaceKind = .scratch,
        workspacePath: String? = nil,
        tenant: String? = nil,
        result: String? = nil,
        skills: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.assignee = assignee
        self.status = status
        self.priority = priority
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.workspaceKind = workspaceKind
        self.workspacePath = workspacePath
        self.tenant = tenant
        self.result = result
        self.skills = skills
    }
}

// MARK: - Task Link (parent → child dependency)

public struct KanbanTaskLink: Codable, Hashable, Sendable {
    public let parentID: String
    public let childID: String

    public init(parentID: String, childID: String) {
        self.parentID = parentID
        self.childID = childID
    }
}

// MARK: - Task Comment

public struct KanbanComment: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let taskID: String
    public let author: String
    public let body: String
    public let createdAt: Date

    public init(id: Int, taskID: String, author: String, body: String, createdAt: Date) {
        self.id = id
        self.taskID = taskID
        self.author = author
        self.body = body
        self.createdAt = createdAt
    }
}

// MARK: - Task Run (execution attempt)

public struct KanbanRun: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let taskID: String
    public let profile: String?
    public let status: String
    public let startedAt: Date
    public let endedAt: Date?
    public let outcome: KanbanRunOutcome?
    public let summary: String?
    public let error: String?

    public init(
        id: Int,
        taskID: String,
        profile: String? = nil,
        status: String,
        startedAt: Date,
        endedAt: Date? = nil,
        outcome: KanbanRunOutcome? = nil,
        summary: String? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.profile = profile
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.outcome = outcome
        self.summary = summary
        self.error = error
    }

    public var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - Create Draft (for CLI writes)

public struct KanbanCreateDraft: Codable, Hashable, Sendable {
    public let title: String
    public let body: String?
    public let assignee: String?
    public let priority: Int
    public let tenant: String?
    public let parentIDs: [String]

    public init(
        title: String,
        body: String? = nil,
        assignee: String? = nil,
        priority: Int = 0,
        tenant: String? = nil,
        parentIDs: [String] = []
    ) {
        self.title = title
        self.body = body
        self.assignee = assignee
        self.priority = priority
        self.tenant = tenant
        self.parentIDs = parentIDs
    }
}

// MARK: - Convenience: priority mapping

public extension KanbanTask {
    /// AgentBoard uses P0-P3; kanban uses integer priority (0 = default).
    /// Map between them for display.
    var displayPriority: String {
        switch priority {
        case 0: "P0"
        case 1: "P1"
        case 2: "P2"
        default: "P3"
        }
    }

    var displayAssignee: String {
        assignee ?? "unassigned"
    }
}
