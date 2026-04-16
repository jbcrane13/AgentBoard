import SwiftUI

/// Sheet for launching PRD-based sessions from GitHub Issues
struct PRDLauncherSheet: View {
    let issue: GitHubIssue
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedAgent: AgentType = .claudeCode
    @State private var generatedPRD: String = ""
    @State private var isLaunching = false
    @State private var prdFilePath: String?
    
    enum AgentType: String, CaseIterable {
        case claudeCode = "Claude Code"
        case codex = "Codex"
        case openCode = "OpenCode"
        
        var command: String {
            switch self {
            case .claudeCode: return "claude"
            case .codex: return "codex"
            case .openCode: return "opencode"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
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
                
                // Agent selection
                HStack {
                    Text("Agent:")
                        .fontWeight(.medium)
                    
                    Picker("Agent", selection: $selectedAgent) {
                        ForEach(AgentType.allCases, id: \.self) { agent in
                            Text(agent.rawValue).tag(agent)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                
                Divider()
                
                // PRD preview
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
                
                // Launch button
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
                    .disabled(isLaunching || generatedPRD.isEmpty)
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
        let generator = PRDGenerator()
        generatedPRD = generator.generatePRD(from: issue)
    }
    
    private func launchSession() {
        guard !generatedPRD.isEmpty else { return }
        
        isLaunching = true
        
        Task {
            // Save PRD to temp file
            let generator = PRDGenerator()
            let prdPath = generator.savePRD(content: generatedPRD, issueNumber: issue.number)
            self.prdFilePath = prdPath
            
            // Launch session with PRD
            let projectName = extractProjectName(from: issue)
            let sessionName = "\(selectedAgent.command)-issue-\(issue.number)"
            
            await appState.launchSession(
                name: sessionName,
                agent: selectedAgent.command,
                project: projectName,
                task: "--prd \(prdPath)"
            )
            
            isLaunching = false
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
