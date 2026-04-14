# AgentBoard Improvements - Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Make AgentBoard a great agent-human collaboration tool with reliable GitHub integration, clean chat, todo boards, and cross-review workflows.

**Architecture:** Refactor existing SwiftUI app, improve existing views, add missing features incrementally. Keep current layout (sidebar/center/right panel).

**Tech Stack:** SwiftUI, SwiftData, Swift 6 strict concurrency, GitHub API (gh CLI), Telegram Bot API, tmux (for agent sessions), macOS 15+.

---

## Phase 1: GitHub Issues Reliability

### Task 1: Add retry logic to GitHubIssuesService

**Objective:** Make GitHub API calls resilient to transient failures

**Files:**
- Modify: `AgentBoard/Services/GitHubIssuesService.swift`

**Step 1:** Add retry helper method

```swift
// Add to GitHubIssuesService
private func withRetry<T>(
    maxRetries: Int = 3,
    initialDelay: TimeInterval = 1.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?
    
    for attempt in 0..<maxRetries {
        do {
            return try await operation()
        } catch let error as GitHubError {
            // Don't retry auth or not-found errors
            if error == .unauthorized || error == .notFound {
                throw error
            }
            lastError = error
        } catch {
            lastError = error
        }
        
        if attempt < maxRetries - 1 {
            let delay = initialDelay * pow(2.0, Double(attempt))
            try await Task.sleep(for: .seconds(delay))
        }
    }
    
    throw lastError ?? GitHubError.invalidResponse
}
```

**Step 2:** Wrap existing fetch methods

```swift
// Update fetchIssues to use retry
func fetchIssues(owner: String, repo: String) async throws -> [GitHubIssue] {
    return try await withRetry {
        // existing fetch logic
    }
}
```

**Step 3:** Build and verify

Run: `xcodebuild -scheme AgentBoard -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 4:** Commit

```bash
git add AgentBoard/Services/GitHubIssuesService.swift
git commit -m "feat: add retry logic to GitHub issues service"
```

---

### Task 2: Add error state to AppState for GitHub

**Objective:** Surface GitHub errors in the UI

**Files:**
- Modify: `AgentBoard/App/AppState.swift`

**Step 1:** Add error properties

```swift
// Add to AppState class
@Published var githubError: String?
@Published var isGitHubLoading: Bool = false
```

**Step 2:** Update fetch methods to set error state

```swift
func loadGitHubIssues() async {
    isGitHubLoading = true
    githubError = nil
    
    do {
        // existing fetch
    } catch {
        githubError = error.localizedDescription
    }
    
    isGitHubLoading = false
}
```

**Step 3:** Build and verify

**Step 4:** Commit

```bash
git add AgentBoard/App/AppState.swift
git commit -m "feat: add GitHub error state to AppState"
```

---

### Task 3: Add error banner to BoardView

**Objective:** Show GitHub errors prominently in the UI

**Files:**
- Modify: `AgentBoard/Views/Board/BoardView.swift`

**Step 1:** Add error banner at top of view

```swift
// Add to BoardView body
if let error = appState.githubError {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.white)
        
        Text(error)
            .font(.caption)
            .foregroundStyle(.white)
            .lineLimit(2)
        
        Spacer()
        
        Button("Retry") {
            Task {
                await appState.loadGitHubIssues()
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.white)
    }
    .padding(8)
    .background(Color.red.gradient)
    .cornerRadius(8)
    .padding(.horizontal)
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Board/BoardView.swift
git commit -m "feat: add GitHub error banner to board view"
```

---

### Task 4: Add GitHub connection status to sidebar

**Objective:** Show connection health at a glance

**Files:**
- Modify: `AgentBoard/Views/Sidebar/SidebarView.swift`

**Step 1:** Add status indicator

```swift
// Add to sidebar bottom
HStack(spacing: 6) {
    Circle()
        .fill(appState.githubError != nil ? Color.red : Color.green)
        .frame(width: 8, height: 8)
    
    if appState.isGitHubLoading {
        ProgressView()
            .controlSize(.small)
    }
    
    Text(appState.githubError != nil ? "GitHub Error" : "GitHub Connected")
        .font(.caption2)
        .foregroundStyle(.secondary)
}
.padding(.horizontal, 12)
.padding(.vertical, 6)
.background(.ultraThinMaterial)
.cornerRadius(6)
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Sidebar/SidebarView.swift
git commit -m "feat: add GitHub connection status to sidebar"
```

---

## Phase 2: Clean Chat Rendering

### Task 5: Create message renderer that hides tool calls

**Objective:** Never show raw tool calls to users

**Files:**
- Create: `AgentBoard/Views/Chat/MessageRenderer.swift`

**Step 1:** Create message renderer

```swift
import SwiftUI

struct MessageRenderer: View {
    let message: ChatMessage
    
    var body: some View {
        if message.isToolCall {
            // Show human-readable summary instead of raw tool call
            toolCallSummary
        } else {
            // Regular message
            regularMessage
        }
    }
    
    @ViewBuilder
    private var toolCallSummary: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            
            Text(parseToolCallSummary(message.content))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var regularMessage: some View {
        // existing message rendering
        Text(message.content)
            .padding(12)
            .background(message.isFromUser ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundStyle(message.isFromUser ? .white : .primary)
            .cornerRadius(16)
    }
    
    private func parseToolCallSummary(_ rawCall: String) -> String {
        // Parse "terminal(command: "gh issue list...")" → "Checking GitHub issues..."
        if rawCall.contains("gh issue") {
            return "🔍 Checking GitHub issues..."
        } else if rawCall.contains("xcodebuild") {
            return "🔨 Building project..."
        } else if rawCall.contains("git") {
            return "📝 Working with git..."
        }
        return "⚙️ Working..."
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Chat/MessageRenderer.swift
git commit -m "feat: add clean message renderer that hides tool calls"
```

---

### Task 6: Update ChatPanelView to use new renderer

**Objective:** Integrate clean rendering into chat

**Files:**
- Modify: `AgentBoard/Views/Chat/ChatPanelView.swift`

**Step 1:** Replace message rendering with MessageRenderer

```swift
// In the ForEach of messages
ForEach(messages) { message in
    MessageRenderer(message: message)
        .id(message.id)
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Chat/ChatPanelView.swift
git commit -m "feat: integrate clean message renderer into chat panel"
```

---

### Task 7: Expand text input area

**Objective:** Make text input grow with content

**Files:**
- Modify: `AgentBoard/Views/Chat/ChatPanelView.swift`

**Step 1:** Replace fixed TextEditor with expanding one

```swift
// Replace existing text input
TextEditor(text: $inputText)
    .frame(minHeight: 40, maxHeight: 200)
    .padding(8)
    .background(.ultraThinMaterial)
    .cornerRadius(8)
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(.secondary.opacity(0.3), lineWidth: 1)
    )
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Chat/ChatPanelView.swift
git commit -m "feat: expand text input area to grow with content"
```

---

## Phase 3: Slash Commands

### Task 8: Create slash command infrastructure

**Objective:** Build system for handling slash commands

**Files:**
- Create: `AgentBoard/Services/SlashCommandService.swift`

**Step 1:** Create slash command service

```swift
import Foundation

struct SlashCommand {
    let name: String
    let description: String
    let action: () async -> String
}

@MainActor
@Observable
final class SlashCommandService {
    var commands: [SlashCommand] = []
    var suggestions: [SlashCommand] = []
    
    init() {
        registerDefaultCommands()
    }
    
    private func registerDefaultCommands() {
        commands = [
            SlashCommand(name: "status", description: "Show project status") {
                return "📊 Project Status:\n• NetMonitor: 4 issues\n• GrowWise: 2 issues"
            },
            SlashCommand(name: "issues", description: "List open issues") {
                return "📋 Open Issues:\n#177 Coverage below target\n#176 Error recovery tests"
            },
            SlashCommand(name: "build", description: "Build current project") {
                return "🔨 Starting build..."
            },
            SlashCommand(name: "test", description: "Run tests") {
                return "🧪 Starting tests..."
            }
        ]
    }
    
    func processInput(_ input: String) -> Bool {
        guard input.hasPrefix("/") else { return false }
        
        let commandName = String(input.dropFirst()).components(separatedBy: " ").first ?? ""
        
        if let command = commands.first(where: { $0.name == commandName }) {
            Task {
                let result = await command.action()
                // Handle result
            }
            return true
        }
        
        return false
    }
    
    func updateSuggestions(for input: String) {
        guard input.hasPrefix("/") else {
            suggestions = []
            return
        }
        
        let query = String(input.dropFirst())
        suggestions = commands.filter { $0.name.hasPrefix(query) }
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Services/SlashCommandService.swift
git commit -m "feat: add slash command infrastructure"
```

---

### Task 9: Integrate slash commands into chat input

**Objective:** Make slash commands work in chat

**Files:**
- Modify: `AgentBoard/Views/Chat/ChatPanelView.swift`

**Step 1:** Add slash command service and suggestions

```swift
@State private var slashService = SlashCommandService()

// Add suggestions dropdown above text input
if !slashService.suggestions.isEmpty {
    VStack(alignment: .leading, spacing: 4) {
        ForEach(slashService.suggestions, id: \.name) { command in
            Button("/\(command.name) - \(command.description)") {
                inputText = "/\(command.name) "
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
    .padding(8)
    .background(.ultraThinMaterial)
    .cornerRadius(8)
}
```

**Step 2:** Update on change of input text

```swift
.onChange(of: inputText) { _, newValue in
    slashService.updateSuggestions(for: newValue)
}
```

**Step 3:** Handle slash commands on send

```swift
private func sendMessage() {
    if slashService.processInput(inputText) {
        inputText = ""
        return
    }
    // existing send logic
}
```

**Step 4:** Build and verify

**Step 5:** Commit

```bash
git add AgentBoard/Views/Chat/ChatPanelView.swift
git commit -m "feat: integrate slash commands into chat with autocomplete"
```

---

## Phase 4: Daily Goals / Todo Board

### Task 10: Create DailyGoal SwiftData model

**Objective:** Model for daily goals/todos

**Files:**
- Create: `AgentBoard/Models/DailyGoal.swift`

**Step 1:** Create the model

```swift
import Foundation
import SwiftData

@Model
final class DailyGoal {
    var id: UUID
    var title: String
    var goalDescription: String
    var project: String
    var assignedAgent: String? // "hermes", "claude", "codex", nil for human
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var date: Date // The day this goal is for
    var sortOrder: Int
    
    // Link to GitHub issue if applicable
    var linkedIssueNumber: Int?
    
    init(title: String, description: String = "", project: String, assignedAgent: String? = nil, date: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.goalDescription = description
        self.project = project
        self.assignedAgent = assignedAgent
        self.isCompleted = false
        self.createdAt = Date()
        self.date = date
        self.sortOrder = 0
    }
    
    func markComplete() {
        isCompleted = true
        completedAt = Date()
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Models/DailyGoal.swift
git commit -m "feat: add DailyGoal SwiftData model for todo board"
```

---

### Task 11: Create DailyGoalsView

**Objective:** Todo list style view for daily goals

**Files:**
- Create: `AgentBoard/Views/Planning/DailyGoalsView.swift`

**Step 1:** Create the view

```swift
import SwiftUI
import SwiftData

struct DailyGoalsView: View {
    @Query var goals: [DailyGoal]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddGoal = false
    @State private var newGoalTitle = ""
    @State private var selectedProject = "netmonitor"
    @State private var selectedAgent: String? = nil
    
    let projects = ["netmonitor", "growwise", "agentboard"]
    let agents = [nil, "hermes", "claude", "codex"]
    
    var todayGoals: [DailyGoal] {
        let calendar = Calendar.current
        return goals.filter { calendar.isDate($0.date, inSameDayAs: Date()) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Today's Goals")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Add Goal") {
                    showingAddGoal = true
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Goals list
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Group by project
                    ForEach(Array(Set(todayGoals.map { $0.project })).sorted(), id: \.self) { project in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(project.capitalized)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            ForEach(todayGoals.filter { $0.project == project }) { goal in
                                GoalRow(goal: goal)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalSheet()
        }
    }
}

struct GoalRow: View {
    let goal: DailyGoal
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    goal.markComplete()
                }
            } label: {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(goal.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .strikethrough(goal.isCompleted)
                
                if let agent = goal.assignedAgent {
                    Text(agent.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if goal.isCompleted {
                Text("✓")
                    .foregroundStyle(.green)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var project = "netmonitor"
    @State private var assignedAgent: String? = nil
    
    let projects = ["netmonitor", "growwise", "agentboard"]
    let agents = [nil, "hermes", "claude", "codex"]
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal title", text: $title)
                
                Picker("Project", selection: $project) {
                    ForEach(projects, id: \.self) { Text($0.capitalized) }
                }
                
                Picker("Assign to", selection: $assignedAgent) {
                    Text("Blake (Human)").tag(nil as String?)
                    Text("Hermes").tag("hermes" as String?)
                    Text("Claude Code").tag("claude" as String?)
                    Text("Codex").tag("codex" as String?)
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let goal = DailyGoal(
                            title: title,
                            project: project,
                            assignedAgent: assignedAgent
                        )
                        modelContext.insert(goal)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 300)
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Planning/DailyGoalsView.swift
git commit -m "feat: add daily goals todo board view"
```

---

### Task 12: Add daily goals to sidebar navigation

**Objective:** Make daily goals accessible from sidebar

**Files:**
- Modify: `AgentBoard/Views/Sidebar/ViewsNavView.swift`

**Step 1:** Add daily goals navigation item

```swift
// Add to navigation items
NavigationLink(destination: DailyGoalsView()) {
    Label("Today's Goals", systemImage: "checklist")
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Sidebar/ViewsNavView.swift
git commit -m "feat: add daily goals to sidebar navigation"
```

---

## Summary: Phase 1-4 (Foundation)

**Total Tasks:** 12
**Estimated Time:** 3-4 hours
**Focus:** Reliability, clean chat, slash commands, todo board

**Next Phases:**
- Phase 5: File attachments for issues
- Phase 6: Subtask support (Epic > Tasks)
- Phase 7: Agent assignment notifications
- Phase 8: Session-task linking
- Phase 9: Cross-review workflow

---

*Save to: `docs/plans/2026-04-13-agentboard-foundation-improvements.md`*