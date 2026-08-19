import Foundation
import SwiftData

func assignIfNeeded<Record: AnyObject, Value: Equatable>(
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
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    public let modelContainer: ModelContainer

    var context: ModelContext {
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
            CachedKanbanTaskRecord.self,
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
                hermesSessionID: $0.hermesSessionID,
                profileID: $0.profileID
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
            record.profileID = conversation.profileID
        } else {
            context.insert(
                CachedConversationRecord(
                    id: conversation.id,
                    title: conversation.title,
                    modelID: conversation.modelID,
                    updatedAt: conversation.updatedAt,
                    hermesSessionID: conversation.hermesSessionID,
                    profileID: conversation.profileID
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
