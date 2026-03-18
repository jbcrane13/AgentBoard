import SwiftUI

struct AllProjectsBoardView: View {
    @Environment(AppState.self) private var appState

    @State private var statusFilter: String = "all"
    @State private var agentFilter: String = "all"
    @State private var priorityFilter: Int = -1
    @State private var selectedIssue: CrossRepoIssue?

    private let statusOptions: [(label: String, value: String)] = [
        ("All Statuses", "all"),
        ("Open", "open"),
        ("In Progress", "in-progress"),
        ("Blocked", "blocked"),
        ("Done", "done")
    ]
    private let priorityOptions: [(label: String, value: Int)] = [
        ("All Priorities", -1),
        ("P0 Critical", 0),
        ("P1 High", 1),
        ("P2 Medium", 2),
        ("P3 Low", 3),
        ("P4 Backlog", 4)
    ]

    private var knownAgents: [String] {
        var agents = Set<String>()
        for issue in appState.allProjectIssues {
            if let agent = issue.assignedAgent { agents.insert(agent) }
        }
        return agents.sorted()
    }

    private var filtered: [CrossRepoIssue] {
        appState.allProjectIssues.filter { issue in
            if statusFilter != "all" {
                let matchesStatus: Bool
                switch statusFilter {
                case "open": matchesStatus = issue.bead.status == .open
                case "in-progress": matchesStatus = issue.bead.status == .inProgress
                case "blocked": matchesStatus = issue.bead.status == .blocked
                case "done": matchesStatus = issue.bead.status == .done
                default: matchesStatus = true
                }
                if !matchesStatus { return false }
            }
            if agentFilter != "all" {
                let agent = issue.assignedAgent ?? ""
                if agentFilter == "unassigned" {
                    if !agent.isEmpty { return false }
                } else {
                    if agent != agentFilter { return false }
                }
            }
            if priorityFilter >= 0 {
                if issue.bead.priority != priorityFilter { return false }
            }
            return true
        }
    }

    private var groupedByProject: [(projectName: String, issues: [CrossRepoIssue])] {
        let sorted = filtered.sorted { lhs, rhs in
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
            filterBar

            if !appState.allProjectLoadErrors.isEmpty {
                errorBanner
            }

            if appState.isLoadingAllProjects && appState.allProjectIssues.isEmpty {
                loadingState
            } else if appState.allProjectIssues.isEmpty {
                emptyState
            } else if filtered.isEmpty {
                noResultsState
            } else {
                issueList
            }
        }
        .accessibilityIdentifier("screen_allProjects")
        .sheet(item: $selectedIssue) { issue in
            CrossRepoIssueDetailSheet(issue: issue)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Picker("Status", selection: $statusFilter) {
                    ForEach(statusOptions, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("allProjects_filter_status")

                Picker("Priority", selection: $priorityFilter) {
                    ForEach(priorityOptions, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("allProjects_filter_priority")

                Picker("Agent", selection: $agentFilter) {
                    Text("All Agents").tag("all")
                    Text("Unassigned").tag("unassigned")
                    ForEach(knownAgents, id: \.self) { agent in
                        Text(agent).tag(agent)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("allProjects_filter_agent")

                Spacer()

                Button {
                    Task { await appState.refreshAllProjectIssues() }
                } label: {
                    Image(systemName: appState.isLoadingAllProjects ? "arrow.clockwise" : "arrow.clockwise")
                        .font(.system(size: 12))
                        .rotationEffect(.degrees(appState.isLoadingAllProjects ? 360 : 0))
                        .animation(
                            appState.isLoadingAllProjects ? .linear(duration: 1)
                                .repeatForever(autoreverses: false) : .default,
                            value: appState.isLoadingAllProjects
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("allProjects_button_refresh")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppTheme.appBackground)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Error Banner

    private var errorBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text("Failed to load: \(appState.allProjectLoadErrors.joined(separator: ", "))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
        .accessibilityIdentifier("allProjects_error_banner")
    }

    // MARK: - Issue List

    private var issueList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedByProject, id: \.projectName) { group in
                    Section {
                        ForEach(group.issues) { issue in
                            Button {
                                selectedIssue = issue
                            } label: {
                                AllProjectsIssueRow(issue: issue)
                                    .padding(.horizontal, 16)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("allProjects_row_\(issue.id)")
                        }
                    } header: {
                        projectHeader(group.projectName, count: group.issues.count)
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
            Text("Loading issues from all projects…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No issues match the current filters.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

// MARK: - Issue Row

struct AllProjectsIssueRow: View {
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
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    projectBadge
                    if let agent = issue.assignedAgent, !agent.isEmpty {
                        Text(agent)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
    }

    private var priorityDot: some View {
        Circle()
            .fill(priorityColor(for: issue.bead.priority))
            .frame(width: 8, height: 8)
            .padding(.top, 4)
    }

    private var projectBadge: some View {
        Text(issue.projectName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(Color.purple)
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

// MARK: - Detail Sheet

struct CrossRepoIssueDetailSheet: View {
    let issue: CrossRepoIssue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(issue.bead.id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        AllProjectsIssueRow.staticProjectBadge(issue.projectName)
                    }
                    Text(issue.bead.title)
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("crossRepoDetail_button_close")
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata
                    HStack(spacing: 12) {
                        labelPill(issue.bead.status.rawValue, color: statusColor)
                        labelPill(issue.bead.kind.rawValue.capitalized, color: issue.bead.kind.color)
                        labelPill("P\(issue.bead.priority)", color: priorityColor(for: issue.bead.priority))
                        if let agent = issue.assignedAgent {
                            labelPill(agent, color: .indigo)
                        }
                    }

                    // Labels
                    if !issue.bead.labels.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(issue.bead.labels, id: \.self) { label in
                                Text(label)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Body
                    if let body = issue.bead.body, !body.isEmpty {
                        Text(body)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                    }

                    // Repo link hint
                    Text("\(issue.owner)/\(issue.repo)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 400)
        .background(AppTheme.appBackground)
    }

    private var statusColor: Color {
        switch issue.bead.status {
        case .open: .blue
        case .inProgress: .orange
        case .blocked: .red
        case .done: .green
        }
    }

    private func labelPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Make the project badge reusable from the detail sheet
extension AllProjectsIssueRow {
    static func staticProjectBadge(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(Color.purple)
    }
}

// MARK: - Flow Layout (simple wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? 300).size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, place) in result.placements.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + place.x, y: bounds.minY + place.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var placements: [(x: CGFloat, y: CGFloat)]
    }

    private func layout(subviews: Subviews, width: CGFloat) -> LayoutResult {
        var placements: [(x: CGFloat, y: CGFloat)] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            placements.append((x, y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return LayoutResult(size: CGSize(width: width, height: y + rowHeight), placements: placements)
    }
}
