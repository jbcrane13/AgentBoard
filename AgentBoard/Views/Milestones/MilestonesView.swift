import SwiftUI

// MARK: - Milestone Draft

struct MilestoneDraft {
    var title: String = ""
    var description: String = ""
    var dueDate: Date?
    var hasDueDate: Bool = false

    /// ISO 8601 date string for the GitHub API, or nil if no due date.
    var dueDateISO: String? {
        guard hasDueDate, let dueDate else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: dueDate)
    }

    static func from(_ milestone: GitHubMilestone) -> MilestoneDraft {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let date = milestone.dueOn.flatMap { isoFormatter.date(from: $0) }
        return MilestoneDraft(
            title: milestone.title,
            description: milestone.description ?? "",
            dueDate: date ?? Date(),
            hasDueDate: date != nil
        )
    }
}

// MARK: - Project Identifier (for picker)

private struct ProjectRef: Identifiable, Hashable {
    let owner: String
    let repo: String
    let displayName: String
    var id: String {
        "\(owner)/\(repo)"
    }
}

// MARK: - View Model

@Observable
@MainActor
final class MilestonesViewModel {
    struct ProjectMilestoneGroup: Identifiable {
        let id: String
        let projectName: String
        let owner: String
        let repo: String
        let milestones: [GitHubMilestone]
        let error: String?
    }

    var groups: [ProjectMilestoneGroup] = []
    var isLoading = false
    var operationError: String?

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
                            owner: owner, repo: repo,
                            milestones: milestones, error: nil
                        )
                    } catch {
                        return ProjectMilestoneGroup(
                            id: projectName, projectName: projectName,
                            owner: owner, repo: repo,
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

    func createMilestone(owner: String, repo: String, token: String, draft: MilestoneDraft) async throws {
        try await run {
            _ = try await service.createMilestone(
                owner: owner, repo: repo, token: token,
                title: draft.title, description: draft.description.isEmpty ? nil : draft.description,
                dueOn: draft.dueDateISO
            )
        }
    }

    func updateMilestone(owner: String, repo: String, token: String, number: Int, draft: MilestoneDraft) async throws {
        try await run {
            _ = try await service.updateMilestone(
                owner: owner, repo: repo, token: token,
                number: number, title: draft.title,
                description: draft.description.isEmpty ? nil : draft.description,
                dueOn: draft.dueDateISO, state: nil
            )
        }
    }

    func toggleMilestoneState(owner: String, repo: String, token: String, milestone: GitHubMilestone) async throws {
        let newState = milestone.isOpen ? "closed" : "open"
        try await run {
            _ = try await service.updateMilestone(
                owner: owner, repo: repo, token: token,
                number: milestone.number, title: nil, description: nil, dueOn: nil, state: newState
            )
        }
    }

    func deleteMilestone(owner: String, repo: String, token: String, number: Int) async throws {
        try await run {
            try await service.deleteMilestone(owner: owner, repo: repo, token: token, number: number)
        }
    }

    private func run(_ operation: () async throws -> Void) async throws {
        operationError = nil
        do { try await operation() } catch { operationError = error.localizedDescription
            throw error
        }
    }
}

// MARK: - Milestones View

struct MilestonesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MilestonesViewModel()
    @State private var showingCreateSheet = false
    @State private var createDraft = MilestoneDraft()
    @State private var createProjectRef: ProjectRef?
    @State private var editingMilestone: EditingContext?
    @State private var editDraft = MilestoneDraft()
    @State private var confirmingDelete: DeleteContext?

    private struct EditingContext: Identifiable {
        let id = UUID()
        let milestone: GitHubMilestone
        let owner: String
        let repo: String
    }

    private struct DeleteContext: Identifiable {
        let id = UUID()
        let milestone: GitHubMilestone
        let owner: String
        let repo: String
    }

    private var configuredProjects: [ProjectRef] {
        appState.appConfig.projects.compactMap { project in
            guard let owner = project.githubOwner, !owner.isEmpty,
                  let repo = project.githubRepo, !repo.isEmpty else { return nil }
            let name = URL(fileURLWithPath: project.path).lastPathComponent
            return ProjectRef(owner: owner, repo: repo, displayName: name)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = viewModel.operationError {
                errorBanner(error)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
        .task { await viewModel.load(appConfig: appState.appConfig) }
        .sheet(isPresented: $showingCreateSheet) {
            MilestoneEditorSheet(
                title: "New Milestone",
                draft: $createDraft,
                projects: configuredProjects,
                selectedProject: $createProjectRef,
                showProjectPicker: configuredProjects.count > 1,
                onCancel: { showingCreateSheet = false },
                onSave: { createNewMilestone() }
            )
            .frame(minWidth: 420, minHeight: 340)
        }
        .sheet(item: $editingMilestone) { context in
            MilestoneEditorSheet(
                title: "Edit Milestone #\(context.milestone.number)",
                draft: $editDraft,
                projects: configuredProjects,
                selectedProject: .constant(nil),
                showProjectPicker: false,
                onCancel: { editingMilestone = nil },
                onSave: { updateExistingMilestone(context: context) }
            )
            .frame(minWidth: 420, minHeight: 340)
            .onAppear {
                editDraft = MilestoneDraft.from(context.milestone)
            }
        }
        .confirmationDialog(
            "Delete Milestone",
            isPresented: Binding(
                get: { confirmingDelete != nil },
                set: { if !$0 { confirmingDelete = nil } }
            ),
            presenting: confirmingDelete
        ) { context in
            Button("Delete", role: .destructive) {
                deleteMilestone(context: context)
            }
        } message: { context in
            Text(
                "Delete \"\(context.milestone.title)\"? This cannot be undone. Issues in this milestone will not be deleted."
            )
        }
        .accessibilityIdentifier("screen_milestones")
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Milestones")
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Button {
                createDraft = MilestoneDraft()
                createProjectRef = configuredProjects.first
                showingCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(configuredProjects.isEmpty)
            .accessibilityIdentifier("milestones_button_create")

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

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
            Text(message)
                .font(.system(size: 12))
            Spacer()
            Button {
                viewModel.operationError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("milestones_button_dismiss_error")
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityIdentifier("milestones_error_banner")
    }

    // MARK: - Content

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
                            .contextMenu {
                                Button {
                                    editingMilestone = EditingContext(
                                        milestone: milestone, owner: group.owner, repo: group.repo
                                    )
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .accessibilityIdentifier("milestones_context_edit_\(milestone.number)")

                                Button {
                                    toggleState(milestone: milestone, owner: group.owner, repo: group.repo)
                                } label: {
                                    Label(
                                        milestone.isOpen ? "Close" : "Reopen",
                                        systemImage: milestone.isOpen ? "checkmark.circle" : "arrow.uturn.left"
                                    )
                                }
                                .accessibilityIdentifier("milestones_context_toggle_\(milestone.number)")

                                Divider()

                                Button(role: .destructive) {
                                    confirmingDelete = DeleteContext(
                                        milestone: milestone, owner: group.owner, repo: group.repo
                                    )
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("milestones_context_delete_\(milestone.number)")
                            }
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

    // MARK: - Actions

    private func createNewMilestone() {
        guard let ref = createProjectRef, let token = appState.appConfig.githubToken else { return }
        showingCreateSheet = false
        runAndReload { try await viewModel.createMilestone(
            owner: ref.owner,
            repo: ref.repo,
            token: token,
            draft: createDraft
        ) }
    }

    private func updateExistingMilestone(context: EditingContext) {
        guard let token = appState.appConfig.githubToken else { return }
        editingMilestone = nil
        runAndReload {
            try await viewModel.updateMilestone(
                owner: context.owner, repo: context.repo,
                token: token, number: context.milestone.number, draft: editDraft
            )
        }
    }

    private func toggleState(milestone: GitHubMilestone, owner: String, repo: String) {
        guard let token = appState.appConfig.githubToken else { return }
        runAndReload { try await viewModel.toggleMilestoneState(
            owner: owner,
            repo: repo,
            token: token,
            milestone: milestone
        ) }
    }

    private func deleteMilestone(context: DeleteContext) {
        guard let token = appState.appConfig.githubToken else { return }
        runAndReload {
            try await viewModel.deleteMilestone(
                owner: context.owner,
                repo: context.repo,
                token: token,
                number: context.milestone.number
            )
        }
    }

    private func runAndReload(_ operation: @escaping () async throws -> Void) {
        Task<Void, Never> {
            try? await operation()
            await viewModel.load(appConfig: appState.appConfig)
        }
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

// MARK: - Milestone Editor Sheet

private struct MilestoneEditorSheet: View {
    let title: String
    @Binding var draft: MilestoneDraft
    let projects: [ProjectRef]
    @Binding var selectedProject: ProjectRef?
    let showProjectPicker: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding(16)
            .overlay(alignment: .bottom) {
                Divider()
            }

            Form {
                if showProjectPicker {
                    Picker("Project", selection: $selectedProject) {
                        ForEach(projects) { project in
                            Text(project.displayName).tag(Optional(project))
                        }
                    }
                    .accessibilityIdentifier("milestones_picker_project")
                }

                TextField("Title", text: $draft.title)
                    .accessibilityIdentifier("milestones_textfield_title")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $draft.description)
                        .accessibilityIdentifier("milestones_textfield_description")
                        .frame(minHeight: 80)
                }
                .padding(.vertical, 4)

                Toggle("Due Date", isOn: $draft.hasDueDate)
                    .accessibilityIdentifier("milestones_toggle_duedate")

                if draft.hasDueDate {
                    DatePicker(
                        "Due",
                        selection: Binding(
                            get: { draft.dueDate ?? Date() },
                            set: { draft.dueDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("milestones_datepicker_due")
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .accessibilityIdentifier("milestones_button_cancel")
                Button("Save", action: onSave)
                    .accessibilityIdentifier("milestones_button_save")
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }
}
