import AgentBoardCore
import SwiftUI

struct TaskDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let task: KanbanTask

    @State private var comments: [KanbanComment] = []
    @State private var runs: [KanbanRun] = []
    @State private var parents: [String] = []
    @State private var children: [String] = []
    @State private var isLoadingDetail = false
    @State private var isCommenting = false
    @State private var commentText = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        taskHeader
                        if !task.bodyOrEmpty.isEmpty { bodySection }
                        runHistorySection
                        commentsSection
                        dependencySection
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Task Details")
            .agentBoardNavigationBarTitleInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityIdentifier("task_detail_button_close")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { presentComment() } label: { Label("Add Comment", systemImage: "bubble.left") }
                            .accessibilityIdentifier("task_detail_button_add_comment")
                        Divider()
                        Button { complete() } label: { Label("Complete", systemImage: "checkmark") }
                            .accessibilityIdentifier("task_detail_button_complete")
                        Button { block() } label: { Label("Block", systemImage: "hand.raised") }
                            .accessibilityIdentifier("task_detail_button_block")
                        Divider()
                        Button(role: .destructive) { archive() } label: { Label("Archive", systemImage: "archivebox") }
                            .accessibilityIdentifier("task_detail_button_archive")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(AppButtonStyle(isAccent: false))
                    .accessibilityIdentifier("task_detail_menu_actions")
                }
            }
            .sheet(isPresented: $isCommenting) {
                commentSheet
                    .presentationDetents([.medium])
            }
            .task { await loadDetails() }
        }
        .accessibilityIdentifier("screen_task_detail")
    }

    // MARK: - Sections

    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.displayPriority)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accentCyan)
                    if let tenant = task.tenant {
                        Text(tenant)
                            .font(.caption2.monospaced())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
                Text(task.status.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .insetSurface(cornerRadius: 12, depth: 3)
            }

            Text(task.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Image(systemName: "person.fill").font(.system(size: 10))
                Text(task.displayAssignee).font(.caption.weight(.bold))
            }
            .foregroundStyle(AppTheme.accentOrange)
        }
        .padding(24)
        .cardSurface(cornerRadius: 24, elevation: 8)
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BODY")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(AppTheme.textSecondary)
            Text(task.bodyOrEmpty)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .padding(24)
        .cardSurface(cornerRadius: 24, elevation: 8)
    }

    private var runHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RUN HISTORY")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(AppTheme.textSecondary)

            if runs.isEmpty {
                Text("No runs yet")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                ForEach(runs) { run in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(runOutcomeColor(run.outcome))
                                .frame(width: 8, height: 8)
                            Text(run.profile ?? "unknown")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(run.outcome?.rawValue.replacingOccurrences(of: "_", with: " ") ?? run.status)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(runOutcomeColor(run.outcome))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .insetSurface(cornerRadius: 8, depth: 2)
                        }

                        if let summary = run.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(3)
                        }

                        HStack {
                            if let duration = run.duration {
                                Text(String(format: "%.0fs", duration))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            Spacer()
                            Text(run.startedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    .padding(16)
                    .cardSurface(cornerRadius: 18, elevation: 4)
                }
            }
        }
        .padding(24)
        .cardSurface(cornerRadius: 24, elevation: 8)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("COMMENTS")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(comments.count)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(AppTheme.textTertiary)
            }

            if comments.isEmpty {
                Text("No comments yet")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(comment.author)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.accentCyan)
                            Spacer()
                            Text(comment.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Text(comment.body)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .cardSurface(cornerRadius: 18, elevation: 4)
                }
            }
        }
        .padding(24)
        .cardSurface(cornerRadius: 24, elevation: 8)
    }

    private var dependencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEPENDENCIES")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(AppTheme.textSecondary)

            if !parents.isEmpty {
                HStack(spacing: 8) {
                    Text("Blocks on:")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(parents, id: \.self) { parentID in
                        Text(parentID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(AppTheme.accentOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .insetSurface(cornerRadius: 8, depth: 2)
                    }
                }
            }

            if !children.isEmpty {
                HStack(spacing: 8) {
                    Text("Blocking:")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(children, id: \.self) { childID in
                        Text(childID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(AppTheme.accentCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .insetSurface(cornerRadius: 8, depth: 2)
                    }
                }
            }

            if parents.isEmpty && children.isEmpty {
                Text("No dependencies")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(24)
        .cardSurface(cornerRadius: 24, elevation: 8)
    }

    // MARK: - Actions

    private var commentSheet: some View {
        NavigationStack {
            Form {
                TextField("Comment", text: $commentText, axis: .vertical)
                    .lineLimit(3 ... 8)
                    .accessibilityIdentifier("task_detail_textfield_comment")
            }
            .formStyle(.grouped)
            .navigationTitle("Add Comment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isCommenting = false }
                        .accessibilityIdentifier("task_detail_button_cancel_comment")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            await appModel.agentsStore.commentOnTask(id: task.id, body: commentText)
                            await loadDetails()
                        }
                        commentText = ""
                        isCommenting = false
                    }
                    .disabled(commentText.trimmedOrNil == nil)
                    .accessibilityIdentifier("task_detail_button_post_comment")
                }
            }
        }
    }

    private func presentComment() {
        commentText = ""
        isCommenting = true
    }

    private func complete() {
        Task {
            await appModel.agentsStore.completeTask(id: task.id, summary: "Completed from AgentBoard")
            await loadDetails()
            dismiss()
        }
    }

    private func block() {
        Task {
            await appModel.agentsStore.blockTask(id: task.id, reason: "Blocked from AgentBoard UI")
            await loadDetails()
            dismiss()
        }
    }

    private func archive() {
        Task {
            await appModel.agentsStore.archiveTask(id: task.id)
            dismiss()
        }
    }

    private func loadDetails() async {
        isLoadingDetail = true
        do {
            async let loadedComments = appModel.agentsStore.fetchComments(for: task.id)
            async let loadedRuns = appModel.agentsStore.fetchRuns(for: task.id)
            async let loadedLinks = appModel.agentsStore.fetchLinks(for: task.id)

            comments = try await loadedComments
            runs = try await loadedRuns
            let links = try await loadedLinks
            parents = links.parents
            children = links.children
        } catch {
            // Detail load failures are non-fatal — section just shows empty state
        }
        isLoadingDetail = false
    }

    // MARK: - Helpers

    private func runOutcomeColor(_ outcome: KanbanRunOutcome?) -> Color {
        switch outcome {
        case .completed: AppTheme.statusSuccess
        case .blocked: AppTheme.accentOrange
        case .crashed, .timedOut: .red
        case .spawnFailed, .gaveUp: AppTheme.accentOrange
        case .reclaimed: AppTheme.statusIdle
        case nil: AppTheme.textSecondary
        }
    }
}

private extension KanbanTask {
    var bodyOrEmpty: String {
        body ?? ""
    }
}
