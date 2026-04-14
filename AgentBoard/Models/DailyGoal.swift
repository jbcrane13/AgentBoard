import Foundation
import SwiftData

@Model
final class DailyGoal: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String
    var project: String
    var assignedAgent: String?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var date: Date
    var sortOrder: Int
    var linkedIssueNumber: Int?

    init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String = "",
        project: String,
        assignedAgent: String? = nil,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        date: Date = .now,
        sortOrder: Int = 0,
        linkedIssueNumber: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.project = project
        self.assignedAgent = assignedAgent
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.date = date
        self.sortOrder = sortOrder
        self.linkedIssueNumber = linkedIssueNumber
    }
}

// MARK: - Convenience

extension DailyGoal {
    var isLinkedToIssue: Bool {
        linkedIssueNumber != nil
    }

    func markComplete() {
        isCompleted = true
        completedAt = .now
    }

    func markIncomplete() {
        isCompleted = false
        completedAt = nil
    }
}

// MARK: - Samples

extension DailyGoal {
    static func sample(
        title: String = "Sample Goal",
        project: String = "AgentBoard",
        isCompleted: Bool = false
    ) -> DailyGoal {
        DailyGoal(
            title: title,
            goalDescription: "A sample daily goal for testing.",
            project: project,
            isCompleted: isCompleted
        )
    }

    @MainActor
    static var preview: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: DailyGoal.self, configurations: config)
        let context = container.mainContext

        let goals = [
            DailyGoal(title: "Implement DailyGoal model", project: "AgentBoard", isCompleted: true, sortOrder: 0),
            DailyGoal(title: "Add todo board view", project: "AgentBoard", sortOrder: 1),
            DailyGoal(title: "Wire up GitHub issues", project: "AgentBoard", assignedAgent: "claude-code", sortOrder: 2),
            DailyGoal(title: "Fix WebSocket reconnect", project: "NetMonitor", sortOrder: 0, linkedIssueNumber: 42)
        ]

        for goal in goals {
            context.insert(goal)
        }

        return container
    }
}
