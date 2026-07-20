import AgentBoardCore
import SwiftUI

struct LaunchSessionSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let task: KanbanTask?
    let workItem: WorkItem?

    @State private var selectedPreset: SessionLauncher.ExecutionPreset = .ralphLoop
    @State private var selectedAgent: SessionLauncher.AgentType = .claude
    @State private var customInstructions = ""
    @State private var repoName = ""
    @State private var isLaunching = false

    init(task: KanbanTask) {
        self.task = task
        workItem = nil
    }

    init(workItem: WorkItem) {
        task = nil
        self.workItem = workItem
    }

    private var displayTitle: String {
        task?.title ?? workItem?.title ?? "New Session"
    }

    private var displayRepoName: String {
        workItem?.repository.name ?? ""
    }

    private var displayFullRepo: String {
        workItem?.repository.fullName ?? ""
    }

    private var displayIssueNumber: Int {
        workItem?.issueNumber ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("LAUNCH SESSION")
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(AppTheme.textSecondary)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Task").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                Text(displayTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .insetSurface(cornerRadius: 12, depth: 4)
                            }

                            // If launched from a work item (GitHub issue), show the issue ref
                            if let workItem {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Issue").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                    Text(workItem.issueReference)
                                        .font(.subheadline.monospaced())
                                        .foregroundStyle(AppTheme.accentCyan)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Repository Folder").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                AppTextField(placeholder: "e.g. AgentBoard", text: $repoName)
                                    .accessibilityIdentifier("launchSession_textfield_repoName")
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Agent").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                ForEach(SessionLauncher.AgentType.allCases) { agent in
                                    Button {
                                        selectedAgent = agent
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: agent.icon)
                                                .frame(width: 24)
                                                .foregroundStyle(selectedAgent == agent ? AppTheme
                                                    .accentCyan : AppTheme.textSecondary)

                                            Text(agent.displayName)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.textPrimary)

                                            Spacer()

                                            if selectedAgent == agent {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(AppTheme.accentCyan)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedAgent == agent ? AppTheme.accentCyan.opacity(0.12) : Color
                                                    .clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("launchSession_button_agent_\(agent.id)")
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Execution Preset").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                ForEach(SessionLauncher.ExecutionPreset.allCases) { preset in
                                    Button {
                                        selectedPreset = preset
                                        selectedAgent = preset.agent
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: preset.icon)
                                                .frame(width: 24)
                                                .foregroundStyle(selectedPreset == preset ? AppTheme
                                                    .accentCyan : AppTheme.textSecondary)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(preset.rawValue)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                Text(preset.description)
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.textSecondary)
                                                    .lineLimit(2)
                                            }

                                            Spacer()

                                            if selectedPreset == preset {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(AppTheme.accentCyan)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedPreset == preset ? AppTheme.accentCyan.opacity(0.12) : Color
                                                    .clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("launchSession_button_preset_\(preset.id)")
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Custom Instructions").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                TextEditor(text: $customInstructions)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 80)
                                    .padding(12)
                                    .insetSurface(cornerRadius: 16, depth: 6)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .accessibilityIdentifier("launchSession_textEditor_customInstructions")
                            }
                        }
                        .padding(24)
                        .cardSurface(cornerRadius: 24, elevation: 8)

                        if isLaunching {
                            ProgressView("Launching session…")
                                .foregroundStyle(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if let error = appModel.sessionLauncher.lastError {
                            Text(error)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Launch Session")
            .agentBoardNavigationBarTitleInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityIdentifier("launchSession_button_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Launch") { launch() }
                        .buttonStyle(AppButtonStyle(isAccent: true))
                        .disabled(isLaunching || repoName.trimmedOrNil == nil)
                        .accessibilityIdentifier("launchSession_button_launch")
                }
            }
            .onAppear {
                if repoName.isEmpty {
                    repoName = displayRepoName
                }
                selectedAgent = selectedPreset.agent
            }
        }
        .accessibilityIdentifier("screen_launchSession")
    }

    private func launch() {
        guard !repoName.isEmpty else { return }
        isLaunching = true

        let config = SessionLauncher.LaunchConfig(
            taskTitle: displayTitle,
            issueNumber: displayIssueNumber,
            repo: repoName.trimmingCharacters(in: .whitespaces),
            fullRepo: displayFullRepo,
            preset: selectedPreset,
            agentType: selectedAgent,
            customInstructions: customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        Task {
            let sessionName = await appModel.sessionLauncher.launch(config: config)
            isLaunching = false
            if sessionName != nil {
                dismiss()
            }
        }
    }
}
