import SwiftUI

/// Sheet that generates a PRD preview from an issue and allows launching a PRD session.
struct PRDLauncherSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let bead: Bead

    @State private var generatedPRD = ""
    @State private var isLaunching = false
    @State private var selectedAgent: AgentType = .claudeCode

    private let prdGenerator = PRDGenerator()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    agentSection
                    prdPreviewSection
                }
                .padding(20)
            }

            Divider()
            footer
        }
        .frame(
            minWidth: 520,
            idealWidth: 600,
            maxWidth: 700,
            minHeight: 400,
            idealHeight: 520,
            maxHeight: 640
        )
        .onAppear {
            generatedPRD = prdGenerator.generatePRD(from: bead)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 16))
                .foregroundStyle(.purple)

            Text("Launch PRD Session")
                .font(.system(size: 15, weight: .semibold))

            Text(bead.id)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Agent Selection

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Agent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Picker("", selection: $selectedAgent) {
                ForEach(AgentType.allCases, id: \.self) { agent in
                    Text(agentLabel(agent)).tag(agent)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - PRD Preview

    private var prdPreviewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Generated PRD")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextEditor(text: $generatedPRD)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 200)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Launch PRD Session") {
                launchPRDSession()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLaunching || generatedPRD.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(16)
    }

    // MARK: - Actions

    private func launchPRDSession() {
        guard let project = appState.selectedProject else { return }
        isLaunching = true
        let prdContent = generatedPRD
        let prdPath = prdGenerator.savePRD(content: prdContent, for: bead)
        let agent = selectedAgent
        let issueID = bead.id
        let title = bead.title

        Task { @MainActor in
            await appState.launchSession(
                project: project,
                agentType: agent,
                sessionType: .ralphLoop,
                issueNumber: GitHubIssuesService.issueNumber(from: issueID),
                prompt: "Work on \(issueID): \(title) --prd \(prdPath)"
            )
            isLaunching = false
            dismiss()
        }
    }

    // MARK: - Helpers

    private func agentLabel(_ agent: AgentType) -> String {
        switch agent {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .opencode: return "OpenCode"
        }
    }
}
