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
                NeuBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("LAUNCH SESSION")
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(NeuPalette.textSecondary)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Task").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                Text(displayTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(NeuPalette.textSecondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .neuRecessed(cornerRadius: 12, depth: 4)
                            }

                            // If launched from a work item (GitHub issue), show the issue ref
                            if let workItem {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Issue").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                    Text(workItem.issueReference)
                                        .font(.subheadline.monospaced())
                                        .foregroundStyle(NeuPalette.accentCyan)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Repository Folder").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                NeuTextField(placeholder: "e.g. AgentBoard", text: $repoName)
                                    .accessibilityIdentifier("launchSession_textfield_repoName")
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Agent").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                ForEach(SessionLauncher.AgentType.allCases) { agent in
                                    Button {
                                        selectedAgent = agent
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: agent.icon)
                                                .frame(width: 24)
                                                .foregroundStyle(selectedAgent == agent ? NeuPalette
                                                    .accentCyan : NeuPalette.textSecondary)

                                            Text(agent.displayName)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(NeuPalette.textPrimary)

                                            Spacer()

                                            if selectedAgent == agent {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(NeuPalette.accentCyan)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedAgent == agent ? Color.white.opacity(0.05) : Color
                                                    .clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Execution Preset").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                ForEach(SessionLauncher.ExecutionPreset.allCases) { preset in
                                    Button {
                                        selectedPreset = preset
                                        selectedAgent = preset.agent
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: preset.icon)
                                                .frame(width: 24)
                                                .foregroundStyle(selectedPreset == preset ? NeuPalette
                                                    .accentCyan : NeuPalette.textSecondary)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(preset.rawValue)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(NeuPalette.textPrimary)
                                                Text(preset.description)
                                                    .font(.caption)
                                                    .foregroundStyle(NeuPalette.textSecondary)
                                                    .lineLimit(2)
                                            }

                                            Spacer()

                                            if selectedPreset == preset {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(NeuPalette.accentCyan)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedPreset == preset ? Color.white.opacity(0.05) : Color
                                                    .clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Custom Instructions").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                TextEditor(text: $customInstructions)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 80)
                                    .padding(12)
                                    .neuRecessed(cornerRadius: 16, depth: 6)
                                    .foregroundStyle(NeuPalette.textPrimary)
                            }
                        }
                        .padding(24)
                        .neuExtruded(cornerRadius: 24, elevation: 8)

                        if isLaunching {
                            ProgressView("Launching session…")
                                .foregroundStyle(NeuPalette.textPrimary)
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
                        .foregroundStyle(NeuPalette.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Launch") { launch() }
                        .buttonStyle(NeuButtonTarget(isAccent: true))
                        .disabled(isLaunching || repoName.trimmedOrNil == nil)
                }
            }
            .onAppear {
                if repoName.isEmpty {
                    repoName = displayRepoName
                }
                selectedAgent = selectedPreset.agent
            }
        }
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
