import Foundation

/// Status of an epic or subtask
public enum TaskStatus: String, Codable, Sendable, CaseIterable {
    case todo = "To Do"
    case inProgress = "In Progress"
    case done = "Done"
    case blocked = "Blocked"
    
    public var iconName: String {
        switch self {
        case .todo: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        case .blocked: return "exclamationmark.circle.fill"
        }
    }
    
    public var color: String {
        switch self {
        case .todo: return "gray"
        case .inProgress: return "blue"
        case .done: return "green"
        case .blocked: return "red"
        }
    }
}

/// Represents a subtask within an epic
public struct Subtask: Codable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public var status: TaskStatus
    public var assignee: String?
    public var createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        status: TaskStatus = .todo,
        assignee: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.assignee = assignee
        self.createdAt = Date()
    }
}

/// Represents an epic (a large task that can be broken down into subtasks)
public struct Epic: Codable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public var description: String?
    public var priority: Priority
    public var status: TaskStatus
    public var subtasks: [Subtask]
    public var assignee: String?
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    
    /// Computed progress based on completed subtasks
    public var progress: Double {
        guard !subtasks.isEmpty else { return 0 }
        let completedCount = subtasks.filter { $0.status == .done }.count
        return Double(completedCount) / Double(subtasks.count)
    }
    
    /// Number of completed subtasks
    public var completedSubtaskCount: Int {
        subtasks.filter { $0.status == .done }.count
    }
    
    /// Whether all subtasks are complete
    public var isComplete: Bool {
        !subtasks.isEmpty && subtasks.allSatisfy { $0.status == .done }
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        priority: Priority = .medium,
        status: TaskStatus = .todo,
        subtasks: [Subtask] = [],
        assignee: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.status = status
        self.subtasks = subtasks
        self.assignee = assignee
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Update a subtask's status
    public mutating func updateSubtask(id: String, status: TaskStatus) {
        guard let index = subtasks.firstIndex(where: { $0.id == id }) else { return }
        subtasks[index].status = status
        updatedAt = Date()
    }
    
    /// Add a new subtask
    public mutating func addSubtask(_ subtask: Subtask) {
        subtasks.append(subtask)
        updatedAt = Date()
    }
    
    /// Remove a subtask
    public mutating func removeSubtask(id: String) {
        subtasks.removeAll { $0.id == id }
        updatedAt = Date()
    }
    
    /// Create a sample epic for preview purposes
    public static func sample() -> Epic {
        var epic = Epic(
            title: "Implement User Authentication",
            description: "Add complete authentication flow including login, signup, and password reset",
            priority: Priority.high,
            status: .inProgress,
            tags: ["security", "backend", "frontend"]
        )
        epic.addSubtask(Subtask(title: "Design login UI", status: .done, assignee: "Alice"))
        epic.addSubtask(Subtask(title: "Implement JWT tokens", status: .done, assignee: "Bob"))
        epic.addSubtask(Subtask(title: "Create signup endpoint", status: .inProgress, assignee: "Charlie"))
        epic.addSubtask(Subtask(title: "Add password reset flow", status: .todo))
        epic.addSubtask(Subtask(title: "Write integration tests", status: .todo, assignee: "Diana"))
        epic.addSubtask(Subtask(title: "Deploy to staging", status: .blocked))
        return epic
    }
}