import Foundation
import Observation

public protocol LifeOpsIngestionService: Sendable {
    func fetchNewInboxItems() async throws -> [LifeTask]
    func fetchCalendarPrepItems() async throws -> [LifeTask]
    func fetchFamilyRequests() async throws -> [FamilyRequest]
}

public protocol LifeOpsActionService: Sendable {
    func submitQuickCapture(_ text: String) async throws -> LifeTask
    func approveAction(_ action: ApprovalAction) async throws
    func rejectAction(_ action: ApprovalAction) async throws
    func askDaneel(task: LifeTask, message: String) async throws -> ApprovalAction?
}

public struct FixtureLifeOpsIngestionService: LifeOpsIngestionService {
    public init() {}

    public func fetchNewInboxItems() async throws -> [LifeTask] {
        LifeOpsFixtures.makeTasks().filter { $0.status == .inbox }
    }

    public func fetchCalendarPrepItems() async throws -> [LifeTask] {
        LifeOpsFixtures.makeTasks().filter { $0.category == .calendar }
    }

    public func fetchFamilyRequests() async throws -> [FamilyRequest] {
        LifeOpsFixtures.makeFamilyRequests()
    }
}

public struct FixtureLifeOpsActionService: LifeOpsActionService {
    public init() {}

    public func submitQuickCapture(_ text: String) async throws -> LifeTask {
        LifeTask(
            title: text,
            category: .personal,
            status: .inbox,
            priority: .p2,
            nextAction: "Clarify the next action.",
            source: LifeTaskSource(
                sourceType: .manual,
                sourceID: "quick-capture",
                displayName: "Quick capture"
            )
        )
    }

    public func approveAction(_: ApprovalAction) async throws {}

    public func rejectAction(_: ApprovalAction) async throws {}

    public func askDaneel(task _: LifeTask, message _: String) async throws -> ApprovalAction? {
        nil
    }
}

@MainActor
@Observable
public final class LifeOpsStore {
    public private(set) var tasks: [LifeTask]
    public private(set) var approvalActions: [ApprovalAction]
    public private(set) var jobOpportunities: [JobOpportunity]
    public private(set) var familyRequests: [FamilyRequest]
    public private(set) var lastRefreshAt: Date
    public var statusMessage: String?

    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let nowProvider: () -> Date

    public init(
        seedData: LifeOpsSeedData? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        let initialData = seedData ?? LifeOpsFixtures.makeSeedData(now: now())
        self.tasks = initialData.tasks
        self.approvalActions = initialData.approvalActions
        self.jobOpportunities = initialData.jobOpportunities
        self.familyRequests = initialData.familyRequests
        self.lastRefreshAt = now()
        self.calendar = calendar
        self.nowProvider = now
    }

    public var nowTasks: [LifeTask] {
        Array(visibleTasks
            .filter { $0.priority == .p0 || $0.priority == .p1 }
            .sorted(by: priorityDueUrgencySort)
            .prefix(3))
    }

    public var todayTasks: [LifeTask] {
        visibleTasks
            .filter { task in
                task.priority == .p1 || task.dueAt.map(isTodayOrOverdue) == true
            }
            .sorted(by: priorityDueUrgencySort)
    }

    public var inboxTasks: [LifeTask] {
        tasks
            .filter { $0.status == .inbox }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public var waitingTasks: [LifeTask] {
        tasks
            .filter { $0.status == .waitingOnExternal }
            .sorted(by: priorityDueUrgencySort)
    }

    public var familyTasks: [LifeTask] {
        tasks
            .filter { task in
                task.owner == .family ||
                    task.owner == .sarah ||
                    task.category == .family ||
                    task.source?.originActor == .sarah
            }
            .sorted(by: priorityDueUrgencySort)
    }

    public var pendingApprovals: [ApprovalAction] {
        approvalActions
            .filter { $0.status == .pending }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public var jobFollowUpsDue: [JobOpportunity] {
        let endOfToday = endOfDay(for: nowProvider())

        return jobOpportunities
            .filter { opportunity in
                guard opportunity.stage != .closed,
                      opportunity.stage != .rejected,
                      let nextFollowUpAt = opportunity.nextFollowUpAt else {
                    return false
                }
                return nextFollowUpAt <= endOfToday
            }
            .sorted { first, second in
                (first.nextFollowUpAt ?? .distantFuture) < (second.nextFollowUpAt ?? .distantFuture)
            }
    }

    @discardableResult
    public func createQuickTask(title: String) -> LifeTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let now = nowProvider()
        let task = LifeTask(
            title: trimmed,
            summary: "Captured quickly for later triage.",
            category: .personal,
            status: .inbox,
            priority: .p2,
            urgencyScore: 45,
            importanceScore: 45,
            estimatedMinutes: 10,
            nextAction: "Clarify the next action.",
            owner: .blake,
            assignee: .blake,
            source: LifeTaskSource(
                sourceType: .manual,
                sourceID: "quick-capture-\(UUID().uuidString)",
                displayName: "Quick capture"
            ),
            confidence: 1.0,
            createdAt: now,
            updatedAt: now
        )

        tasks.insert(task, at: 0)
        lastRefreshAt = now
        statusMessage = "Captured \"\(trimmed)\"."
        return task
    }

    public func markDone(id: UUID) {
        updateTask(id: id) { task, now in
            task.status = .done
            task.updatedAt = now
        }
    }

    public func snooze(id: UUID, until date: Date) {
        updateTask(id: id) { task, now in
            task.status = .snoozed
            task.snoozedUntil = date
            task.updatedAt = now
        }
    }

    public func assignToDaneel(id: UUID) {
        updateTask(id: id) { task, now in
            task.status = .assignedToDaneel
            task.assignee = .daneel
            task.updatedAt = now
        }
    }

    public func updateJobOpportunityStage(id: UUID, stage: JobOpportunityStage) {
        guard let index = jobOpportunities.firstIndex(where: { $0.id == id }) else { return }
        jobOpportunities[index].stage = stage
        jobOpportunities[index].updatedAt = nowProvider()
    }

    private var visibleTasks: [LifeTask] {
        let now = nowProvider()
        return tasks.filter { task in
            !task.status.isTerminal && !isSnoozed(task, now: now)
        }
    }

    private func isSnoozed(_ task: LifeTask, now: Date) -> Bool {
        guard task.status == .snoozed || task.snoozedUntil != nil else {
            return false
        }

        guard let snoozedUntil = task.snoozedUntil else {
            return true
        }

        return snoozedUntil > now
    }

    private func priorityDueUrgencySort(_ lhs: LifeTask, _ rhs: LifeTask) -> Bool {
        if lhs.priority.sortRank != rhs.priority.sortRank {
            return lhs.priority.sortRank < rhs.priority.sortRank
        }

        switch (lhs.dueAt, rhs.dueAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            break
        }

        if lhs.urgencyScore != rhs.urgencyScore {
            return lhs.urgencyScore > rhs.urgencyScore
        }

        if lhs.importanceScore != rhs.importanceScore {
            return lhs.importanceScore > rhs.importanceScore
        }

        return lhs.updatedAt > rhs.updatedAt
    }

    private func isTodayOrOverdue(_ date: Date) -> Bool {
        date <= endOfDay(for: nowProvider())
    }

    private func endOfDay(for date: Date) -> Date {
        calendar.dateInterval(of: .day, for: date)?.end.addingTimeInterval(-1) ?? date
    }

    private func updateTask(id: UUID, mutation: (inout LifeTask, Date) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let now = nowProvider()
        mutation(&tasks[index], now)
        lastRefreshAt = now
    }
}
