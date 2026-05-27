import AgentBoardCore
import Foundation
import Testing

@Suite("LifeOps models")
struct LifeOpsModelsTests {
    @Test func lifePriorityDisplayOrderMapsUrgentFirst() {
        #expect(LifePriority.displayOrder == [.p0, .p1, .p2, .p3])
        #expect(LifePriority.displayOrder.map(\.displayName) == ["P0", "P1", "P2", "P3"])
        #expect(LifePriority.p0.sortRank < LifePriority.p1.sortRank)
        #expect(LifePriority.p1.sortRank < LifePriority.p2.sortRank)
        #expect(LifePriority.p2.sortRank < LifePriority.p3.sortRank)
    }

    @Test func lifeTaskCodableRoundTripPreservesAllFields() throws {
        let source = LifeTaskSource(
            sourceType: .email,
            sourceID: "message-1",
            sourceURL: URL(string: "message://lifeops/message-1"),
            displayName: "Recruiter email",
            originActor: .external
        )
        let task = LifeTask(
            id: UUID(),
            title: "Reply to recruiter",
            summary: "Pick times and reply.",
            category: .email,
            status: .needsBlake,
            priority: .p1,
            urgencyScore: 80,
            importanceScore: 75,
            dueAt: fixedNow,
            snoozedUntil: fixedNow.addingTimeInterval(3600),
            estimatedMinutes: 12,
            nextAction: "Pick two windows.",
            owner: .blake,
            assignee: .daneel,
            source: source,
            confidence: 0.91,
            createdAt: fixedNow.addingTimeInterval(-600),
            updatedAt: fixedNow
        )

        #expect(try roundTrip(task) == task)
    }

    @Test func approvalActionCodableRoundTripPreservesAllFields() throws {
        let approval = ApprovalAction(
            id: UUID(),
            taskID: UUID(),
            title: "Approve reply",
            summary: "Daneel drafted a reply.",
            actionType: .sendEmail,
            proposedPayloadPreview: "Thanks, Thursday works.",
            riskLevel: .medium,
            status: .pending,
            createdAt: fixedNow.addingTimeInterval(-120),
            updatedAt: fixedNow
        )

        #expect(try roundTrip(approval) == approval)
    }

    @Test func jobOpportunityCodableRoundTripPreservesAllFields() throws {
        let taskID = UUID()
        let opportunity = JobOpportunity(
            id: UUID(),
            company: "Northstar Labs",
            role: "Agent Platform Lead",
            url: URL(string: "https://example.com/job"),
            contactName: "Jordan",
            contactChannel: "Email",
            stage: .followUpDue,
            lastTouchAt: fixedNow.addingTimeInterval(-86400),
            nextFollowUpAt: fixedNow,
            notes: "Good fit.",
            associatedTaskIDs: [taskID],
            createdAt: fixedNow.addingTimeInterval(-172_800),
            updatedAt: fixedNow
        )

        #expect(try roundTrip(opportunity) == opportunity)
    }

    @Test func familyRequestCodableRoundTripPreservesAllFields() throws {
        let taskID = UUID()
        let approvalID = UUID()
        let request = FamilyRequest(
            id: UUID(),
            requester: .sarah,
            source: LifeTaskSource(
                sourceType: .message,
                sourceID: "imessage-1",
                displayName: "Sarah via iMessage",
                originActor: .sarah
            ),
            rawText: "Can you remind Blake to call the vet tomorrow?",
            interpretedAction: .createTask,
            linkedTaskID: taskID,
            linkedApprovalID: approvalID,
            status: .convertedToTask,
            createdAt: fixedNow.addingTimeInterval(-300),
            updatedAt: fixedNow
        )

        #expect(try roundTrip(request) == request)
    }

    @Test func fixturesConstructValidRelatedData() {
        let seed = LifeOpsFixtures.makeSeedData(now: fixedNow)
        let taskIDs = Set(seed.tasks.map(\.id))
        let approvalIDs = Set(seed.approvalActions.map(\.id))

        #expect(!seed.tasks.isEmpty)
        #expect(!seed.approvalActions.isEmpty)
        #expect(!seed.jobOpportunities.isEmpty)
        #expect(!seed.familyRequests.isEmpty)

        for approval in seed.approvalActions {
            if let taskID = approval.taskID {
                #expect(taskIDs.contains(taskID))
            }
        }

        for opportunity in seed.jobOpportunities {
            #expect(!opportunity.associatedTaskIDs.isEmpty)
            for taskID in opportunity.associatedTaskIDs {
                #expect(taskIDs.contains(taskID))
            }
        }

        for request in seed.familyRequests {
            if let taskID = request.linkedTaskID {
                #expect(taskIDs.contains(taskID))
            }
            if let approvalID = request.linkedApprovalID {
                #expect(approvalIDs.contains(approvalID))
            }
        }
    }

    @Test func fixturesIncludeRequiredMVPExamples() {
        let seed = LifeOpsFixtures.makeSeedData(now: fixedNow)

        #expect(seed.tasks.contains { $0.id == LifeOpsFixtures.IDs.emailReplyTask && $0.category == .email })
        #expect(seed.tasks.contains { $0.id == LifeOpsFixtures.IDs.calendarPrepTask && $0.category == .calendar })
        #expect(seed.tasks.contains { $0.id == LifeOpsFixtures.IDs.jobFollowUpTask && $0.category == .jobSearch })
        #expect(seed.tasks.contains { $0.id == LifeOpsFixtures.IDs.familyMessageTask && $0.isSarahOriginated })
        #expect(seed.tasks.contains { $0.id == LifeOpsFixtures.IDs.waitingOnTask && $0.status == .waitingOnExternal })
        #expect(seed.tasks.contains { $0.id == LifeOpsFixtures.IDs.snoozedTask && $0.status == .snoozed })
        #expect(seed.approvalActions.contains { $0.id == LifeOpsFixtures.IDs.approval && $0.status == .pending })
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_779_907_600)

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
