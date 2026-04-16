import SwiftUI

/// Sheet view for GitHub Issue details with PRD session launch capability
struct GitHubIssueDetailSheet: View {
    let issue: GitHubIssue
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showingPRDLauncher = false
    @State private var selectedAgent = "claude"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Issue header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Issue #\(issue.number)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(issue.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Labels
                        if !issue.labels.isEmpty {
                            HStack {
                                ForEach(issue.labels, id: \.name) { label in
                                    Text(label.name)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        // Metadata
                        HStack {
                            Label(issue.state.capitalized, systemImage: issue.state == "open" ? "circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(issue.state == "open" ? .green : .secondary)
                            
                            if !issue.assignees.isEmpty {
                                Label(issue.assignees.map { $0.login }.joined(separator: ", "), systemImage: "person")
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
                    
                    // Description
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
                    
                    // Actions
                    VStack(spacing: 12) {
                        // Simple session launch
                        HStack {
                            Picker("Agent", selection: $selectedAgent) {
                                Text("Claude Code").tag("claude")
                                Text("Codex").tag("codex")
                            }
                            .pickerStyle(.segmented)
                            
                            Button("Launch Session") {
                                launchSimpleSession()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        // PRD session launch
                        Button("Launch PRD Session") {
                            showingPRDLauncher = true
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
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
    
    private func launchSimpleSession() {
        let task = """
        Working on issue #\(issue.number): \(issue.title)
        
        \(issue.body ?? "")
        
        Labels: \(issue.labels.map { $0.name }.joined(separator: ", "))
        """
        
        let projectName = extractProjectName(from: issue)
        let sessionName = "\(selectedAgent)-issue-\(issue.number)"
        
        Task {
            await appState.launchSession(
                name: sessionName,
                agent: selectedAgent,
                project: projectName,
                task: task
            )
            dismiss()
        }
    }
    
    private func extractProjectName(from issue: GitHubIssue) -> String {
        // Try to extract project from labels
        for label in issue.labels {
            if label.name.hasPrefix("project:") {
                return String(label.name.dropFirst("project:".count))
            }
        }
        
        // Default to first label or "default"
        return issue.labels.first?.name ?? "default"
    }
}
