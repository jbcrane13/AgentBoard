import SwiftUI

struct NewSessionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Optional pre-fill values (e.g. when launching from an issue detail view).
    var initialProjectID: UUID?
    var initialIssueNumber: Int?
    var initialPrompt: String?

    @State private var selectedProjectID: UUID?
    @State private var selectedAgentType: AgentType = .claudeCode
    @State private var issueNumberText = ""
    @State private var prompt = ""
    @State private var isLaunching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Session")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Project
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Project")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Picker("Project", selection: $selectedProjectID) {
                            ForEach(appState.projects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .accessibilityIdentifier("new_session_picker_project")
                    }

                    // Agent
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Agent")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Picker("Agent", selection: $selectedAgentType) {
                            ForEach(AgentType.allCases, id: \.self) { agent in
                                Text(agentLabel(agent)).tag(agent)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityIdentifier("new_session_picker_agent")
                    }

                    // GitHub Issue
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GitHub Issue (optional)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("e.g. 16", text: $issueNumberText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("new_session_issue_number_field")
                    }

                    // Prompt
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt (optional)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextEditor(text: $prompt)
                            .font(.system(size: 12))
                            .frame(minHeight: 100)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                            .accessibilityIdentifier("new_session_editor_prompt")
                    }
                }
            }

            // Error message display
            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.vertical, 8)
            }

            Spacer(minLength: 12)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("new_session_button_cancel")

                Button(isLaunching ? "Launching..." : "Launch") {
                    launch()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isLaunching || selectedProject == nil)
                .accessibilityIdentifier("new_session_button_launch")
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 500)
        .frame(minHeight: 500)
        .onAppear {
            selectedProjectID = initialProjectID ?? appState.selectedProjectID ?? appState.projects.first?.id
            if let initialIssueNumber {
                issueNumberText = String(initialIssueNumber)
            }
            if let initialPrompt {
                prompt = initialPrompt
            }
            appState.errorMessage = nil
        }
    }

    private var selectedProject: Project? {
        if let selectedProjectID {
            return appState.projects.first(where: { $0.id == selectedProjectID })
        }
        return appState.selectedProject ?? appState.projects.first
    }

    private var parsedIssueNumber: Int? {
        let trimmed = issueNumberText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        return Int(trimmed)
    }

    private func launch() {
        guard let selectedProject else { return }
        isLaunching = true

        Task<Void, Never> { @MainActor in
            let success = await appState.launchSession(
                project: selectedProject,
                agentType: selectedAgentType,
                issueNumber: parsedIssueNumber,
                prompt: trimmedValue(prompt)
            )
            isLaunching = false
            if success {
                dismiss()
            }
        }
    }

    private func trimmedValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func agentLabel(_ agentType: AgentType) -> String {
        switch agentType {
        case .claudeCode:
            return "Claude Code"
        case .codex:
            return "Codex"
        case .openCode:
            return "OpenCode"
        }
    }
}
