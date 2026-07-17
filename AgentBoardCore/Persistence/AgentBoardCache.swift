import Foundation
import SwiftData

@Model
private final class CachedConversationRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var modelID: String?
    var updatedAt: Date
    var hermesSessionID: String?

    init(id: UUID, title: String, modelID: String?, updatedAt: Date, hermesSessionID: String? = nil) {
        self.id = id
        self.title = title
        self.modelID = modelID
        self.updatedAt = updatedAt
        self.hermesSessionID = hermesSessionID
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

    func update(from item: WorkItem, assigneesData: Data, labelsData: Data) -> Bool {
        var didChange = false
        didChange = assignIfNeeded(self, \.repositoryOwner, to: item.repository.owner) || didChange
        didChange = assignIfNeeded(self, \.repositoryName, to: item.repository.name) || didChange
        didChange = assignIfNeeded(self, \.issueNumber, to: item.issueNumber) || didChange
        didChange = assignIfNeeded(self, \.title, to: item.title) || didChange
        didChange = assignIfNeeded(self, \.bodySummary, to: item.bodySummary) || didChange
        didChange = assignIfNeeded(self, \.isClosed, to: item.isClosed) || didChange
        didChange = assignIfNeeded(self, \.assigneesData, to: assigneesData) || didChange
        didChange = assignIfNeeded(self, \.milestoneNumber, to: item.milestone?.number) || didChange
        didChange = assignIfNeeded(self, \.milestoneTitle, to: item.milestone?.title) || didChange
        didChange = assignIfNeeded(self, \.labelsData, to: labelsData) || didChange
        didChange = assignIfNeeded(self, \.status, to: item.status.rawValue) || didChange
        didChange = assignIfNeeded(self, \.priority, to: item.priority.rawValue) || didChange
        didChange = assignIfNeeded(self, \.agentHint, to: item.agentHint) || didChange
        didChange = assignIfNeeded(self, \.createdAt, to: item.createdAt) || didChange
        didChange = assignIfNeeded(self, \.updatedAt, to: item.updatedAt) || didChange
        return didChange
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
    var pid: Int?
    var tmuxSession: String?
    var tmuxPaneID: String?
    var lastOutput: String?

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
        lastSeenAt: Date,
        pid: Int? = nil,
        tmuxSession: String? = nil,
        tmuxPaneID: String? = nil,
        lastOutput: String? = nil
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
        self.pid = pid
        self.tmuxSession = tmuxSession
        self.tmuxPaneID = tmuxPaneID
        self.lastOutput = lastOutput
    }

    func update(from session: AgentSession) -> Bool {
        var didChange = false
        didChange = assignIfNeeded(self, \.source, to: session.source) || didChange
        didChange = assignIfNeeded(self, \.status, to: session.status.rawValue) || didChange
        didChange = assignIfNeeded(self, \.linkedTaskID, to: session.linkedTaskID) || didChange
        didChange = assignIfNeeded(self, \.repositoryOwner, to: session.workItem?.repository.owner) || didChange
        didChange = assignIfNeeded(self, \.repositoryName, to: session.workItem?.repository.name) || didChange
        didChange = assignIfNeeded(self, \.issueNumber, to: session.workItem?.issueNumber) || didChange
        didChange = assignIfNeeded(self, \.model, to: session.model) || didChange
        didChange = assignIfNeeded(self, \.startedAt, to: session.startedAt) || didChange
        didChange = assignIfNeeded(self, \.lastSeenAt, to: session.lastSeenAt) || didChange
        didChange = assignIfNeeded(self, \.pid, to: session.pid) || didChange
        didChange = assignIfNeeded(self, \.tmuxSession, to: session.tmuxSession) || didChange
        didChange = assignIfNeeded(self, \.tmuxPaneID, to: session.tmuxPaneID) || didChange
        didChange = assignIfNeeded(self, \.lastOutput, to: session.lastOutput) || didChange
        return didChange
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

    func update(from agent: AgentSummary) -> Bool {
        var didChange = false
        didChange = assignIfNeeded(self, \.name, to: agent.name) || didChange
        didChange = assignIfNeeded(self, \.health, to: agent.health.rawValue) || didChange
        didChange = assignIfNeeded(self, \.activeTaskCount, to: agent.activeTaskCount) || didChange
        didChange = assignIfNeeded(self, \.activeSessionCount, to: agent.activeSessionCount) || didChange
        didChange = assignIfNeeded(self, \.recentActivity, to: agent.recentActivity) || didChange
        didChange = assignIfNeeded(self, \.updatedAt, to: agent.updatedAt) || didChange
        return didChange
    }
}

private func assignIfNeeded<Record: AnyObject, Value: Equatable>(
    _ record: Record,
    _ keyPath: ReferenceWritableKeyPath<Record, Value>,
    to value: Value
) -> Bool {
    guard record[keyPath: keyPath] != value else { return false }
    record[keyPath: keyPath] = value
    return true
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
                updatedAt: $0.updatedAt,
                hermesSessionID: $0.hermesSessionID
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
            record.hermesSessionID = conversation.hermesSessionID
        } else {
            context.insert(
                CachedConversationRecord(
                    id: conversation.id,
                    title: conversation.title,
                    modelID: conversation.modelID,
                    updatedAt: conversation.updatedAt,
                    hermesSessionID: conversation.hermesSessionID
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
                status: WorkState(rawValue: record.status) ?? .ready,
                priority: WorkPriority(rawValue: record.priority) ?? .p2,
                agentHint: record.agentHint,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
    }

    public func replaceWorkItems(_ items: [WorkItem]) throws {
        let existing = try context.fetch(FetchDescriptor<CachedWorkItemRecord>())
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var incomingIDs = Set<String>()
        var didChange = false

        for item in items {
            incomingIDs.insert(item.id)
            let assigneesData = encodeStrings(item.assignees)
            let labelsData = encodeStrings(item.labels)

            if let record = existingByID[item.id] {
                didChange = record.update(
                    from: item,
                    assigneesData: assigneesData,
                    labelsData: labelsData
                ) || didChange
            } else {
                context.insert(makeWorkItemRecord(item, assigneesData: assigneesData, labelsData: labelsData))
                didChange = true
            }
        }

        for record in existing where !incomingIDs.contains(record.id) {
            context.delete(record)
            didChange = true
        }

        if didChange {
            try context.save()
        }
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
                lastSeenAt: record.lastSeenAt,
                pid: record.pid,
                tmuxSession: record.tmuxSession,
                tmuxPaneID: record.tmuxPaneID,
                lastOutput: record.lastOutput
            )
        }
    }

    public func replaceSessions(_ sessions: [AgentSession]) throws {
        let existing = try context.fetch(FetchDescriptor<CachedSessionRecord>())
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var incomingIDs = Set<String>()
        var didChange = false

        for session in sessions {
            incomingIDs.insert(session.id)
            if let record = existingByID[session.id] {
                didChange = record.update(from: session) || didChange
            } else {
                context.insert(makeSessionRecord(session))
                didChange = true
            }
        }

        for record in existing where !incomingIDs.contains(record.id) {
            context.delete(record)
            didChange = true
        }

        if didChange {
            try context.save()
        }
    }

    public func deleteConversation(id: UUID) throws {
        let records = try context.fetch(
            FetchDescriptor<CachedConversationRecord>(
                predicate: #Predicate { $0.id == id }
            )
        )
        records.forEach(context.delete)

        let messages = try context.fetch(
            FetchDescriptor<CachedMessageRecord>(
                predicate: #Predicate { $0.conversationID == id }
            )
        )
        messages.forEach(context.delete)
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
        let existing = try context.fetch(FetchDescriptor<CachedAgentRecord>())
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var incomingIDs = Set<String>()
        var didChange = false

        for agent in agents {
            incomingIDs.insert(agent.id)
            if let record = existingByID[agent.id] {
                didChange = record.update(from: agent) || didChange
            } else {
                context.insert(makeAgentRecord(agent))
                didChange = true
            }
        }

        for record in existing where !incomingIDs.contains(record.id) {
            context.delete(record)
            didChange = true
        }

        if didChange {
            try context.save()
        }
    }

    private func makeWorkItemRecord(
        _ item: WorkItem,
        assigneesData: Data,
        labelsData: Data
    ) -> CachedWorkItemRecord {
        CachedWorkItemRecord(
            id: item.id,
            repositoryOwner: item.repository.owner,
            repositoryName: item.repository.name,
            issueNumber: item.issueNumber,
            title: item.title,
            bodySummary: item.bodySummary,
            isClosed: item.isClosed,
            assigneesData: assigneesData,
            milestoneNumber: item.milestone?.number,
            milestoneTitle: item.milestone?.title,
            labelsData: labelsData,
            status: item.status.rawValue,
            priority: item.priority.rawValue,
            agentHint: item.agentHint,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
    }

    private func makeSessionRecord(_ session: AgentSession) -> CachedSessionRecord {
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
            lastSeenAt: session.lastSeenAt,
            pid: session.pid,
            tmuxSession: session.tmuxSession,
            tmuxPaneID: session.tmuxPaneID,
            lastOutput: session.lastOutput
        )
    }

    private func makeAgentRecord(_ agent: AgentSummary) -> CachedAgentRecord {
        CachedAgentRecord(
            id: agent.id,
            name: agent.name,
            health: agent.health.rawValue,
            activeTaskCount: agent.activeTaskCount,
            activeSessionCount: agent.activeSessionCount,
            recentActivity: agent.recentActivity,
            updatedAt: agent.updatedAt
        )
    }

    private func encodeStrings(_ values: [String]) -> Data {
        (try? encoder.encode(values)) ?? Data()
    }

    private func decodeStrings(_ data: Data) -> [String] {
        (try? decoder.decode([String].self, from: data)) ?? []
    }
}

// MARK: - Protocol conformance

extension AgentBoardCache: AgentBoardCacheProtocol {}
