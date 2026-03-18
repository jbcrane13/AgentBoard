import SwiftUI

struct AllProjectsBoardView: View {
    @Environment(AppState.self) private var appState

    private var groupedByProject: [(projectName: String, issues: [CrossRepoIssue])] {
        let sorted = appState.allProjectIssues.sorted { lhs, rhs in
            if lhs.bead.priority != rhs.bead.priority { return lhs.bead.priority < rhs.bead.priority }
            return lhs.bead.updatedAt > rhs.bead.updatedAt
        }
        var seen: [String: [CrossRepoIssue]] = [:]
        var order: [String] = []
        for issue in sorted {
            if seen[issue.projectName] == nil { order.append(issue.projectName) }
            seen[issue.projectName, default: []].append(issue)
        }
        return order.map { name in (projectName: name, issues: seen[name] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.allProjectIssues.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedByProject, id: \.projectName) { group in
                            Section {
                                ForEach(group.issues) { issue in
                                    CrossRepoIssueRow(issue: issue)
                                        .padding(.horizontal, 16)
                                }
                            } header: {
                                projectHeader(group.projectName, count: group.issues.count)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .accessibilityIdentifier("screen_allProjects")
    }

    private func projectHeader(_ name: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 13, weight: .bold))
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No GitHub issues found across projects.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Configure GitHub owner/repo in Settings for each project.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("allProjects_empty_state")
    }
}

private struct CrossRepoIssueRow: View {
    let issue: CrossRepoIssue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            priorityDot
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(issue.bead.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    statusBadge
                    Spacer()
                    kindBadge
                }
                Text(issue.bead.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                if let agent = issue.assignedAgent, !agent.isEmpty {
                    Text(agent)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
        .accessibilityIdentifier("allProjects_row_\(issue.id)")
    }

    private var priorityDot: some View {
        Circle()
            .fill(priorityColor(for: issue.bead.priority))
            .frame(width: 8, height: 8)
            .padding(.top, 4)
    }

    private var statusBadge: some View {
        Text(issue.bead.status.rawValue)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch issue.bead.status {
        case .open: .blue
        case .inProgress: .orange
        case .blocked: .red
        case .done: .green
        }
    }

    private var kindBadge: some View {
        Text(issue.bead.kind.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(issue.bead.kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(issue.bead.kind.color)
    }
}
