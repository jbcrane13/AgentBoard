import SwiftUI

struct NewSessionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProjectID: UUID?
    @State private var selectedAgentType: AgentType = .claudeCode
    @State private var beadID = ""
    @State private var prompt = ""
    @State private var isLaunching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Session")
                .font(.system(size: 16, weight: .semibold))

            projectPicker
            agentPicker

            TextField("Linked bead ID (optional)", text: $beadID)
                .textFieldStyle(.roundedBorder)

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
            }

            Spacer(minLength: 8)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isLaunching ? "Launching..." : "Launch") {
                    launch()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isLaunching || selectedProject == nil)
            }
        }
        .padding(20)
        .frame(width: 500, height: 360)
        .onAppear {
            selectedProjectID = appState.selectedProjectID ?? appState.projects.first?.id
        }
    }

    private var projectPicker: some View {
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
        }
    }

    private var agentPicker: some View {
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
        }
    }

    private var selectedProject: Project? {
        if let selectedProjectID {
            return appState.projects.first(where: { $0.id == selectedProjectID })
        }
        return appState.selectedProject ?? appState.projects.first
    }

    private func launch() {
        guard let selectedProject else { return }
        isLaunching = true

        Task { @MainActor in
            let success = await appState.launchSession(
                project: selectedProject,
                agentType: selectedAgentType,
                beadID: trimmedValue(beadID),
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
