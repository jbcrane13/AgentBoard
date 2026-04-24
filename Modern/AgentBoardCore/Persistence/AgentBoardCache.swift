import Foundation
import SwiftData

@Model
private final class CachedConversationRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var modelID: String?
    var updatedAt: Date

    init(id: UUID, title: String, modelID: String?, updatedAt: Date) {
        self.id = id
        self.title = title
        self.modelID = modelID
        self.updatedAt = updatedAt
    }
}

@Model
private final class CachedMessageRecord {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID
    var role: String
    var content: String
    var createdAt: Date
    var isStreaming: Bool

    init(
        id: UUID,
        conversationID: UUID,
        role: String,
        content: String,
        createdAt: Date,
        isStreaming: Bool
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }
}

@Model
private final class CachedWorkItemRecord {
    @Attribute(.unique) var id: String
    var repositoryOwner: String
    var repositoryName: String
    var issueNumber: Int
    var title: String
    var bodySummary: String
    var isClosed: Bool
    var assigneesData: Data
    var milestoneNumber: Int?
    var milestoneTitle: String?
    var labelsData: Data
    var status: String
    var priority: String
    var agentHint: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        repositoryOwner: String,
        repositoryName: String,
        issueNumber: Int,
        title: String,
        bodySummary: String,
        isClosed: Bool,
        assigneesData: Data,
        milestoneNumber: Int?,
        milestoneTitle: String?,
        labelsData: Data,
        status: String,
        priority: String,
        agentHint: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.repositoryOwner = repositoryOwner
        self.repositoryName = repositoryName
        self.issueNumber = issueNumber
        self.title = title
        self.bodySummary = bodySummary
        self.isClosed = isClosed
        self.assigneesData = assigneesData
        self.milestoneNumber = milestoneNumber
        self.milestoneTitle = milestoneTitle
        self.labelsData = labelsData
        self.status = status
        self.priority = priority
        self.agentHint = agentHint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
private final class CachedTaskRecord {
    @Attribute(.unique) var id: String
    var repositoryOwner: String
    var repositoryName: String
    var issueNumber: Int
    var title: String
    var status: String
    var priority: String
    var assignedAgent: String
    var sessionID: String?
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        repositoryOwner: String,
        repositoryName: String,
        issueNumber: Int,
        title: String,
        status: String,
        priority: String,
        assignedAgent: String,
        sessionID: String?,
        note: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.repositoryOwner = repositoryOwner
        self.repositoryName = repositoryName
        self.issueNumber = issueNumber
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

@Model
private final class CachedSessionRecord {
    @Attribute(.unique) var id: String
    var source: String
    var status: String
    var linkedTaskID: String?
    var repositoryOwner: String?
    var repositoryName: String?
    var issueNumber: Int?
    var model: String?
    var startedAt: Date
    var lastSeenAt: Date

    init(
        id: String,
        source: String,
        status: String,
        linkedTaskID: String?,
        repositoryOwner: String?,
        repositoryName: String?,
        issueNumber: Int?,
        model: String?,
        startedAt: Date,
        lastSeenAt: Date
    ) {
        self.id = id
        self.source = source
        self.status = status
        self.linkedTaskID = linkedTaskID
        self.repositoryOwner = repositoryOwner
        self.repositoryName = repositoryName
        self.issueNumber = issueNumber
        self.model = model
        self.startedAt = startedAt
        self.lastSeenAt = lastSeenAt
    }
}

@Model
private final class CachedAgentRecord {
    @Attribute(.unique) var id: String
    var name: String
    var health: String
    var activeTaskCount: Int
    var activeSessionCount: Int
    var recentActivity: String
    var updatedAt: Date

    init(
        id: String,
        name: String,
        health: String,
        activeTaskCount: Int,
        activeSessionCount: Int,
        recentActivity: String,
        updatedAt: Date
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

@MainActor
public final class AgentBoardCache {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public let modelContainer: ModelContainer

    private var context: ModelContext {
        modelContainer.mainContext
    }

    public init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        modelContainer = try ModelContainer(
            for: CachedConversationRecord.self,
            CachedMessageRecord.self,
            CachedWorkItemRecord.self,
            CachedTaskRecord.self,
            CachedSessionRecord.self,
            CachedAgentRecord.self,
            configurations: configuration
        )
    }

    public func loadConversations() throws -> [ChatConversation] {
        let descriptor = FetchDescriptor<CachedConversationRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map {
            ChatConversation(
                id: $0.id,
                title: $0.title,
                modelID: $0.modelID,
                updatedAt: $0.updatedAt
            )
        }
    }

    public func loadMessages(conversationID: UUID) throws -> [ConversationMessage] {
        let descriptor = FetchDescriptor<CachedMessageRecord>(
            predicate: #Predicate { $0.conversationID == conversationID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).compactMap {
            guard let role = MessageRole(rawValue: $0.role) else { return nil }
            return ConversationMessage(
                id: $0.id,
                conversationID: $0.conversationID,
                role: role,
                content: $0.content,
                createdAt: $0.createdAt,
                isStreaming: $0.isStreaming
            )
        }
    }

    public func saveConversationSnapshot(
        conversation: ChatConversation,
        messages: [ConversationMessage]
    ) throws {
        let existingConversations = try context.fetch(
            FetchDescriptor<CachedConversationRecord>(
                predicate: #Predicate { $0.id == conversation.id }
            )
        )
        if let record = existingConversations.first {
            record.title = conversation.title
            record.modelID = conversation.modelID
            record.updatedAt = conversation.updatedAt
        } else {
            context.insert(
                CachedConversationRecord(
                    id: conversation.id,
                    title: conversation.title,
                    modelID: conversation.modelID,
                    updatedAt: conversation.updatedAt
                )
            )
        }

        let existingMessages = try context.fetch(
            FetchDescriptor<CachedMessageRecord>(
                predicate: #Predicate { $0.conversationID == conversation.id }
            )
        )
        existingMessages.forEach(context.delete)

        for message in messages {
            context.insert(
                CachedMessageRecord(
                    id: message.id,
                    conversationID: message.conversationID,
                    role: message.role.rawValue,
                    content: message.content,
                    createdAt: message.createdAt,
                    isStreaming: message.isStreaming
                )
            )
        }

        try context.save()
    }

    public func loadWorkItems() throws -> [WorkItem] {
        let descriptor = FetchDescriptor<CachedWorkItemRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { record in
            WorkItem(
                repository: ConfiguredRepository(owner: record.repositoryOwner, name: record.repositoryName),
                issueNumber: record.issueNumber,
                title: record.title,
                bodySummary: record.bodySummary,
                isClosed: record.isClosed,
                assignees: decodeStrings(record.assigneesData),
                milestone: {
                    guard let number = record.milestoneNumber,
                          let title = record.milestoneTitle else {
                        return nil
                    }
                    return WorkMilestone(number: number, title: title)
                }(),
                labels: decodeStrings(record.labelsData),
                status: WorkState(rawValue: record.status) ?? .open,
                priority: WorkPriority(rawValue: record.priority) ?? .medium,
                agentHint: record.agentHint,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
    }

    public func replaceWorkItems(_ items: [WorkItem]) throws {
        try replaceAll(CachedWorkItemRecord.self)
        for item in items {
            context.insert(
                CachedWorkItemRecord(
                    id: item.id,
                    repositoryOwner: item.repository.owner,
                    repositoryName: item.repository.name,
                    issueNumber: item.issueNumber,
                    title: item.title,
                    bodySummary: item.bodySummary,
                    isClosed: item.isClosed,
                    assigneesData: encodeStrings(item.assignees),
                    milestoneNumber: item.milestone?.number,
                    milestoneTitle: item.milestone?.title,
                    labelsData: encodeStrings(item.labels),
                    status: item.status.rawValue,
                    priority: item.priority.rawValue,
                    agentHint: item.agentHint,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            )
        }
        try context.save()
    }

    public func loadTasks() throws -> [AgentTask] {
        let descriptor = FetchDescriptor<CachedTaskRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { record in
            AgentTask(
                id: record.id,
                workItem: WorkReference(
                    repository: ConfiguredRepository(owner: record.repositoryOwner, name: record.repositoryName),
                    issueNumber: record.issueNumber
                ),
                title: record.title,
                status: AgentTaskState(rawValue: record.status) ?? .backlog,
                priority: WorkPriority(rawValue: record.priority) ?? .medium,
                assignedAgent: record.assignedAgent,
                sessionID: record.sessionID,
                note: record.note,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
    }

    public func replaceTasks(_ tasks: [AgentTask]) throws {
        try replaceAll(CachedTaskRecord.self)
        for task in tasks {
            context.insert(
                CachedTaskRecord(
                    id: task.id,
                    repositoryOwner: task.workItem.repository.owner,
                    repositoryName: task.workItem.repository.name,
                    issueNumber: task.workItem.issueNumber,
                    title: task.title,
                    status: task.status.rawValue,
                    priority: task.priority.rawValue,
                    assignedAgent: task.assignedAgent,
                    sessionID: task.sessionID,
                    note: task.note,
                    createdAt: task.createdAt,
                    updatedAt: task.updatedAt
                )
            )
        }
        try context.save()
    }

    public func loadSessions() throws -> [AgentSession] {
        let descriptor = FetchDescriptor<CachedSessionRecord>(
            sortBy: [SortDescriptor(\.lastSeenAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { record in
            AgentSession(
                id: record.id,
                source: record.source,
                status: AgentSessionStatus(rawValue: record.status) ?? .idle,
                linkedTaskID: record.linkedTaskID,
                workItem: {
                    guard let owner = record.repositoryOwner,
                          let name = record.repositoryName,
                          let issueNumber = record.issueNumber else {
                        return nil
                    }
                    return WorkReference(
                        repository: ConfiguredRepository(owner: owner, name: name),
                        issueNumber: issueNumber
                    )
                }(),
                model: record.model,
                startedAt: record.startedAt,
                lastSeenAt: record.lastSeenAt
            )
        }
    }

    public func replaceSessions(_ sessions: [AgentSession]) throws {
        try replaceAll(CachedSessionRecord.self)
        for session in sessions {
            context.insert(
                CachedSessionRecord(
                    id: session.id,
                    source: session.source,
                    status: session.status.rawValue,
                    linkedTaskID: session.linkedTaskID,
                    repositoryOwner: session.workItem?.repository.owner,
                    repositoryName: session.workItem?.repository.name,
                    issueNumber: session.workItem?.issueNumber,
                    model: session.model,
                    startedAt: session.startedAt,
                    lastSeenAt: session.lastSeenAt
                )
            )
        }
        try context.save()
    }

    public func loadAgentSummaries() throws -> [AgentSummary] {
        let descriptor = FetchDescriptor<CachedAgentRecord>(
            sortBy: [SortDescriptor(\.activeSessionCount, order: .reverse)]
        )
        return try context.fetch(descriptor).map { record in
            AgentSummary(
                id: record.id,
                name: record.name,
                health: AgentHealthStatus(rawValue: record.health) ?? .idle,
                activeTaskCount: record.activeTaskCount,
                activeSessionCount: record.activeSessionCount,
                recentActivity: record.recentActivity,
                updatedAt: record.updatedAt
            )
        }
    }

    public func replaceAgentSummaries(_ agents: [AgentSummary]) throws {
        try replaceAll(CachedAgentRecord.self)
        for agent in agents {
            context.insert(
                CachedAgentRecord(
                    id: agent.id,
                    name: agent.name,
                    health: agent.health.rawValue,
                    activeTaskCount: agent.activeTaskCount,
                    activeSessionCount: agent.activeSessionCount,
                    recentActivity: agent.recentActivity,
                    updatedAt: agent.updatedAt
                )
            )
        }
        try context.save()
    }

    private func replaceAll<Model: PersistentModel>(_: Model.Type) throws {
        let existing = try context.fetch(FetchDescriptor<Model>())
        existing.forEach(context.delete)
    }

    private func encodeStrings(_ values: [String]) -> Data {
        (try? encoder.encode(values)) ?? Data()
    }

    private func decodeStrings(_ data: Data) -> [String] {
        (try? decoder.decode([String].self, from: data)) ?? []
    }
}
