import Foundation

/// Represents a task checkbox within an issue
public struct IssueTask: Codable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public var isCompleted: Bool
    public var assignee: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        isCompleted: Bool = false,
        assignee: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.assignee = assignee
    }
}

/// Represents an acceptance criterion for an issue
public struct AcceptanceCriterion: Codable, Identifiable, Sendable {
    public let id: String
    public var description: String
    public var isMet: Bool
    
    public init(
        id: String = UUID().uuidString,
        description: String,
        isMet: Bool = false
    ) {
        self.id = id
        self.description = description
        self.isMet = isMet
    }
}

/// Represents an issue associated with a Bead
public struct BeadIssue: Codable, Identifiable, Sendable {
    public let id: String
    public let beadId: String
    public var title: String
    public var description: String
    public var context: String?
    public var tasks: [IssueTask]
    public var acceptanceCriteria: [AcceptanceCriterion]
    public var priority: Priority
    public var createdAt: Date
    public var updatedAt: Date
    
    /// Computed progress based on completed tasks
    public var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(tasks.count)
    }
    
    /// Number of completed tasks
    public var completedTaskCount: Int {
        tasks.filter { $0.isCompleted }.count
    }
    
    /// Whether all tasks are complete
    public var isComplete: Bool {
        !tasks.isEmpty && tasks.allSatisfy { $0.isCompleted }
    }
    
    /// Whether all acceptance criteria are met
    public var allCriteriaMet: Bool {
        !acceptanceCriteria.isEmpty && acceptanceCriteria.allSatisfy { $0.isMet }
    }
    
    public init(
        id: String = UUID().uuidString,
        beadId: String,
        title: String,
        description: String,
        context: String? = nil,
        tasks: [IssueTask] = [],
        acceptanceCriteria: [AcceptanceCriterion] = [],
        priority: Priority = .medium
    ) {
        self.id = id
        self.beadId = beadId
        self.title = title
        self.description = description
        self.context = context
        self.tasks = tasks
        self.acceptanceCriteria = acceptanceCriteria
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Toggle task completion status
    public mutating func toggleTask(id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isCompleted.toggle()
        updatedAt = Date()
    }
    
    /// Toggle acceptance criterion status
    public mutating func toggleCriterion(id: String) {
        guard let index = acceptanceCriteria.firstIndex(where: { $0.id == id }) else { return }
        acceptanceCriteria[index].isMet.toggle()
        updatedAt = Date()
    }
    
    /// Add a new task
    public mutating func addTask(_ task: IssueTask) {
        tasks.append(task)
        updatedAt = Date()
    }
    
    /// Add a new acceptance criterion
    public mutating func addCriterion(_ criterion: AcceptanceCriterion) {
        acceptanceCriteria.append(criterion)
        updatedAt = Date()
    }
    
    /// Create a sample issue for preview purposes
    public static func sample() -> BeadIssue {
        var issue = BeadIssue(
            beadId: "bead-001",
            title: "Implement User Authentication",
            description: "Add complete authentication flow including login, signup, and password reset functionality.",
            context: "This is needed for the MVP launch scheduled for Q2. Currently users cannot access protected features.",
            priority: .high
        )
        issue.addTask(IssueTask(title: "Design login UI mockups", isCompleted: true, assignee: "Alice"))
        issue.addTask(IssueTask(title: "Implement JWT token generation", isCompleted: true, assignee: "Bob"))
        issue.addTask(IssueTask(title: "Create signup endpoint", isCompleted: false, assignee: "Charlie"))
        issue.addTask(IssueTask(title: "Add password reset flow", isCompleted: false))
        issue.addTask(IssueTask(title: "Write integration tests", isCompleted: false, assignee: "Diana"))
        issue.addCriterion(AcceptanceCriterion(description: "Users can log in with email and password", isMet: true))
        issue.addCriterion(AcceptanceCriterion(description: "New users can create accounts", isMet: false))
        issue.addCriterion(AcceptanceCriterion(description: "Password reset emails are sent within 30 seconds", isMet: false))
        return issue
    }
}
