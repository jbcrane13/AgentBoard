import Foundation

// The PRD names priorities P0 through P3, so these case names intentionally match it.
// swiftlint:disable identifier_name
public enum LifePriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case p0
    case p1
    case p2
    case p3

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .p0: "P0"
        case .p1: "P1"
        case .p2: "P2"
        case .p3: "P3"
        }
    }

    public var sortRank: Int {
        switch self {
        case .p0: 0
        case .p1: 1
        case .p2: 2
        case .p3: 3
        }
    }

    public static var displayOrder: [LifePriority] {
        [.p0, .p1, .p2, .p3]
    }
}
// swiftlint:enable identifier_name

public enum LifeTaskCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case email
    case calendar
    case messages
    case jobSearch
    case family
    case admin
    case personal
    case finance
    case health
    case project
    case waitingOn
    case approval

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .email: "Email"
        case .calendar: "Calendar"
        case .messages: "Messages"
        case .jobSearch: "Job Search"
        case .family: "Family"
        case .admin: "Admin"
        case .personal: "Personal"
        case .finance: "Finance"
        case .health: "Health"
        case .project: "Project"
        case .waitingOn: "Waiting On"
        case .approval: "Approval"
        }
    }
}

public enum LifeTaskStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case inbox
    case needsBlake
    case assignedToDaneel
    case waitingOnExternal
    case scheduled
    case snoozed
    case done
    case blocked
    case cancelled

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .inbox: "Inbox"
        case .needsBlake: "Needs Blake"
        case .assignedToDaneel: "Assigned to Daneel"
        case .waitingOnExternal: "Waiting On"
        case .scheduled: "Scheduled"
        case .snoozed: "Snoozed"
        case .done: "Done"
        case .blocked: "Blocked"
        case .cancelled: "Cancelled"
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .done, .cancelled: true
        case .inbox, .needsBlake, .assignedToDaneel, .waitingOnExternal, .scheduled, .snoozed, .blocked: false
        }
    }
}

public enum LifeActor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blake
    case sarah
    case family
    case daneel
    case external

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .blake: "Blake"
        case .sarah: "Sarah"
        case .family: "Family"
        case .daneel: "Daneel"
        case .external: "External"
        }
    }
}

public enum LifeSourceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case email
    case calendar
    case message
    case manual
    case chat
    case jobSearch
    case family

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .email: "Email"
        case .calendar: "Calendar"
        case .message: "Message"
        case .manual: "Manual"
        case .chat: "Chat"
        case .jobSearch: "Job Search"
        case .family: "Family"
        }
    }
}

public enum ApprovalActionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case sendEmail
    case sendMessage
    case createCalendarEvent
    case applyToJob
    case archiveEmail
    case delegateTask
    case other

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .sendEmail: "Send Email"
        case .sendMessage: "Send Message"
        case .createCalendarEvent: "Create Calendar Event"
        case .applyToJob: "Apply to Job"
        case .archiveEmail: "Archive Email"
        case .delegateTask: "Delegate Task"
        case .other: "Other"
        }
    }
}

public enum ApprovalRiskLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

public enum ApprovalStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case approved
    case rejected
    case completed
    case failed

    public var id: String {
        rawValue
    }
}

public enum JobOpportunityStage: String, Codable, CaseIterable, Identifiable, Sendable {
    case target
    case saved
    case applied
    case recruiterContact
    case screenScheduled
    case interviewing
    case followUpDue
    case offer
    case rejected
    case closed

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .target: "Target"
        case .saved: "Saved"
        case .applied: "Applied"
        case .recruiterContact: "Recruiter Contact"
        case .screenScheduled: "Screen Scheduled"
        case .interviewing: "Interviewing"
        case .followUpDue: "Follow Up Due"
        case .offer: "Offer"
        case .rejected: "Rejected"
        case .closed: "Closed"
        }
    }
}

public enum FamilyRequestAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case createTask
    case createCalendarEvent
    case askQuestion
    case needsClarification

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .createTask: "Create Task"
        case .createCalendarEvent: "Create Calendar Event"
        case .askQuestion: "Ask Question"
        case .needsClarification: "Needs Clarification"
        }
    }
}

public enum FamilyRequestStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case received
    case convertedToTask
    case awaitingApproval
    case completed
    case blocked
    case dismissed

    public var id: String {
        rawValue
    }
}

public struct LifeTaskSource: Codable, Hashable, Sendable {
    public var sourceType: LifeSourceType
    public var sourceID: String?
    public var sourceURL: URL?
    public var displayName: String
    public var originActor: LifeActor?

    public init(
        sourceType: LifeSourceType,
        sourceID: String? = nil,
        sourceURL: URL? = nil,
        displayName: String,
        originActor: LifeActor? = nil
    ) {
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.sourceURL = sourceURL
        self.displayName = displayName
        self.originActor = originActor
    }
}

public struct LifeTask: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var summary: String
    public var category: LifeTaskCategory
    public var status: LifeTaskStatus
    public var priority: LifePriority
    public var urgencyScore: Int
    public var importanceScore: Int
    public var dueAt: Date?
    public var snoozedUntil: Date?
    public var estimatedMinutes: Int?
    public var nextAction: String
    public var owner: LifeActor
    public var assignee: LifeActor
    public var source: LifeTaskSource?
    public var confidence: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String = "",
        category: LifeTaskCategory,
        status: LifeTaskStatus = .inbox,
        priority: LifePriority = .p2,
        urgencyScore: Int = 50,
        importanceScore: Int = 50,
        dueAt: Date? = nil,
        snoozedUntil: Date? = nil,
        estimatedMinutes: Int? = nil,
        nextAction: String,
        owner: LifeActor = .blake,
        assignee: LifeActor = .blake,
        source: LifeTaskSource? = nil,
        confidence: Double = 1.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.status = status
        self.priority = priority
        self.urgencyScore = urgencyScore
        self.importanceScore = importanceScore
        self.dueAt = dueAt
        self.snoozedUntil = snoozedUntil
        self.estimatedMinutes = estimatedMinutes
        self.nextAction = nextAction
        self.owner = owner
        self.assignee = assignee
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isSarahOriginated: Bool {
        owner == .sarah || source?.originActor == .sarah
    }
}

public struct ApprovalAction: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var taskID: UUID?
    public var title: String
    public var summary: String
    public var actionType: ApprovalActionType
    public var proposedPayloadPreview: String
    public var riskLevel: ApprovalRiskLevel
    public var status: ApprovalStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        title: String,
        summary: String,
        actionType: ApprovalActionType,
        proposedPayloadPreview: String,
        riskLevel: ApprovalRiskLevel,
        status: ApprovalStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.summary = summary
        self.actionType = actionType
        self.proposedPayloadPreview = proposedPayloadPreview
        self.riskLevel = riskLevel
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct JobOpportunity: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var company: String
    public var role: String
    public var url: URL?
    public var contactName: String?
    public var contactChannel: String?
    public var stage: JobOpportunityStage
    public var lastTouchAt: Date?
    public var nextFollowUpAt: Date?
    public var notes: String
    public var associatedTaskIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        company: String,
        role: String,
        url: URL? = nil,
        contactName: String? = nil,
        contactChannel: String? = nil,
        stage: JobOpportunityStage,
        lastTouchAt: Date? = nil,
        nextFollowUpAt: Date? = nil,
        notes: String = "",
        associatedTaskIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.company = company
        self.role = role
        self.url = url
        self.contactName = contactName
        self.contactChannel = contactChannel
        self.stage = stage
        self.lastTouchAt = lastTouchAt
        self.nextFollowUpAt = nextFollowUpAt
        self.notes = notes
        self.associatedTaskIDs = associatedTaskIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct FamilyRequest: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var requester: LifeActor
    public var source: LifeTaskSource
    public var rawText: String
    public var interpretedAction: FamilyRequestAction
    public var linkedTaskID: UUID?
    public var linkedApprovalID: UUID?
    public var status: FamilyRequestStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        requester: LifeActor,
        source: LifeTaskSource,
        rawText: String,
        interpretedAction: FamilyRequestAction,
        linkedTaskID: UUID? = nil,
        linkedApprovalID: UUID? = nil,
        status: FamilyRequestStatus,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.requester = requester
        self.source = source
        self.rawText = rawText
        self.interpretedAction = interpretedAction
        self.linkedTaskID = linkedTaskID
        self.linkedApprovalID = linkedApprovalID
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
