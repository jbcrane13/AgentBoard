import Foundation

public struct ConfiguredRepository: Codable, Hashable, Identifiable, Sendable {
    public let owner: String
    public let name: String

    public var id: String {
        fullName.lowercased()
    }

    public var fullName: String {
        "\(owner)/\(name)"
    }

    public var shortName: String {
        name
    }

    public init(owner: String, name: String) {
        self.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum MessageRole: String, Codable, CaseIterable, Sendable {
    case user
    case assistant
    case system
}

public struct ChatConversation: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var modelID: String?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        modelID: String? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.modelID = modelID
        self.updatedAt = updatedAt
    }
}

public struct ConversationMessage: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let role: MessageRole
    public var content: String
    public let createdAt: Date
    public var isStreaming: Bool

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date = .now,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }
}

public enum ChatConnectionState: String, Codable, CaseIterable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed

    public var title: String {
        switch self {
        case .disconnected: "Offline"
        case .connecting: "Connecting"
        case .connected: "Live"
        case .reconnecting: "Reconnecting"
        case .failed: "Error"
        }
    }
}

public enum WorkState: String, Codable, CaseIterable, Identifiable, Sendable {
    case open
    case inProgress
    case blocked
    case done

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .done: "Done"
        }
    }

    public var githubState: String {
        self == .done ? "closed" : "open"
    }

    public var labelValue: String {
        switch self {
        case .open: "status:open"
        case .inProgress: "status:in-progress"
        case .blocked: "status:blocked"
        case .done: "status:done"
        }
    }
}

public enum WorkPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case critical = "p0"
    case high = "p1"
    case medium = "p2"
    case low = "p3"

    public var id: String {
        rawValue
    }

    public var title: String {
        rawValue.uppercased()
    }

    public var rank: Int {
        switch self {
        case .critical: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        }
    }

    public var labelValue: String {
        "priority:\(rawValue)"
    }
}

public struct WorkMilestone: Codable, Hashable, Sendable {
    public let number: Int
    public let title: String

    public init(number: Int, title: String) {
        self.number = number
        self.title = title
    }
}

public struct WorkReference: Codable, Hashable, Sendable {
    public let repository: ConfiguredRepository
    public let issueNumber: Int

    public init(repository: ConfiguredRepository, issueNumber: Int) {
        self.repository = repository
        self.issueNumber = issueNumber
    }

    public var issueReference: String {
        "\(repository.fullName)#\(issueNumber)"
    }
}

public struct WorkItem: Codable, Hashable, Identifiable, Sendable {
    public let repository: ConfiguredRepository
    public let issueNumber: Int
    public var title: String
    public var bodySummary: String
    public var isClosed: Bool
    public var assignees: [String]
    public var milestone: WorkMilestone?
    public var labels: [String]
    public var status: WorkState
    public var priority: WorkPriority
    public var agentHint: String?
    public let createdAt: Date
    public var updatedAt: Date

    public var id: String {
        issueReference
    }

    public var reference: WorkReference {
        WorkReference(repository: repository, issueNumber: issueNumber)
    }

    public var issueReference: String {
        "\(repository.fullName)#\(issueNumber)"
    }

    public init(
        repository: ConfiguredRepository,
        issueNumber: Int,
        title: String,
        bodySummary: String,
        isClosed: Bool,
        assignees: [String],
        milestone: WorkMilestone?,
        labels: [String],
        status: WorkState,
        priority: WorkPriority,
        agentHint: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.repository = repository
        self.issueNumber = issueNumber
        self.title = title
        self.bodySummary = bodySummary
        self.isClosed = isClosed
        self.assignees = assignees
        self.milestone = milestone
        self.labels = labels
        self.status = status
        self.priority = priority
        self.agentHint = agentHint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum AgentTaskState: String, Codable, CaseIterable, Identifiable, Sendable {
    case backlog
    case inProgress
    case blocked
    case done

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .backlog: "Backlog"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .done: "Done"
        }
    }
}

public struct AgentTask: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let workItem: WorkReference
    public var title: String
    public var status: AgentTaskState
    public var priority: WorkPriority
    public var assignedAgent: String
    public var sessionID: String?
    public var note: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        workItem: WorkReference,
        title: String,
        status: AgentTaskState,
        priority: WorkPriority,
        assignedAgent: String,
        sessionID: String? = nil,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workItem = workItem
        self.title = title
        self.status = status
        self.priority = priority
        self.assignedAgent = assignedAgent
        self.sessionID = sessionID
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AgentTaskDraft: Codable, Hashable, Sendable {
    public let workItem: WorkReference
    public let title: String
    public let status: AgentTaskState
    public let priority: WorkPriority
    public let assignedAgent: String
    public let sessionID: String?
    public let note: String

    public init(
        workItem: WorkReference,
        title: String,
        status: AgentTaskState = .backlog,
        priority: WorkPriority = .medium,
        assignedAgent: String,
        sessionID: String? = nil,
        note: String = ""
    ) {
        self.workItem = workItem
        self.title = title
        self.status = status
        self.priority = priority
        self.assignedAgent = assignedAgent
        self.sessionID = sessionID
        self.note = note
    }
}

public struct AgentTaskPatch: Codable, Hashable, Sendable {
    public var title: String?
    public var status: AgentTaskState?
    public var priority: WorkPriority?
    public var assignedAgent: String?
    public var sessionID: String?
    public var note: String?

    public init(
        title: String? = nil,
        status: AgentTaskState? = nil,
        priority: WorkPriority? = nil,
        assignedAgent: String? = nil,
        sessionID: String? = nil,
        note: String? = nil
    ) {
        self.title = title
        self.status = status
        self.priority = priority
        self.assignedAgent = assignedAgent
        self.sessionID = sessionID
        self.note = note
    }
}

public enum AgentSessionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case running
    case idle
    case stopped
    case error

    public var id: String {
        rawValue
    }

    public var title: String {
        rawValue.capitalized
    }
}

public struct AgentSession: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var source: String
    public var status: AgentSessionStatus
    public var linkedTaskID: String?
    public var workItem: WorkReference?
    public var model: String?
    public var startedAt: Date
    public var lastSeenAt: Date
    public var pid: Int?
    public var tmuxSession: String?
    public var lastOutput: String?

    public init(
        id: String,
        source: String,
        status: AgentSessionStatus,
        linkedTaskID: String? = nil,
        workItem: WorkReference? = nil,
        model: String? = nil,
        startedAt: Date = .now,
        lastSeenAt: Date = .now,
        pid: Int? = nil,
        tmuxSession: String? = nil,
        lastOutput: String? = nil
    ) {
        self.id = id
        self.source = source
        self.status = status
        self.linkedTaskID = linkedTaskID
        self.workItem = workItem
        self.model = model
        self.startedAt = startedAt
        self.lastSeenAt = lastSeenAt
        self.pid = pid
        self.tmuxSession = tmuxSession
        self.lastOutput = lastOutput
    }
}

public enum AgentHealthStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case online
    case idle
    case warning
    case offline

    public var id: String {
        rawValue
    }

    public var title: String {
        rawValue.capitalized
    }
}

public struct AgentSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var health: AgentHealthStatus
    public var activeTaskCount: Int
    public var activeSessionCount: Int
    public var recentActivity: String
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        health: AgentHealthStatus,
        activeTaskCount: Int,
        activeSessionCount: Int,
        recentActivity: String,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.health = health
        self.activeTaskCount = activeTaskCount
        self.activeSessionCount = activeSessionCount
        self.recentActivity = recentActivity
        self.updatedAt = updatedAt
    }
}

public enum CompanionEventKind: String, Codable, CaseIterable, Sendable {
    case tasksChanged
    case sessionsChanged
    case agentsChanged
    case snapshotRefreshed
}

public struct CompanionEvent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let kind: CompanionEventKind
    public let sentAt: Date

    public init(
        id: UUID = UUID(),
        kind: CompanionEventKind,
        sentAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.sentAt = sentAt
    }
}

public struct AgentBoardSettings: Codable, Hashable, Sendable {
    public var hermesGatewayURL: String
    public var hermesModelID: String?
    public var companionURL: String
    public var repositories: [ConfiguredRepository]
    public var autoRefreshInterval: TimeInterval

    public init(
        hermesGatewayURL: String = "http://127.0.0.1:8642",
        hermesModelID: String? = "hermes-agent",
        companionURL: String = "http://127.0.0.1:8742",
        repositories: [ConfiguredRepository] = [],
        autoRefreshInterval: TimeInterval = 30
    ) {
        self.hermesGatewayURL = hermesGatewayURL
        self.hermesModelID = hermesModelID
        self.companionURL = companionURL
        self.repositories = repositories
        self.autoRefreshInterval = autoRefreshInterval
    }
}

public struct AgentBoardSecrets: Equatable, Sendable {
    public var hermesAPIKey: String?
    public var githubToken: String?
    public var companionToken: String?

    public init(
        hermesAPIKey: String? = nil,
        githubToken: String? = nil,
        companionToken: String? = nil
    ) {
        self.hermesAPIKey = hermesAPIKey
        self.githubToken = githubToken
        self.companionToken = companionToken
    }
}

public enum AppDestination: String, CaseIterable, Identifiable, Sendable {
    case chat
    case work
    case agents
    case sessions
    case settings

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .chat: "Chat"
        case .work: "Work"
        case .agents: "Agents"
        case .sessions: "Sessions"
        case .settings: "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .work: "square.grid.2x2"
        case .agents: "person.3.sequence"
        case .sessions: "bolt.horizontal.circle"
        case .settings: "slider.horizontal.3"
        }
    }
}
