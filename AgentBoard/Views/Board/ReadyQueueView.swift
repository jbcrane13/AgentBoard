import SwiftUI

struct ReadyQueueView: View {
    @Environment(AppState.self) private var appState
    @State private var claimingIssueID: String?
    @State private var selectedIssue: CrossRepoIssue?

    private let agentGroups: [(label: String, key: String)] = [
        ("Unassigned", ""),
        ("agent:daneel", "daneel"),
        ("agent:friend", "friend"),
        ("agent:quentin", "quentin")
    ]

    private var groupedIssues: [(label: String, issues: [CrossRepoIssue])] {
        let ready = appState.readyIssues
        var known: Set<String> = []
        var groups: [(label: String, issues: [CrossRepoIssue])] = []

        for (label, key) in agentGroups {
            let issues = ready.filter { issue in
                let agent = issue.assignedAgent ?? ""
                if key.isEmpty { return agent.isEmpty }
                return agent == key
            }
            if !issues.isEmpty {
                groups.append((label, issues))
            }
            known.insert(key)
        }

        // Catch any other agents not in the predefined list
        let otherAgents = Set(ready.compactMap { $0.assignedAgent }).subtracting(known)
        for agent in otherAgents.sorted() {
            let issues = ready.filter { ($0.assignedAgent ?? "") == agent }
            if !issues.isEmpty {
                groups.append(("agent:\(agent)", issues))
            }
        }

        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if appState.isLoadingAllProjects && appState.readyIssues.isEmpty {
                loadingState
            } else if appState.readyIssues.isEmpty {
                emptyState
            } else {
                issueList
            }
        }
        .accessibilityIdentifier("screen_readyQueue")
        .sheet(item: $selectedIssue) { issue in
            CrossRepoIssueDetailSheet(issue: issue)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("\(appState.readyIssues.count) ready")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await appState.refreshAllProjectIssues() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("ready_button_refresh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.appBackground)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Issue List

    private var issueList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedIssues, id: \.label) { group in
                    Section {
                        ForEach(group.issues) { issue in
                            ReadyQueueRow(
                                issue: issue,
                                isClaiming: claimingIssueID == issue.id,
                                onTap: { selectedIssue = issue },
                                onClaim: { await claim(issue) }
                            )
                            .padding(.horizontal, 16)
                            .accessibilityIdentifier("ready_row_\(issue.id)")
                        }
                    } header: {
                        groupHeader(group.label, count: group.issues.count)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Loading ready issues…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No ready issues across projects.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Issues with status:ready and no blockers appear here.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("ready_empty_state")
    }

    private func groupHeader(_ label: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.06), in: Capsule())
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.appBackground)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Claim Action

    private func claim(_ issue: CrossRepoIssue) async {
        claimingIssueID = issue.id
        await appState.claimIssue(issue)
        claimingIssueID = nil
    }
}

// MARK: - Ready Queue Row

private struct ReadyQueueRow: View {
    let issue: CrossRepoIssue
    let isClaiming: Bool
    let onTap: () -> Void
    let onClaim: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(priorityColor(for: issue.bead.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(issue.bead.id)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        priorityBadge
                        typeBadge
                        Spacer()
                        projectBadge
                    }
                    Text(issue.bead.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            claimButton
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
    }

    private var priorityBadge: some View {
        Text("P\(issue.bead.priority)")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(priorityColor(for: issue.bead.priority).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(priorityColor(for: issue.bead.priority))
    }

    private var typeBadge: some View {
        Text(issue.bead.kind.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(issue.bead.kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(issue.bead.kind.color)
    }

    private var projectBadge: some View {
        Text(issue.projectName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(Color.purple)
    }

    private var claimButton: some View {
        Button {
            Task { await onClaim() }
        } label: {
            if isClaiming {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 60)
            } else {
                Text("Claim")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(isClaiming)
        .accessibilityIdentifier("ready_row_claim_\(issue.id)")
    }
}
