import Foundation

public struct LifeOpsSeedData: Sendable {
    public var tasks: [LifeTask]
    public var approvalActions: [ApprovalAction]
    public var jobOpportunities: [JobOpportunity]
    public var familyRequests: [FamilyRequest]

    public init(
        tasks: [LifeTask],
        approvalActions: [ApprovalAction],
        jobOpportunities: [JobOpportunity],
        familyRequests: [FamilyRequest]
    ) {
        self.tasks = tasks
        self.approvalActions = approvalActions
        self.jobOpportunities = jobOpportunities
        self.familyRequests = familyRequests
    }
}

public enum LifeOpsFixtures {
    public enum IDs {
        public static let emailReplyTask = uuid("5A5F6558-7BB8-465E-A55F-7F75C11FA001")
        public static let calendarPrepTask = uuid("5A5F6558-7BB8-465E-A55F-7F75C11FA002")
        public static let jobFollowUpTask = uuid("5A5F6558-7BB8-465E-A55F-7F75C11FA003")
        public static let familyMessageTask = uuid("5A5F6558-7BB8-465E-A55F-7F75C11FA004")
        public static let waitingOnTask = uuid("5A5F6558-7BB8-465E-A55F-7F75C11FA005")
        public static let snoozedTask = uuid("5A5F6558-7BB8-465E-A55F-7F75C11FA006")
        public static let inboxAdminTask = uuid("5A5F6558-7BB8-465E-A55F-7F75C11FA007")
        public static let approval = uuid("A61B2CE2-08A4-45E0-903A-7F75C11FA001")
        public static let completedApproval = uuid("A61B2CE2-08A4-45E0-903A-7F75C11FA002")
        public static let jobOpportunity = uuid("CF06A8BC-BFA0-4C9E-8E1E-7F75C11FA001")
        public static let familyRequest = uuid("AD6A4965-EBE6-442B-B006-7F75C11FA001")
    }

    public static func makeSeedData(now: Date = Date()) -> LifeOpsSeedData {
        let tasks = makeTasks(now: now)
        let approvals = makeApprovalActions(now: now)
        let jobs = makeJobOpportunities(now: now)
        let familyRequests = makeFamilyRequests(now: now)

        return LifeOpsSeedData(
            tasks: tasks,
            approvalActions: approvals,
            jobOpportunities: jobs,
            familyRequests: familyRequests
        )
    }

    public static func makeTasks(now: Date = Date()) -> [LifeTask] {
        [
            emailReplyTask(now: now),
            calendarPrepTask(now: now),
            jobFollowUpTask(now: now),
            familyMessageTask(now: now),
            waitingOnTask(now: now),
            snoozedTask(now: now),
            inboxAdminTask(now: now)
        ]
    }

    public static func makeApprovalActions(now: Date = Date()) -> [ApprovalAction] {
        [
            ApprovalAction(
                id: IDs.approval,
                taskID: IDs.emailReplyTask,
                title: "Approve recruiter reply",
                summary: "Daneel drafted a short availability response.",
                actionType: .sendEmail,
                proposedPayloadPreview: "Thanks for reaching out. I can do Thursday afternoon or Friday morning.",
                riskLevel: .medium,
                status: .pending,
                createdAt: offset(now, minutes: -25),
                updatedAt: offset(now, minutes: -25)
            ),
            ApprovalAction(
                id: IDs.completedApproval,
                taskID: IDs.jobFollowUpTask,
                title: "Archive old job alert",
                summary: "The alert was already captured into the pipeline.",
                actionType: .archiveEmail,
                proposedPayloadPreview: "Archive the duplicate alert email.",
                riskLevel: .low,
                status: .completed,
                createdAt: offset(now, days: -1),
                updatedAt: offset(now, hours: -20)
            )
        ]
    }

    public static func makeJobOpportunities(now: Date = Date()) -> [JobOpportunity] {
        [
            JobOpportunity(
                id: IDs.jobOpportunity,
                company: "Northstar Labs",
                role: "Agent Platform Lead",
                url: URL(string: "https://example.com/jobs/northstar-platform"),
                contactName: "Jordan Lee",
                contactChannel: "Email",
                stage: .followUpDue,
                lastTouchAt: offset(now, days: -5),
                nextFollowUpAt: offset(now, hours: -1),
                notes: "Strong fit for agent orchestration and QA workflow experience.",
                associatedTaskIDs: [IDs.jobFollowUpTask],
                createdAt: offset(now, days: -8),
                updatedAt: offset(now, hours: -1)
            )
        ]
    }

    public static func makeFamilyRequests(now: Date = Date()) -> [FamilyRequest] {
        [
            FamilyRequest(
                id: IDs.familyRequest,
                requester: .sarah,
                source: LifeTaskSource(
                    sourceType: .message,
                    sourceID: "imessage-sarah-vet",
                    displayName: "Sarah via iMessage",
                    originActor: .sarah
                ),
                rawText: "Can you remind Blake to call the vet tomorrow?",
                interpretedAction: .createTask,
                linkedTaskID: IDs.familyMessageTask,
                status: .convertedToTask,
                createdAt: offset(now, minutes: -35),
                updatedAt: offset(now, minutes: -35)
            )
        ]
    }

    private static func emailReplyTask(now: Date) -> LifeTask {
        LifeTask(
            id: IDs.emailReplyTask,
            title: "Reply to recruiter about availability",
            summary: "A recruiter asked for two interview windows this week.",
            category: .email,
            status: .needsBlake,
            priority: .p1,
            urgencyScore: 82,
            importanceScore: 76,
            dueAt: offset(now, hours: 4),
            estimatedMinutes: 12,
            nextAction: "Pick two realistic windows and approve Daneel's draft.",
            owner: .blake,
            assignee: .blake,
            source: LifeTaskSource(
                sourceType: .email,
                sourceID: "email-recruiter-availability",
                sourceURL: URL(string: "message://lifeops/recruiter-availability"),
                displayName: "Recruiter email"
            ),
            confidence: 0.93,
            createdAt: offset(now, hours: -2),
            updatedAt: offset(now, hours: -1)
        )
    }

    private static func calendarPrepTask(now: Date) -> LifeTask {
        LifeTask(
            id: IDs.calendarPrepTask,
            title: "Prep notes for benefits call",
            summary: "Calendar event has no agenda and needs a short checklist.",
            category: .calendar,
            status: .scheduled,
            priority: .p1,
            urgencyScore: 74,
            importanceScore: 68,
            dueAt: offset(now, hours: 6),
            estimatedMinutes: 20,
            nextAction: "List questions about enrollment deadlines and coverage.",
            owner: .blake,
            assignee: .blake,
            source: LifeTaskSource(
                sourceType: .calendar,
                sourceID: "calendar-benefits-call",
                displayName: "Today's calendar"
            ),
            confidence: 0.88,
            createdAt: offset(now, hours: -3),
            updatedAt: offset(now, minutes: -45)
        )
    }

    private static func jobFollowUpTask(now: Date) -> LifeTask {
        LifeTask(
            id: IDs.jobFollowUpTask,
            title: "Follow up with Northstar Labs",
            summary: "Application has been quiet for five business days.",
            category: .jobSearch,
            status: .needsBlake,
            priority: .p1,
            urgencyScore: 70,
            importanceScore: 84,
            dueAt: endOfDay(for: now),
            estimatedMinutes: 15,
            nextAction: "Send a concise follow-up note referencing the platform role.",
            owner: .blake,
            assignee: .daneel,
            source: LifeTaskSource(
                sourceType: .jobSearch,
                sourceID: "northstar-platform-role",
                sourceURL: URL(string: "https://example.com/jobs/northstar-platform"),
                displayName: "Job pipeline"
            ),
            confidence: 0.9,
            createdAt: offset(now, days: -5),
            updatedAt: offset(now, hours: -2)
        )
    }

    private static func familyMessageTask(now: Date) -> LifeTask {
        LifeTask(
            id: IDs.familyMessageTask,
            title: "Call the vet tomorrow",
            summary: "Sarah asked for a reminder to schedule the follow-up appointment.",
            category: .family,
            status: .needsBlake,
            priority: .p1,
            urgencyScore: 78,
            importanceScore: 72,
            dueAt: offset(now, days: 1),
            estimatedMinutes: 10,
            nextAction: "Call the vet and confirm the appointment window with Sarah.",
            owner: .family,
            assignee: .blake,
            source: LifeTaskSource(
                sourceType: .message,
                sourceID: "imessage-sarah-vet",
                displayName: "Sarah via iMessage",
                originActor: .sarah
            ),
            confidence: 0.95,
            createdAt: offset(now, minutes: -35),
            updatedAt: offset(now, minutes: -35)
        )
    }

    private static func waitingOnTask(now: Date) -> LifeTask {
        LifeTask(
            id: IDs.waitingOnTask,
            title: "Waiting on childcare schedule",
            summary: "Need confirmation before planning Friday afternoon.",
            category: .waitingOn,
            status: .waitingOnExternal,
            priority: .p2,
            urgencyScore: 52,
            importanceScore: 66,
            dueAt: offset(now, days: 2),
            estimatedMinutes: 5,
            nextAction: "Check whether the schedule arrived by tomorrow afternoon.",
            owner: .family,
            assignee: .external,
            source: LifeTaskSource(
                sourceType: .message,
                sourceID: "childcare-schedule-thread",
                displayName: "Family thread"
            ),
            confidence: 0.86,
            createdAt: offset(now, days: -1),
            updatedAt: offset(now, hours: -4)
        )
    }

    private static func snoozedTask(now: Date) -> LifeTask {
        LifeTask(
            id: IDs.snoozedTask,
            title: "Compare dental plan options",
            summary: "Useful but not needed until enrollment details are in.",
            category: .admin,
            status: .snoozed,
            priority: .p2,
            urgencyScore: 36,
            importanceScore: 58,
            dueAt: offset(now, days: 7),
            snoozedUntil: offset(now, days: 3),
            estimatedMinutes: 30,
            nextAction: "Review plan comparison after benefits documents arrive.",
            owner: .blake,
            assignee: .blake,
            source: LifeTaskSource(
                sourceType: .manual,
                sourceID: "manual-dental-plan",
                displayName: "Manual capture"
            ),
            confidence: 1.0,
            createdAt: offset(now, days: -2),
            updatedAt: offset(now, hours: -8)
        )
    }

    private static func inboxAdminTask(now: Date) -> LifeTask {
        LifeTask(
            id: IDs.inboxAdminTask,
            title: "Renew library card",
            summary: "Captured from a reminder note and needs triage.",
            category: .admin,
            status: .inbox,
            priority: .p3,
            urgencyScore: 24,
            importanceScore: 30,
            estimatedMinutes: 8,
            nextAction: "Decide whether this belongs this week.",
            owner: .blake,
            assignee: .blake,
            source: LifeTaskSource(
                sourceType: .manual,
                sourceID: "manual-library-card",
                displayName: "Manual capture"
            ),
            confidence: 1.0,
            createdAt: offset(now, minutes: -10),
            updatedAt: offset(now, minutes: -10)
        )
    }

    private static func uuid(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Invalid LifeOps fixture UUID: \(value)")
        }
        return uuid
    }

    private static func offset(_ date: Date, days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func offset(_ date: Date, hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: date) ?? date
    }

    private static func offset(_ date: Date, minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: date) ?? date
    }

    private static func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .day, for: date)?.end.addingTimeInterval(-1) ?? date
    }
}
