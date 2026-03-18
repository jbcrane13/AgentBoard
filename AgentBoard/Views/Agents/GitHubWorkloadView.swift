import SwiftUI

// MARK: - GitHub Workload Section

/// A section showing open GitHub issues grouped by assigned agent.
/// Reads from AppState.allProjectIssues — no extra API calls needed.
struct GitHubWorkloadSection: View {
    @Environment(AppState.self) private var appState

    private var openIssues: [CrossRepoIssue] {
        appState.allProjectIssues.filter { $0.bead.status != .done }
    }

    private struct AgentGroup {
        let agentID: String
        let displayName: String
        let issues: [CrossRepoIssue]
    }

    private var agentGroups: [AgentGroup] {
        let namedAgents = AgentDefinition.knownAgents.filter { !$0.id.isEmpty }
        let namedIDs = Set(namedAgents.map { $0.id.lowercased() })

        var groups = namedAgents.map { agent -> AgentGroup in
            let agentIssues = openIssues.filter {
                ($0.assignedAgent ?? "").lowercased() == agent.id.lowercased()
            }
            return AgentGroup(agentID: agent.id, displayName: agent.displayName, issues: agentIssues)
        }

        let unassigned = openIssues.filter {
            let agent = ($0.assignedAgent ?? "").lowercased()
            return agent.isEmpty || !namedIDs.contains(agent)
        }
        groups.append(AgentGroup(agentID: "", displayName: "📋 Unassigned", issues: unassigned))

        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GitHub Workload")
                .font(.system(size: 18, weight: .semibold))

            if appState.allProjectIssues.isEmpty {
                HStack {
                    Spacer()
                    Text("No GitHub issues loaded — configure GitHub in Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("workload_empty_state")
                    Spacer()
                }
                .padding(.vertical, 20)
                .cardStyle()
            } else {
                VStack(spacing: 10) {
                    ForEach(agentGroups, id: \.agentID) { group in
                        AgentWorkloadCard(
                            displayName: group.displayName,
                            agentID: group.agentID,
                            issues: group.issues
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("section_githubWorkload")
    }
}

// MARK: - Agent Workload Card

private struct AgentWorkloadCard: View {
    let displayName: String
    let agentID: String
    let issues: [CrossRepoIssue]

    @State private var isExpanded = true

    private var isOverloaded: Bool {
        issues.count > 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if isExpanded {
                Divider()
                issueList
            }
        }
        .cardStyle()
        .accessibilityIdentifier("workload_card_\(agentID.isEmpty ? "unassigned" : agentID)")
    }

    private var headerRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text(displayName)
                    .font(.system(size: 14, weight: .semibold))

                Text("\(issues.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.06), in: Capsule())

                if isOverloaded {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("Overloaded")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workload_header_\(agentID.isEmpty ? "unassigned" : agentID)")
    }

    @ViewBuilder
    private var issueList: some View {
        if issues.isEmpty {
            Text("No open issues")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 0) {
                let visible = Array(issues.prefix(20))
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, issue in
                    WorkloadIssueRow(issue: issue)
                    if index < visible.count - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
                if issues.count > 20 {
                    Text("+ \(issues.count - 20) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
        }
    }
}

// MARK: - Workload Issue Row

private struct WorkloadIssueRow: View {
    let issue: CrossRepoIssue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(priorityColor(for: issue.bead.priority))
                .frame(width: 7, height: 7)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(issue.bead.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .accessibilityIdentifier("workload_issue_title_\(issue.id)")

                HStack(spacing: 6) {
                    Text(issue.projectName)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(.blue)

                    Text("P\(issue.bead.priority)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            priorityColor(for: issue.bead.priority).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 3)
                        )
                        .foregroundStyle(priorityColor(for: issue.bead.priority))

                    Text(issue.bead.status.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            statusColor(issue.bead.status).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 3)
                        )
                        .foregroundStyle(statusColor(issue.bead.status))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func statusColor(_ status: BeadStatus) -> Color {
        switch status {
        case .open: .blue
        case .inProgress: .orange
        case .blocked: .red
        case .done: .green
        }
    }
}
