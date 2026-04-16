import SwiftUI

/// Sheet for generating a PRD from a GitHub issue and launching a GitHub-linked session.
struct PRDLauncherSheet: View {
    let issue: GitHubIssue

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var selectedAgent: AgentType = .claudeCode
    @State private var generatedPRD = ""
    @State private var isLaunching = false
    @State private var prdFilePath: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Launch PRD Session")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Issue #\(issue.number): \(issue.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)

                Divider()

                HStack {
                    Text("Agent:")
                        .fontWeight(.medium)

                    Picker("Agent", selection: $selectedAgent) {
                        Text("Claude Code").tag(AgentType.claudeCode)
                        Text("Codex").tag(AgentType.codex)
                        Text("OpenCode").tag(AgentType.openCode)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Generated PRD:")
                            .fontWeight(.medium)

                        Spacer()

                        Button("Regenerate") {
                            regeneratePRD()
                        }
                        .buttonStyle(.borderless)
                    }

                    ScrollView {
                        TextEditor(text: $generatedPRD)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 300)
                            .padding(4)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
                .padding()

                Divider()

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Launch Session") {
                        launchSession()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isLaunching || generatedPRD.isEmpty || appState.selectedProject == nil)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            regeneratePRD()
        }
    }

    private func regeneratePRD() {
        if let bead = appState.bead(issueNumber: issue.number) {
            generatedPRD = PRDGenerator().generatePRD(from: bead, childIssues: appState.childTasks(of: bead))
        } else {
            generatedPRD = PRDGenerator().generatePRD(from: issue)
        }
    }

    private func launchSession() {
        guard !generatedPRD.isEmpty, let project = appState.selectedProject else { return }

        isLaunching = true

        Task {
            let generator = PRDGenerator()
            let savedPath = generator.savePRD(content: generatedPRD, issueNumber: issue.number)
            await MainActor.run {
                prdFilePath = savedPath
            }

            let prompt = """
            Use the attached PRD as the execution brief for GitHub issue #\(issue.number).

            PRD file: \(savedPath)

            \(generatedPRD)
            """

            let launched = await appState.launchSession(
                project: project,
                agentType: selectedAgent,
                sessionType: .ralphLoop,
                issueNumber: issue.number,
                prompt: prompt
            )

            await MainActor.run {
                isLaunching = false
                if launched {
                    dismiss()
                }
            }
        }
    }
}
