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
    /// The Hermes gateway's server-side session id for this conversation, if one has been
    /// established. Used to continue the same Hermes session (`X-Hermes-Session-Id`) and to
    /// hydrate remote history via `HermesGatewayClient.fetchSessionMessages`.
    public var hermesSessionID: String?
    /// The Hermes profile this conversation is bound to, if any. Selecting a conversation whose
    /// `profileID` names a known profile switches the active Hermes profile to match.
    public var profileID: String?

    public init(
        id: UUID = UUID(),
        title: String,
        modelID: String? = nil,
        updatedAt: Date = .now,
        hermesSessionID: String? = nil,
        profileID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.modelID = modelID
        self.updatedAt = updatedAt
        self.hermesSessionID = hermesSessionID
        self.profileID = profileID
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, modelID, updatedAt, hermesSessionID, profileID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        modelID = try container.decodeIfPresent(String.self, forKey: .modelID)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        hermesSessionID = try container.decodeIfPresent(String.self, forKey: .hermesSessionID)
        profileID = try container.decodeIfPresent(String.self, forKey: .profileID)
    }
}

public struct HermesProfile: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var gatewayURL: String
    public var modelID: String?
    /// Hex color (`#RRGGBB`) used to visually distinguish this profile in the chat header.
    public var colorHex: String?

    // Dashboard configuration (URL/username/password) is app-global — see
    // `AgentBoardSettings.dashboardURL`/`dashboardUsername` and
    // `AgentBoardSecrets.dashboardPassword` — not per-profile. A profile is a chat identity
    // (gateway + model + API key + color); the dashboard is the kanban board's own server, a
    // different Hermes service entirely.

    // MARK: - Keychain-backed secrets
    //
    // `apiKey` is never written to the UserDefaults settings snapshot — it lives in the
    // Keychain (`SettingsRepository.loadProfileSecrets`/`saveProfileSecrets`, keyed by profile
    // id) and is hydrated into this in-memory-only property by `SettingsStore.bootstrap()` /
    // `SettingsStore.selectHermesProfile(id:)`.

    /// Per-profile Hermes API key override, Keychain-backed. Selecting this profile applies it to
    /// `SettingsStore.hermesAPIKey`; profiles without one inherit the current global key.
    public var apiKey: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        gatewayURL: String,
        modelID: String? = nil,
        apiKey: String? = nil,
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.gatewayURL = gatewayURL
        self.modelID = modelID
        self.apiKey = apiKey
        self.colorHex = colorHex
    }

    /// Persisted keys only — `apiKey` is deliberately absent so the synthesized `encode(to:)`
    /// never writes it into the UserDefaults settings snapshot.
    private enum CodingKeys: String, CodingKey {
        case id, name, gatewayURL, modelID, colorHex
    }

    /// Reads a legacy inline `apiKey` from settings snapshots persisted before per-profile
    /// secrets moved to the Keychain. Decoded via a separate container so it never becomes part
    /// of the `CodingKeys` used by the synthesized (secret-excluding) `encode(to:)`.
    private enum LegacyCodingKeys: String, CodingKey {
        case apiKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        gatewayURL = try container.decode(String.self, forKey: .gatewayURL)
        modelID = try container.decodeIfPresent(String.self, forKey: .modelID)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)

        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        apiKey = try legacyContainer.decodeIfPresent(String.self, forKey: .apiKey)
    }
}

public struct ToolActivity: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let tool: String
    public var emoji: String?
    public var label: String?
    public var isComplete: Bool

    public init(id: String, tool: String, emoji: String?, label: String?, isComplete: Bool) {
        self.id = id
        self.tool = tool
        self.emoji = emoji
        self.label = label
        self.isComplete = isComplete
    }
}

public struct ConversationMessage: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let role: MessageRole
    public var content: String
    public let createdAt: Date
    public var isStreaming: Bool
    public var attachments: [ChatAttachment]
    public var toolActivities: [ToolActivity]
    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date = .now,
        isStreaming: Bool = false,
        attachments: [ChatAttachment] = [],
        toolActivities: [ToolActivity] = []
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.isStreaming = isStreaming
        self.attachments = attachments
        self.toolActivities = toolActivities
    }

    private enum CodingKeys: String, CodingKey {
        case id, conversationID, role, content, createdAt, isStreaming, attachments, toolActivities
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        conversationID = try container.decode(UUID.self, forKey: .conversationID)
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isStreaming = try container.decode(Bool.self, forKey: .isStreaming)
        attachments = try container.decodeIfPresent([ChatAttachment].self, forKey: .attachments) ?? []
        toolActivities = try container.decodeIfPresent([ToolActivity].self, forKey: .toolActivities) ?? []
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
    case ready
    case inProgress
    case blocked
    case review
    case done

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .ready: "Ready"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .review: "Review"
        case .done: "Done"
        }
    }

    public var githubState: String {
        switch self {
        case .done: "closed"
        default: "open"
        }
    }

    public var labelValue: String {
        switch self {
        case .ready: "status:ready"
        case .inProgress: "status:in-progress"
        case .blocked: "status:blocked"
        case .review: "status:review"
        case .done: "status:done"
        }
    }

    public var designColumnTitle: String {
        switch self {
        case .ready: "READY"
        case .inProgress: "IN PROGRESS"
        case .blocked: "BLOCKED"
        case .review: "REVIEW"
        case .done: "DONE"
        }
    }

    /// Whether this state represents a closed/done item on GitHub.
    public var isTerminal: Bool {
        self == .done
    }
}

public enum WorkPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    // swiftlint:disable:next identifier_name
    case p0
    // swiftlint:disable:next identifier_name
    case p1
    // swiftlint:disable:next identifier_name
    case p2
    // swiftlint:disable:next identifier_name
    case p3

    public var id: String {
        rawValue
    }

    public var title: String {
        rawValue.uppercased()
    }

    public var rank: Int {
        switch self {
        case .p0: 0
        case .p1: 1
        case .p2: 2
        case .p3: 3
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
    public var tmuxPaneID: String?
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
        tmuxPaneID: String? = nil,
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
        self.tmuxPaneID = tmuxPaneID
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

public struct SessionTranscript: Codable, Hashable, Sendable {
    public let content: String
    public let updatedAt: Date
    public let isFinal: Bool

    public init(content: String, updatedAt: Date, isFinal: Bool) {
        self.content = content
        self.updatedAt = updatedAt
        self.isFinal = isFinal
    }
}

public struct ConversationSyncPayload: Codable, Hashable, Sendable {
    public var conversations: [ChatConversation]
    public var messagesByConversation: [UUID: [ConversationMessage]]

    public init(
        conversations: [ChatConversation],
        messagesByConversation: [UUID: [ConversationMessage]]
    ) {
        self.conversations = conversations
        self.messagesByConversation = messagesByConversation
    }
}

public enum CompanionEventKind: String, Codable, CaseIterable, Sendable {
    case sessionsChanged
    case agentsChanged
    case conversationsChanged
    case snapshotRefreshed
}

public enum SessionsSyncStatus: String, Codable, CaseIterable, Sendable {
    case offline
    case loading
    case live
    case cached

    public var title: String {
        switch self {
        case .offline: "Offline"
        case .loading: "Syncing"
        case .live: "Live"
        case .cached: "Cached"
        }
    }
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
