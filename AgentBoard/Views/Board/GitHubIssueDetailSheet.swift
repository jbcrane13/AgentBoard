import SwiftUI

/// Sheet view for GitHub Issue details with session launch actions.
struct GitHubIssueDetailSheet: View {
    let issue: GitHubIssue

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var showingPRDLauncher = false
    @State private var selectedAgent: AgentType = .claudeCode

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard

                    if let body = issue.body, !body.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            Text(body)
                                .font(.body)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    actionCard
                }
                .padding()
            }
            .navigationTitle("Issue Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPRDLauncher) {
            PRDLauncherSheet(issue: issue)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Issue #\(issue.number)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(issue.title)
                .font(.title2)
                .fontWeight(.bold)

            if !issue.labels.isEmpty {
                HStack {
                    ForEach(issue.labels) { label in
                        Text(label.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            HStack {
                Label(issue.state.capitalized, systemImage: issue.state == "open" ? "circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(issue.state == "open" ? .green : .secondary)

                if !issue.assignees.isEmpty {
                    Label(issue.assignees.map(\.login).joined(separator: ", "), systemImage: "person")
                }

                if let milestone = issue.milestone {
                    Label(milestone.title, systemImage: "flag")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var actionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Agent", selection: $selectedAgent) {
                    Text("Claude Code").tag(AgentType.claudeCode)
                    Text("Codex").tag(AgentType.codex)
                    Text("OpenCode").tag(AgentType.openCode)
                }
                .pickerStyle(.segmented)

                Button("Launch Session") {
                    launchSimpleSession()
                }
                .buttonStyle(.bordered)
                .disabled(appState.selectedProject == nil)
            }

            Button("Launch PRD Session") {
                showingPRDLauncher = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(appState.selectedProject == nil)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func launchSimpleSession() {
        guard let project = appState.selectedProject else { return }

        let prompt = """
        Work on GitHub issue #\(issue.number): \(issue.title)

        \(issue.body ?? "")

        Labels: \(issue.labels.map(\.name).joined(separator: ", "))
        """

        Task {
            let launched = await appState.launchSession(
                project: project,
                agentType: selectedAgent,
                sessionType: .standard,
                issueNumber: issue.number,
                prompt: prompt
            )
            if launched {
                dismiss()
            }
        }
    }
}
