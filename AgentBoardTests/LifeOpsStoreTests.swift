import AgentBoardCore
import Foundation
import Testing

@Suite("LifeOpsStore", .serialized)
@MainActor
struct LifeOpsStoreTests {
    @Test func nowTasksReturnsAtMostThreeSortedP0P1Tasks() {
        let store = makeStore(
            tasks: [
                makeTask(title: "P1 third", priority: .p1, urgency: 70, dueOffset: 3600),
                makeTask(title: "P0 first", priority: .p0, urgency: 30, dueOffset: 7200),
                makeTask(title: "P1 second", priority: .p1, urgency: 90, dueOffset: 1800),
                makeTask(title: "P1 fourth", priority: .p1, urgency: 60, dueOffset: 10800),
                makeTask(title: "P2 excluded", priority: .p2, urgency: 99, dueOffset: 600)
            ]
        )

        #expect(store.nowTasks.count == 3)
        #expect(store.nowTasks.map(\.title) == ["P0 first", "P1 second", "P1 third"])
    }

    @Test func doneAndSnoozedTasksDisappearFromToday() {
        let active = makeTask(title: "Active today", priority: .p1, dueOffset: 600)
        let done = makeTask(title: "Done today", status: .done, priority: .p1, dueOffset: 600)
        let snoozed = makeTask(
            title: "Snoozed today",
            status: .snoozed,
            priority: .p1,
            dueOffset: 600,
            snoozedUntil: fixedNow.addingTimeInterval(86400)
        )
        let store = makeStore(tasks: [active, done, snoozed])

        #expect(store.todayTasks.map(\.title) == ["Active today"])
    }

    @Test func familyTasksIncludeSarahOriginatedAndFamilyOwnedItems() {
        let sarahSource = makeTask(
            title: "Sarah source",
            category: .messages,
            source: LifeTaskSource(
                sourceType: .message,
                sourceID: "sarah-1",
                displayName: "Sarah via iMessage",
                originActor: .sarah
            )
        )
        let familyOwned = makeTask(title: "Family owner", category: .admin, owner: .family)
        let unrelated = makeTask(title: "Unrelated", category: .admin, owner: .blake)
        let store = makeStore(tasks: [sarahSource, familyOwned, unrelated])

        #expect(Set(store.familyTasks.map(\.title)) == ["Sarah source", "Family owner"])
    }

    @Test func pendingApprovalsFilterCorrectly() {
        let pending = ApprovalAction(
            title: "Pending",
            summary: "Needs approval.",
            actionType: .sendEmail,
            proposedPayloadPreview: "Draft",
            riskLevel: .medium,
            status: .pending,
            createdAt: fixedNow,
            updatedAt: fixedNow
        )
        let completed = ApprovalAction(
            title: "Completed",
            summary: "Already done.",
            actionType: .archiveEmail,
            proposedPayloadPreview: "Archive",
            riskLevel: .low,
            status: .completed,
            createdAt: fixedNow,
            updatedAt: fixedNow
        )
        let store = makeStore(approvalActions: [completed, pending])

        #expect(store.pendingApprovals == [pending])
    }

    @Test func quickCaptureCreatesInboxTask() throws {
        let store = makeStore(tasks: [])
        let created = try #require(store.createQuickTask(title: "  Pay registration fee  "))

        #expect(created.title == "Pay registration fee")
        #expect(created.status == .inbox)
        #expect(created.source?.sourceType == .manual)
        #expect(store.inboxTasks.contains(created))
    }

    @Test func markDoneSnoozeAndAssignMutateTaskState() throws {
        let task = makeTask(title: "Mutable", priority: .p1)
        let store = makeStore(tasks: [task])

        store.assignToDaneel(id: task.id)
        var updated = try #require(store.tasks.first)
        #expect(updated.status == .assignedToDaneel)
        #expect(updated.assignee == .daneel)

        store.snooze(id: task.id, until: fixedNow.addingTimeInterval(3600))
        updated = try #require(store.tasks.first)
        #expect(updated.status == .snoozed)
        #expect(updated.snoozedUntil == fixedNow.addingTimeInterval(3600))

        store.markDone(id: task.id)
        updated = try #require(store.tasks.first)
        #expect(updated.status == .done)
    }

    @Test func jobFollowUpsDueIncludesOpenOpportunitiesThroughToday() {
        let due = JobOpportunity(
            company: "Due Co",
            role: "Lead",
            stage: .followUpDue,
            nextFollowUpAt: fixedNow.addingTimeInterval(-600),
            associatedTaskIDs: [],
            createdAt: fixedNow,
            updatedAt: fixedNow
        )
        let later = JobOpportunity(
            company: "Later Co",
            role: "Lead",
            stage: .saved,
            nextFollowUpAt: fixedNow.addingTimeInterval(172_800),
            associatedTaskIDs: [],
            createdAt: fixedNow,
            updatedAt: fixedNow
        )
        let closed = JobOpportunity(
            company: "Closed Co",
            role: "Lead",
            stage: .closed,
            nextFollowUpAt: fixedNow.addingTimeInterval(-600),
            associatedTaskIDs: [],
            createdAt: fixedNow,
            updatedAt: fixedNow
        )
        let store = makeStore(jobOpportunities: [later, closed, due])

        #expect(store.jobFollowUpsDue == [due])
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_779_907_600)

    private func makeStore(
        tasks: [LifeTask] = [],
        approvalActions: [ApprovalAction] = [],
        jobOpportunities: [JobOpportunity] = [],
        familyRequests: [FamilyRequest] = []
    ) -> LifeOpsStore {
        LifeOpsStore(
            seedData: LifeOpsSeedData(
                tasks: tasks,
                approvalActions: approvalActions,
                jobOpportunities: jobOpportunities,
                familyRequests: familyRequests
            ),
            now: { fixedNow }
        )
    }

    private func makeTask(
        title: String,
        category: LifeTaskCategory = .personal,
        status: LifeTaskStatus = .needsBlake,
        priority: LifePriority = .p2,
        urgency: Int = 50,
        dueOffset: TimeInterval? = nil,
        snoozedUntil: Date? = nil,
        owner: LifeActor = .blake,
        source: LifeTaskSource? = nil
    ) -> LifeTask {
        LifeTask(
            id: UUID(),
            title: title,
            summary: "Summary",
            category: category,
            status: status,
            priority: priority,
            urgencyScore: urgency,
            importanceScore: 50,
            dueAt: dueOffset.map { fixedNow.addingTimeInterval($0) },
            snoozedUntil: snoozedUntil,
            estimatedMinutes: 10,
            nextAction: "Next action",
            owner: owner,
            assignee: .blake,
            source: source,
            confidence: 1.0,
            createdAt: fixedNow,
            updatedAt: fixedNow
        )
    }
}
