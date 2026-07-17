import Foundation
import SwiftData

@Model
final class CachedKanbanTaskRecord {
    @Attribute(.unique) var id: String
    var title: String
    var body: String?
    var assignee: String?
    var status: String
    var priority: Int
    var createdBy: String?
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var workspaceKind: String
    var workspacePath: String?
    var tenant: String?
    var result: String?
    /// Nil means `KanbanTask.skills == nil`; non-nil (possibly encoding `[]`)
    /// means the task has a skills array. Keeps nil vs. empty distinct.
    var skillsData: Data?

    init(
        id: String,
        title: String,
        body: String?,
        assignee: String?,
        status: String,
        priority: Int,
        createdBy: String?,
        createdAt: Date,
        startedAt: Date?,
        completedAt: Date?,
        workspaceKind: String,
        workspacePath: String?,
        tenant: String?,
        result: String?,
        skillsData: Data?
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
        self.skillsData = skillsData
    }

    func update(from task: KanbanTask, skillsData: Data?) -> Bool {
        var didChange = false
        didChange = assignIfNeeded(self, \.title, to: task.title) || didChange
        didChange = assignIfNeeded(self, \.body, to: task.body) || didChange
        didChange = assignIfNeeded(self, \.assignee, to: task.assignee) || didChange
        didChange = assignIfNeeded(self, \.status, to: task.status.rawValue) || didChange
        didChange = assignIfNeeded(self, \.priority, to: task.priority) || didChange
        didChange = assignIfNeeded(self, \.createdBy, to: task.createdBy) || didChange
        didChange = assignIfNeeded(self, \.createdAt, to: task.createdAt) || didChange
        didChange = assignIfNeeded(self, \.startedAt, to: task.startedAt) || didChange
        didChange = assignIfNeeded(self, \.completedAt, to: task.completedAt) || didChange
        didChange = assignIfNeeded(self, \.workspaceKind, to: task.workspaceKind.rawValue) || didChange
        didChange = assignIfNeeded(self, \.workspacePath, to: task.workspacePath) || didChange
        didChange = assignIfNeeded(self, \.tenant, to: task.tenant) || didChange
        didChange = assignIfNeeded(self, \.result, to: task.result) || didChange
        didChange = assignIfNeeded(self, \.skillsData, to: skillsData) || didChange
        return didChange
    }
}

extension AgentBoardCache {
    public func loadKanbanTasks() throws -> [KanbanTask] {
        let descriptor = FetchDescriptor<CachedKanbanTaskRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { record in
            KanbanTask(
                id: record.id,
                title: record.title,
                body: record.body,
                assignee: record.assignee,
                status: KanbanStatus(rawValue: record.status) ?? .todo,
                priority: record.priority,
                createdBy: record.createdBy,
                createdAt: record.createdAt,
                startedAt: record.startedAt,
                completedAt: record.completedAt,
                workspaceKind: KanbanWorkspaceKind(rawValue: record.workspaceKind) ?? .scratch,
                workspacePath: record.workspacePath,
                tenant: record.tenant,
                result: record.result,
                skills: decodeOptionalStrings(record.skillsData)
            )
        }
    }

    public func replaceKanbanTasks(_ tasks: [KanbanTask]) throws {
        let existing = try context.fetch(FetchDescriptor<CachedKanbanTaskRecord>())
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var incomingIDs = Set<String>()
        var didChange = false

        for task in tasks {
            incomingIDs.insert(task.id)
            let skillsData = encodeOptionalStrings(task.skills)

            if let record = existingByID[task.id] {
                didChange = record.update(from: task, skillsData: skillsData) || didChange
            } else {
                context.insert(makeKanbanTaskRecord(task, skillsData: skillsData))
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

    private func makeKanbanTaskRecord(_ task: KanbanTask, skillsData: Data?) -> CachedKanbanTaskRecord {
        CachedKanbanTaskRecord(
            id: task.id,
            title: task.title,
            body: task.body,
            assignee: task.assignee,
            status: task.status.rawValue,
            priority: task.priority,
            createdBy: task.createdBy,
            createdAt: task.createdAt,
            startedAt: task.startedAt,
            completedAt: task.completedAt,
            workspaceKind: task.workspaceKind.rawValue,
            workspacePath: task.workspacePath,
            tenant: task.tenant,
            result: task.result,
            skillsData: skillsData
        )
    }

    fileprivate func encodeOptionalStrings(_ values: [String]?) -> Data? {
        guard let values else { return nil }
        return try? encoder.encode(values)
    }

    fileprivate func decodeOptionalStrings(_ data: Data?) -> [String]? {
        guard let data else { return nil }
        return try? decoder.decode([String].self, from: data)
    }
}
