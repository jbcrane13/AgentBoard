import AgentBoardCore
import SwiftUI

struct QuickLaunchSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: SessionLauncher.ExecutionPreset = .ralphLoop
    @State private var selectedAgent: SessionLauncher.AgentType = .claude
    @State private var customInstructions = ""
    @State private var repoName = ""
    @State private var issueNumber = ""
    @State private var taskTitle = ""
    @State private var isLaunching = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("QUICK LAUNCH")
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(AppTheme.textSecondary)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Task Title").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                AppTextField(placeholder: "e.g. Implement feature X", text: $taskTitle)
                                    .accessibilityIdentifier("quick_launch_textfield_task_title")
                            }

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Issue #").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                    AppTextField(placeholder: "72", text: $issueNumber)
                                        .accessibilityIdentifier("quick_launch_textfield_issue_number")
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Repository").font(.headline).foregroundStyle(AppTheme.textPrimary)
                                    AppTextField(placeholder: "AgentBoard", text: $repoName)
                                        .accessibilityIdentifier("quick_launch_textfield_repo_name")
                                }
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
                                    .accessibilityIdentifier("quick_launch_button_agent_\(agent.id)")
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
                                    .accessibilityIdentifier("quick_launch_button_preset_\(preset.id)")
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
                                    .accessibilityIdentifier("quick_launch_texteditor_custom_instructions")
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
            .navigationTitle("Quick Launch")
            .agentBoardNavigationBarTitleInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityIdentifier("quick_launch_button_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Launch") { launch() }
                        .buttonStyle(AppButtonStyle(isAccent: true))
                        .disabled(isLaunching || repoName.trimmedOrNil == nil || taskTitle.trimmedOrNil == nil)
                        .accessibilityIdentifier("quick_launch_button_launch")
                }
            }
        }
        .accessibilityIdentifier("screen_quick_launch")
    }

    private func launch() {
        guard !repoName.isEmpty, !taskTitle.isEmpty else { return }
        isLaunching = true

        let num = Int(issueNumber.trimmingCharacters(in: .whitespaces)) ?? 0
        let fullRepo = "jbcrane13/\(repoName.trimmingCharacters(in: .whitespaces))"

        let config = SessionLauncher.LaunchConfig(
            taskTitle: taskTitle,
            issueNumber: num,
            repo: repoName.trimmingCharacters(in: .whitespaces),
            fullRepo: fullRepo,
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
