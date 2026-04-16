import SwiftUI

/// A view that launches coding sessions from issue cards.
///
/// Features:
/// - Launch Claude Code or Codex sessions linked to issues
/// - Agent selection with visual indicators
/// - Session configuration options (working directory, branch name)
/// - Real-time session status tracking
/// - Issue context display with priority and status
/// - PRD-based workflow support for ralphy --prd flag
///
/// Usage:
/// ```swift
/// @State var epic = Epic.sample()
/// @State var showLauncher = false
///
/// .sheet(isPresented: $showLauncher) {
///     SessionLauncher(epic: $epic)
/// }
/// ```
public struct SessionLauncher: View {
    @Binding public var epic: Epic
    @Environment(\.dismiss) private var dismiss

    /// Available coding agents for session launch
    @State private var selectedAgent: CodingAgent = .claudeCode
    @State private var workingDirectory: String = ""
    @State private var branchName: String = ""
    @State private var sessionState: SessionState = .idle
    @State private var statusMessage: String?
    
    /// Launch mode selection
    @State private var launchMode: LaunchMode = .simple
    @State private var prdFilePath: String?

    /// Callback when a session is launched
    public var onSessionLaunched: ((SessionLaunchResult) -> Void)?

    /// Initialize the session launcher
    /// - Parameters:
    ///   - epic: Binding to the epic/issue model
    ///   - onSessionLaunched: Optional callback when session is launched
    public init(
        epic: Binding<Epic>,
        onSessionLaunched: ((SessionLaunchResult) -> Void)? = nil
    ) {
        self._epic = epic
        self.onSessionLaunched = onSessionLaunched
        self._workingDirectory = State(initialValue: "~/workspace/\(epic.wrappedValue.id)")
        self._branchName = State(initialValue: "feature/\(epic.wrappedValue.title.lowercased().prefix(30).replacingOccurrences(of: " ", with: "-"))")
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    issueContextSection
                    agentSelectionSection
                    launchModeSection
                    configurationSection

                    if let message = statusMessage {
                        statusBanner(message)
                    }
                }
                .padding(20)
            }

            footerSection
        }
        .frame(width: 520, height: 560)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.accentColor)
                Text("Launch Session")
                    .font(.headline)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Issue Context

    private var issueContextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Issue")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                // Priority indicator
                VStack(spacing: 2) {
                    Image(systemName: priorityIcon)
                        .font(.title3)
                        .foregroundColor(priorityColor)
                    Text(epic.priority.rawValue.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(priorityColor)
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(epic.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    if let description = epic.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: epic.status.iconName)
                        .font(.caption2)
                    Text(epic.status.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(statusColor.opacity(0.15))
                )
                .foregroundColor(statusColor)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Agent Selection

    private var agentSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coding Agent")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(CodingAgent.allCases, id: \.self) { agent in
                    agentCard(agent)
                }
            }
        }
    }

    private func agentCard(_ agent: CodingAgent) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedAgent = agent
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: agent.iconName)
                    .font(.title2)
                    .foregroundColor(selectedAgent == agent ? .white : agent.brandColor)

                Text(agent.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedAgent == agent ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedAgent == agent ? agent.brandColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        selectedAgent == agent ? agent.brandColor : Color(nsColor: .separatorColor),
                        lineWidth: selectedAgent == agent ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Launch Mode

    private var launchModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Launch Mode")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(LaunchMode.allCases, id: \.self) { mode in
                    launchModeCard(mode)
                }
            }
            
            if launchMode == .prd {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.accentColor)
                    Text("Generates PRD markdown and launches with ralphy --prd flag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private func launchModeCard(_ mode: LaunchMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                launchMode = mode
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.title2)
                    .foregroundColor(launchMode == mode ? .white : mode.color)

                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(launchMode == mode ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(launchMode == mode ? mode.color : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        launchMode == mode ? mode.color : Color(nsColor: .separatorColor),
                        lineWidth: launchMode == mode ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                // Working directory
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    TextField("Working directory", text: $workingDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                // Branch name
                HStack {
                    Image(systemName: "arrow.branch")
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    TextField("Branch name (optional)", text: $branchName)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if sessionState == .launching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Launching session...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button {
                launchSession()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Launch Session")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(sessionState == .launching || epic.status == .blocked)
        }
        .padding(16)
    }

    // MARK: - Status Banner

    private func statusBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            if sessionState == .launching {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: message.hasPrefix("✓") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(message.hasPrefix("✓") ? .green : .orange)
            }
            Text(message)
                .font(.caption)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Helpers

    private var priorityIcon: String {
        switch epic.priority {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "arrow.up.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }

    private var priorityColor: Color {
        switch epic.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private var statusColor: Color {
        switch epic.status {
        case .todo: return .gray
        case .inProgress: return .blue
        case .done: return .green
        case .blocked: return .red
        }
    }

    // MARK: - Session Launch

    private func launchSession() {
        sessionState = .launching
        statusMessage = "Launching \(selectedAgent.displayName) session..."

        // Generate a session ID
        let sessionId = UUID().uuidString

        // Handle PRD mode
        if launchMode == .prd {
            launchWithPRD(sessionId: sessionId)
            return
        }

        // Build the command based on selected agent (simple mode)
        let command = selectedAgent.buildCommand(
            workingDirectory: workingDirectory,
            branchName: branchName.isEmpty ? nil : branchName,
            issueId: epic.id,
            issueTitle: epic.title
        )

        // Simulate launch delay for UI feedback
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                sessionState = .launched
                statusMessage = "✓ Session launched successfully"

                let result = SessionLaunchResult(
                    sessionId: sessionId,
                    agent: selectedAgent,
                    epicId: epic.id,
                    workingDirectory: workingDirectory,
                    branchName: branchName.isEmpty ? nil : branchName,
                    command: command
                )

                onSessionLaunched?(result)

                // Auto-dismiss after success
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// Launch session with PRD-based workflow using ralphy --prd flag
    private func launchWithPRD(sessionId: String) {
        // Convert Epic to BeadIssue for PRD generation
        let issue = BeadIssue(
            beadId: epic.id,
            title: epic.title,
            description: epic.description ?? "No description provided",
            tasks: epic.subtasks.map { subtask in
                IssueTask(
                    title: subtask.title,
                    isCompleted: subtask.status == .done,
                    assignee: subtask.assignee
                )
            },
            priority: epic.priority
        )
        
        // Generate PRD markdown
        let generator = PRDGenerator()
        let result = generator.generatePRD(from: issue)
        
        switch result {
        case .success(let markdown):
            // Save PRD to temp file
            let tempPath = NSTemporaryDirectory() + "prd-\(epic.id).md"
            do {
                try markdown.write(toFile: tempPath, atomically: true, encoding: .utf8)
                prdFilePath = tempPath
                
                // Build command with --prd flag
                let command = selectedAgent.buildCommand(
                    workingDirectory: workingDirectory,
                    branchName: branchName.isEmpty ? nil : branchName,
                    issueId: epic.id,
                    issueTitle: epic.title,
                    prdPath: tempPath
                )
                
                // Simulate launch delay for UI feedback
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await MainActor.run {
                        sessionState = .launched
                        statusMessage = "✓ PRD session launched successfully"

                        let launchResult = SessionLaunchResult(
                            sessionId: sessionId,
                            agent: selectedAgent,
                            epicId: epic.id,
                            workingDirectory: workingDirectory,
                            branchName: branchName.isEmpty ? nil : branchName,
                            command: command,
                            prdFilePath: tempPath
                        )

                        onSessionLaunched?(launchResult)

                        // Auto-dismiss after success
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    }
                }
            } catch {
                sessionState = .failed
                statusMessage = "Failed to save PRD file: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            sessionState = .failed
            statusMessage = "PRD generation failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Launch Mode

/// Launch mode for session execution
public enum LaunchMode: String, CaseIterable, Codable, Sendable {
    case simple = "Simple"
    case prd = "PRD"

    public var displayName: String { rawValue }

    public var iconName: String {
        switch self {
        case .simple: return "play.circle"
        case .prd: return "doc.text"
        }
    }

    public var color: Color {
        switch self {
        case .simple: return .blue
        case .prd: return .orange
        }
    }
}

// MARK: - Coding Agent

/// Supported coding agents for session launch
public enum CodingAgent: String, CaseIterable, Codable, Sendable {
    case claudeCode = "claude-code"
    case codex = "codex"

    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    public var iconName: String {
        switch self {
        case .claudeCode: return "sparkle"
        case .codex: return "curlybraces"
        }
    }

    public var brandColor: Color {
        switch self {
        case .claudeCode: return .purple
        case .codex: return .teal
        }
    }

    /// Build the CLI command to launch this agent
    public func buildCommand(
        workingDirectory: String,
        branchName: String?,
        issueId: String,
        issueTitle: String,
        prdPath: String? = nil
    ) -> String {
        var parts: [String] = []

        // Change to working directory
        parts.append("cd \(workingDirectory)")

        // Create and checkout branch if specified
        if let branch = branchName {
            parts.append("git checkout -b \(branch)")
        }

        // Build the agent command
        var agentCommand: String
        switch self {
        case .claudeCode:
            agentCommand = "claude --issue \"\(issueId)\" --title \"\(issueTitle)\""
        case .codex:
            agentCommand = "codex --issue \"\(issueId)\" \"\(issueTitle)\""
        }
        
        // Append --prd flag if PRD path is provided
        if let prdPath = prdPath {
            agentCommand += " --prd \"\(prdPath)\""
        }
        
        parts.append(agentCommand)

        return parts.joined(separator: " && ")
    }
}

// MARK: - Session State

/// State of a session launch operation
public enum SessionState: String, Codable, Sendable {
    case idle
    case launching
    case launched
    case failed
}

// MARK: - Session Launch Result

/// Result of a session launch operation
public struct SessionLaunchResult: Codable, Identifiable, Sendable {
    public let id: String
    public let sessionId: String
    public let agent: CodingAgent
    public let epicId: String
    public let workingDirectory: String
    public let branchName: String?
    public let command: String
    public let launchedAt: Date
    public let prdFilePath: String?

    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        agent: CodingAgent,
        epicId: String,
        workingDirectory: String,
        branchName: String?,
        command: String,
        launchedAt: Date = Date(),
        prdFilePath: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.agent = agent
        self.epicId = epicId
        self.workingDirectory = workingDirectory
        self.branchName = branchName
        self.command = command
        self.launchedAt = launchedAt
        self.prdFilePath = prdFilePath
    }
}

// MARK: - Preview

#if DEBUG
struct SessionLauncher_Previews: PreviewProvider {
    static var previews: some View {
        SessionLauncher(
            epic: .constant(Epic.sample()),
            onSessionLaunched: { result in
                print("Session launched: \(result.sessionId)")
            }
        )
    }
}
#endif
