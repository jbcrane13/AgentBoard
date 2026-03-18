import SwiftUI

// MARK: - View Model

@Observable
@MainActor
final class MilestonesViewModel {
    struct ProjectMilestoneGroup: Identifiable {
        let id: String
        let projectName: String
        let milestones: [GitHubMilestone]
        let error: String?
    }

    var groups: [ProjectMilestoneGroup] = []
    var isLoading = false

    private let service = GitHubIssuesService()

    func load(appConfig: AppConfig) async {
        guard let token = appConfig.githubToken, !token.isEmpty else { return }

        let configuredProjects = appConfig.projects.filter {
            !($0.githubOwner ?? "").isEmpty && !($0.githubRepo ?? "").isEmpty
        }
        guard !configuredProjects.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let service = self.service
        var results: [ProjectMilestoneGroup] = []

        await withTaskGroup(of: ProjectMilestoneGroup.self) { group in
            for project in configuredProjects {
                guard let owner = project.githubOwner, !owner.isEmpty,
                      let repo = project.githubRepo, !repo.isEmpty else { continue }
                let projectName = URL(fileURLWithPath: project.path).lastPathComponent

                group.addTask {
                    do {
                        let milestones = try await service.fetchMilestones(
                            owner: owner, repo: repo, token: token
                        )
                        return ProjectMilestoneGroup(
                            id: projectName, projectName: projectName,
                            milestones: milestones, error: nil
                        )
                    } catch {
                        return ProjectMilestoneGroup(
                            id: projectName, projectName: projectName,
                            milestones: [], error: error.localizedDescription
                        )
                    }
                }
            }
            for await result in group {
                results.append(result)
            }
        }

        groups = results.sorted { $0.projectName < $1.projectName }
    }
}

// MARK: - Milestones View

struct MilestonesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MilestonesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
        .task { await viewModel.load(appConfig: appState.appConfig) }
        .accessibilityIdentifier("screen_milestones")
    }

    private var header: some View {
        HStack {
            Text("Milestones")
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Button {
                Task { await viewModel.load(appConfig: appState.appConfig) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("milestones_button_refresh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("milestones_progress_loading")
        } else if viewModel.groups.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                    ForEach(viewModel.groups) { group in
                        projectGroup(group)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    private func projectGroup(_ group: MilestonesViewModel.ProjectMilestoneGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.projectName)
                .font(.system(size: 14, weight: .bold))

            if let error = group.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 12))
                }
                .foregroundStyle(.orange)
                .padding(10)
                .cardStyle()
                .accessibilityIdentifier("milestones_error_\(group.id)")
            } else if group.milestones.isEmpty {
                Text("No open milestones")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .cardStyle()
            } else {
                VStack(spacing: 8) {
                    ForEach(group.milestones) { milestone in
                        MilestoneProgressRow(milestone: milestone)
                    }
                }
            }
        }
        .accessibilityIdentifier("milestones_project_\(group.id)")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No milestones found")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Configure GitHub owner/repo in Settings to load milestones.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("milestones_empty_state")
    }
}

// MARK: - Milestone Progress Row

private struct MilestoneProgressRow: View {
    let milestone: GitHubMilestone

    private var dueDateLabel: String? {
        guard let dueOn = milestone.dueOn else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        guard let date = isoFormatter.date(from: dueOn) else { return nil }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return "Due \(display.string(from: date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(milestone.title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                if let due = dueDateLabel {
                    Text(due)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Text("\(milestone.closedIssues)/\(milestone.totalIssues) done")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("milestones_count_\(milestone.number)")
            }

            ProgressView(value: milestone.progress)
                .tint(progressTint)
                .accessibilityIdentifier("milestones_progress_\(milestone.number)")
        }
        .padding(12)
        .cardStyle()
        .accessibilityIdentifier("milestones_row_\(milestone.number)")
    }

    private var progressTint: Color {
        if milestone.progress >= 1.0 { return .green }
        if milestone.progress >= 0.5 { return .blue }
        return .accentColor
    }
}
