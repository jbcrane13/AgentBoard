import AgentBoardCore
import SwiftUI

enum LifeOpsScreenMode {
    case dashboard
    case compact
}

struct LifeOpsScreen: View {
    let store: LifeOpsStore
    let mode: LifeOpsScreenMode

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesCompactLayout: Bool {
        mode == .compact || horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            NeuBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if usesCompactLayout {
                        compactContent
                    } else {
                        dashboardContent
                    }
                }
                .padding(usesCompactLayout ? 16 : 24)
                .padding(.bottom, 32)
            }
        }
        .agentBoardNavigationBarHidden(true)
        .accessibilityIdentifier("screen_lifeops")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    AgentBoardEyebrow(text: "LIFEOPS")
                    Text("LifeOps")
                        .font(.system(size: usesCompactLayout ? 34 : 32, weight: .bold))
                        .foregroundStyle(NeuPalette.textPrimary)
                    Text("Updated \(store.lastRefreshAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(NeuPalette.textSecondary)
                }

                Spacer()

                if !usesCompactLayout {
                    summaryStrip
                }
            }

            LifeOpsQuickCaptureView { title in
                store.createQuickTask(title: title)
            }
        }
        .accessibilityIdentifier("lifeops.header")
    }

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            metric("Now", count: store.nowTasks.count, color: NeuPalette.accentOrange)
            metric("Approvals", count: store.pendingApprovals.count, color: NeuPalette.accentCyan)
            metric("Family", count: store.familyTasks.count, color: NeuPalette.accentGreen)
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            taskSection(
                title: "Now",
                accessibilityID: "lifeops.section.now",
                tasks: Array(store.nowTasks.prefix(3)),
                emptyText: "Clear for now."
            )
            taskSection(
                title: "Today",
                accessibilityID: "lifeops.section.today",
                tasks: store.todayTasks,
                emptyText: "No timed items today."
            )
            approvalSection
            familySection
            jobSearchSection
            taskSection(
                title: "Inbox",
                accessibilityID: "lifeops.section.inbox",
                tasks: store.inboxTasks,
                emptyText: "Inbox is empty."
            )
            taskSection(
                title: "Waiting On",
                accessibilityID: "lifeops.section.waiting",
                tasks: store.waitingTasks,
                emptyText: "No blockers tracked."
            )
        }
    }

    private var dashboardContent: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 26) {
                taskSection(
                    title: "Now",
                    accessibilityID: "lifeops.section.now",
                    tasks: Array(store.nowTasks.prefix(3)),
                    emptyText: "Clear for now."
                )
                taskSection(
                    title: "Today",
                    accessibilityID: "lifeops.section.today",
                    tasks: store.todayTasks,
                    emptyText: "No timed items today."
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 26) {
                taskSection(
                    title: "Inbox",
                    accessibilityID: "lifeops.section.inbox",
                    tasks: store.inboxTasks,
                    emptyText: "Inbox is empty."
                )
                approvalSection
                taskSection(
                    title: "Waiting On",
                    accessibilityID: "lifeops.section.waiting",
                    tasks: store.waitingTasks,
                    emptyText: "No blockers tracked."
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 26) {
                jobSearchSection
                familySection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func taskSection(
        title: String,
        accessibilityID: String,
        tasks: [LifeTask],
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title, count: tasks.count)

            if tasks.isEmpty {
                emptyState(emptyText)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(tasks) { task in
                        LifeOpsTaskRow(task: task)
                    }
                }
            }
        }
        .accessibilityIdentifier(accessibilityID)
    }

    private var approvalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Needs Approval", count: store.pendingApprovals.count)

            if store.pendingApprovals.isEmpty {
                emptyState("No pending approvals.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(store.pendingApprovals) { approval in
                        approvalRow(approval)
                    }
                }
            }
        }
        .accessibilityIdentifier("lifeops.section.approvals")
    }

    private var jobSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Job Search", count: store.jobFollowUpsDue.count)

            if store.jobFollowUpsDue.isEmpty {
                emptyState("No follow-ups due.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(store.jobFollowUpsDue) { opportunity in
                        jobRow(opportunity)
                    }
                }
            }
        }
        .accessibilityIdentifier("lifeops.section.jobSearch")
    }

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Family", count: store.familyTasks.count)

            if store.familyTasks.isEmpty && store.familyRequests.isEmpty {
                emptyState("No family items.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(store.familyTasks) { task in
                        LifeOpsTaskRow(task: task)
                    }

                    ForEach(store.familyRequests) { request in
                        familyRequestRow(request)
                    }
                }
            }
        }
        .accessibilityIdentifier("lifeops.section.family")
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeuPalette.textSecondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeuPalette.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NeuPalette.inset)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Spacer()
        }
    }

    private func metric(_ label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(NeuPalette.textSecondary)
        }
        .frame(width: 78, alignment: .leading)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(NeuPalette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(NeuPalette.surface.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func approvalRow(_ approval: ApprovalAction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: approvalIcon(for: approval.actionType))
                .font(.body.weight(.semibold))
                .foregroundStyle(NeuPalette.accentCyan)
                .frame(width: 28, height: 28)
                .background(NeuPalette.accentCyan.opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(approval.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NeuPalette.textPrimary)
                    Spacer()
                    Text(approval.riskLevel.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(approvalRiskColor(approval.riskLevel))
                }

                Text(approval.summary)
                    .font(.caption)
                    .foregroundStyle(NeuPalette.textSecondary)
                    .lineLimit(2)

                Text(approval.proposedPayloadPreview)
                    .font(.caption2)
                    .foregroundStyle(NeuPalette.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(NeuPalette.accentCyan.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NeuPalette.accentCyan.opacity(0.28), lineWidth: 1)
        }
        .accessibilityIdentifier("lifeops.approval.row")
    }

    private func jobRow(_ opportunity: JobOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(opportunity.company)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeuPalette.textPrimary)
                Spacer()
                Text(opportunity.stage.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NeuPalette.accentOrange)
            }

            Text(opportunity.role)
                .font(.caption)
                .foregroundStyle(NeuPalette.textSecondary)

            if let nextFollowUpAt = opportunity.nextFollowUpAt {
                Label(nextFollowUpAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(NeuPalette.textTertiary)
            }
        }
        .padding(14)
        .background(NeuPalette.surface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NeuPalette.borderSoft, lineWidth: 1)
        }
        .accessibilityIdentifier("lifeops.job.row")
    }

    private func familyRequestRow(_ request: FamilyRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(request.requester.displayName) request", systemImage: "message.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NeuPalette.accentOrange)

            Text(request.rawText)
                .font(.subheadline)
                .foregroundStyle(NeuPalette.textPrimary)
                .lineLimit(2)

            Text(request.interpretedAction.title)
                .font(.caption2)
                .foregroundStyle(NeuPalette.textTertiary)
        }
        .padding(14)
        .background(NeuPalette.surface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NeuPalette.accentOrange.opacity(0.28), lineWidth: 1)
        }
        .accessibilityIdentifier("lifeops.familyRequest.row")
    }

    private func approvalIcon(for type: ApprovalActionType) -> String {
        switch type {
        case .sendEmail: "envelope.badge"
        case .sendMessage: "message.badge"
        case .createCalendarEvent: "calendar.badge.plus"
        case .applyToJob: "briefcase"
        case .archiveEmail: "archivebox"
        case .delegateTask: "person.crop.circle.badge.checkmark"
        case .other: "checkmark.seal"
        }
    }

    private func approvalRiskColor(_ riskLevel: ApprovalRiskLevel) -> Color {
        switch riskLevel {
        case .low: NeuPalette.accentGreen
        case .medium: NeuPalette.accentOrange
        case .high: NeuPalette.accentCoral
        }
    }
}
