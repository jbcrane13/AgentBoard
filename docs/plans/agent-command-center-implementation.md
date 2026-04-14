# Agent Command Center - Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Build a unified SwiftUI app for chatting with Hermes agents, viewing GitHub issues as Kanban, managing tasks, and watching live Claude Code/Codex CLI sessions.

**Architecture:** Single SwiftUI app with tab-based navigation. Chat tab talks to Hermes via Telegram bot API or direct HTTP. Kanban tab fetches GitHub issues via `gh` CLI. Task board uses local SwiftData storage. Terminal sessions are tmux captures rendered in SwiftUI.

**Tech Stack:** SwiftUI, SwiftData, Swift 6 strict concurrency, GitHub API (`gh` CLI), Telegram Bot API, tmux (for agent sessions), macOS 15+ (primary), iOS 18+ (companion).

---

## Phase 1: Project Skeleton & Core Navigation

### Task 1: Create Xcode project structure

**Objective:** Set up the AgentBoard app with 4-tab navigation

**Files:**
- Create: `AgentBoard/AgentBoardApp.swift`
- Create: `AgentBoard/Views/MainTabView.swift`
- Create: `AgentBoard/Models/Task.swift`
- Create: `AgentBoard/Info.plist`

**Step 1:** Create the app entry point

```swift
// AgentBoardApp.swift
import SwiftUI
import SwiftData

@main
struct AgentBoardApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [AgentTask.self])
    }
}
```

**Step 2:** Create the main tab view

```swift
// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
            
            KanbanView()
                .tabItem {
                    Label("Issues", systemImage: "rectangle.grid.3x2")
                }
            
            TaskBoardView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            TerminalView()
                .tabItem {
                    Label("Terminal", systemImage: "terminal")
                }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
```

**Step 3:** Create placeholder views

```swift
// ChatView.swift
import SwiftUI

struct ChatView: View {
    var body: some View {
        Text("Chat with Hermes")
            .font(.title)
    }
}

// KanbanView.swift
import SwiftUI

struct KanbanView: View {
    var body: some View {
        Text("GitHub Issues Kanban")
            .font(.title)
    }
}

// TaskBoardView.swift
import SwiftUI

struct TaskBoardView: View {
    var body: some View {
        Text("Agent Task Board")
            .font(.title)
    }
}

// TerminalView.swift
import SwiftUI

struct TerminalView: View {
    var body: some View {
        Text("Terminal Sessions")
            .font(.title)
    }
}
```

**Step 4:** Create the SwiftData model for tasks

```swift
// Models/Task.swift
import Foundation
import SwiftData

@Model
final class AgentTask {
    var id: UUID
    var title: String
    var taskDescription: String
    var status: String // "todo", "in_progress", "done"
    var assignedAgent: String? // "hermes", "claude", "codex"
    var project: String // "growwise", "netmonitor", "agentboard"
    var createdAt: Date
    var completedAt: Date?
    
    init(title: String, description: String = "", project: String, assignedAgent: String? = nil) {
        self.id = UUID()
        self.title = title
        self.taskDescription = description
        self.status = "todo"
        self.assignedAgent = assignedAgent
        self.project = project
        self.createdAt = Date()
    }
}
```

**Step 5:** Build and verify

Run: `xcodebuild -scheme AgentBoard -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 6:** Commit

```bash
git add AgentBoard/
git commit -m "feat: initial project skeleton with 4-tab navigation"
```

---

## Phase 2: Chat Interface

### Task 2: Build the chat message model

**Objective:** Create SwiftData model for chat messages

**Files:**
- Create: `AgentBoard/Models/ChatMessage.swift`

```swift
// Models/ChatMessage.swift
import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    var agent: String // "hermes", "claude", "codex"
    
    init(content: String, isFromUser: Bool, agent: String = "hermes") {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.agent = agent
    }
}
```

**Step 1:** Create the file and add the model above

**Step 2:** Update Info.plist to include ChatMessage in the SwiftData schema

**Step 3:** Commit

```bash
git add AgentBoard/Models/ChatMessage.swift
git commit -m "feat: add ChatMessage SwiftData model"
```

### Task 3: Build the chat view UI

**Objective:** Create a scrollable chat interface with message input

**Files:**
- Modify: `AgentBoard/Views/ChatView.swift`

```swift
// ChatView.swift
import SwiftUI
import SwiftData

struct ChatView: View {
    @Query(sort: \ChatMessage.timestamp) var messages: [ChatMessage]
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @State private var selectedAgent = "hermes"
    
    let agents = ["hermes", "claude", "codex"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Agent selector
            HStack {
                Picker("Agent", selection: $selectedAgent) {
                    ForEach(agents, id: \.self) { agent in
                        Text(agent.capitalized).tag(agent)
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages.filter { $0.agent == selectedAgent }) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Input
            HStack {
                TextField("Message...", text: $inputText)
                    .textFieldStyle(.plain)
                    .onSubmit { sendMessage() }
                
                Button("Send") {
                    sendMessage()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(inputText.isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(content: inputText, isFromUser: true, agent: selectedAgent)
        modelContext.insert(userMessage)
        
        let text = inputText
        inputText = ""
        
        // TODO: Send to actual agent and get response
        // For now, echo back
        Task {
            try? await Task.sleep(for: .seconds(1))
            let response = ChatMessage(content: "Echo: \(text)", isFromUser: false, agent: selectedAgent)
            modelContext.insert(response)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser { Spacer() }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading) {
                Text(message.content)
                    .padding(12)
                    .background(message.isFromUser ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isFromUser { Spacer() }
        }
    }
}
```

**Step 1:** Replace ChatView.swift with the code above

**Step 2:** Build and verify

Run: `xcodebuild -scheme AgentBoard -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 3:** Commit

```bash
git add AgentBoard/Views/ChatView.swift
git commit -m "feat: build chat interface with message bubbles"
```

---

## Phase 3: GitHub Kanban Board

### Task 4: Build GitHub issues data service

**Objective:** Fetch GitHub issues via `gh` CLI and parse into SwiftUI data

**Files:**
- Create: `AgentBoard/Services/GitHubService.swift`

```swift
// Services/GitHubService.swift
import Foundation

struct GitHubIssue: Identifiable, Codable {
    let number: Int
    let title: String
    let body: String?
    let state: String
    let labels: [GitHubLabel]
    let createdAt: Date
    let updatedAt: Date
    
    var id: Int { number }
    
    struct GitHubLabel: Codable {
        let name: String
        let color: String
    }
    
    // Map labels to Kanban columns
    var column: String {
        let labelNames = labels.map { $0.name.lowercased() }
        if labelNames.contains("status:in-progress") { return "In Progress" }
        if labelNames.contains("status:ready") { return "Ready" }
        if labelNames.contains("status:review") { return "Review" }
        if labelNames.contains("status:done") { return "Done" }
        return "Backlog"
    }
    
    var priority: Int {
        let labelNames = labels.map { $0.name.lowercased() }
        if labelNames.contains("priority:critical") { return 0 }
        if labelNames.contains("priority:high") { return 1 }
        if labelNames.contains("priority:medium") { return 2 }
        return 3
    }
}

@MainActor
@Observable
final class GitHubService {
    var issues: [GitHubIssue] = []
    var isLoading = false
    var errorMessage: String?
    
    let projects = [
        ("growwise", "jbcrane13/GrowWise"),
        ("netmonitor", "jbcrane13/NetMonitor-2.0"),
        ("agentboard", "jbcrane13/AgentBoard")
    ]
    
    func fetchIssues(for repo: String) async {
        isLoading = true
        errorMessage = nil
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gh")
        process.arguments = [
            "issue", "list",
            "--repo", repo,
            "--state", "open",
            "--json", "number,title,body,state,labels,createdAt,updatedAt",
            "--limit", "50"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            issues = try decoder.decode([GitHubIssue].self, from: data)
        } catch {
            errorMessage = "Failed to fetch issues: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateIssueStatus(issue: Int, repo: String, newStatus: String) async {
        let labelMap = [
            "Backlog": "status:ready",
            "Ready": "status:ready",
            "In Progress": "status:in-progress",
            "Review": "status:review",
            "Done": "status:done"
        ]
        
        guard let label = labelMap[newStatus] else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gh")
        process.arguments = [
            "issue", "edit", "\(issue)",
            "--repo", repo,
            "--add-label", label
        ]
        
        try? process.run()
        process.waitUntilExit()
        
        // Refresh issues
        await fetchIssues(for: repo)
    }
}
```

**Step 1:** Create the file with the code above

**Step 2:** Build to verify

**Step 3:** Commit

```bash
git add AgentBoard/Services/GitHubService.swift
git commit -m "feat: add GitHub service for fetching issues via gh CLI"
```

### Task 5: Build the Kanban board UI

**Objective:** Create a drag-and-drop Kanban board grouped by status

**Files:**
- Modify: `AgentBoard/Views/KanbanView.swift`

```swift
// KanbanView.swift
import SwiftUI

struct KanbanView: View {
    @State private var githubService = GitHubService()
    @State private var selectedProject = "netmonitor"
    @State private var draggedIssue: GitHubIssue?
    
    let columns = ["Backlog", "Ready", "In Progress", "Review", "Done"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Project selector
            HStack {
                Picker("Project", selection: $selectedProject) {
                    Text("GrowWise").tag("growwise")
                    Text("NetMonitor").tag("netmonitor")
                    Text("AgentBoard").tag("agentboard")
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        let repo = githubService.projects.first(where: { $0.0 == selectedProject })?.1 ?? ""
                        await githubService.fetchIssues(for: repo)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            if githubService.isLoading {
                ProgressView("Loading issues...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Kanban columns
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(columns, id: \.self) { column in
                            KanbanColumn(
                                title: column,
                                issues: issuesForColumn(column),
                                onDrop: { issue in
                                    moveIssue(issue, to: column)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            let repo = githubService.projects.first(where: { $0.0 == selectedProject })?.1 ?? ""
            await githubService.fetchIssues(for: repo)
        }
    }
    
    private func issuesForColumn(_ column: String) -> [GitHubIssue] {
        githubService.issues
            .filter { $0.column == column }
            .sorted { $0.priority < $1.priority }
    }
    
    private func moveIssue(_ issue: GitHubIssue, to column: String) {
        Task {
            let repo = githubService.projects.first(where: { $0.0 == selectedProject })?.1 ?? ""
            await githubService.updateIssueStatus(issue: issue.number, repo: repo, newStatus: column)
        }
    }
}

struct KanbanColumn: View {
    let title: String
    let issues: [GitHubIssue]
    let onDrop: (GitHubIssue) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(issues) { issue in
                        IssueCard(issue: issue)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(width: 250)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct IssueCard: View {
    let issue: GitHubIssue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("#\(issue.number)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(issue.title)
                .font(.subheadline)
                .lineLimit(2)
            
            HStack {
                ForEach(issue.labels, id: \.name) { label in
                    Text(label.name)
                        .font(.caption2)
                        .padding(4)
                        .background(Color(hex: label.color))
                        .cornerRadius(4)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
```

**Step 1:** Replace KanbanView.swift with the code above

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/KanbanView.swift
git commit -m "feat: build Kanban board with GitHub issues integration"
```

---

## Phase 4: Task Board

### Task 6: Build the task board UI

**Objective:** Create a view for assigning tasks to agents

**Files:**
- Modify: `AgentBoard/Views/TaskBoardView.swift`

```swift
// TaskBoardView.swift
import SwiftUI
import SwiftData

struct TaskBoardView: View {
    @Query(sort: \AgentTask.createdAt) var tasks: [AgentTask]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddTask = false
    @State private var selectedProject = "all"
    
    let projects = ["all", "growwise", "netmonitor", "agentboard"]
    let agents = ["hermes", "claude", "codex"]
    
    var filteredTasks: [AgentTask] {
        if selectedProject == "all" {
            return tasks
        }
        return tasks.filter { $0.project == selectedProject }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filters
            HStack {
                Picker("Project", selection: $selectedProject) {
                    Text("All Projects").tag("all")
                    Text("GrowWise").tag("growwise")
                    Text("NetMonitor").tag("netmonitor")
                    Text("AgentBoard").tag("agentboard")
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                Button("Add Task") {
                    showingAddTask = true
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Task columns
            HStack(alignment: .top, spacing: 16) {
                TaskColumn(title: "To Do", status: "todo", tasks: filteredTasks)
                TaskColumn(title: "In Progress", status: "in_progress", tasks: filteredTasks)
                TaskColumn(title: "Done", status: "done", tasks: filteredTasks)
            }
            .padding()
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
        }
    }
}

struct TaskColumn: View {
    let title: String
    let status: String
    let tasks: [AgentTask]
    
    var filtered: [AgentTask] {
        tasks.filter { $0.status == status }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(filtered.count))")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { task in
                        TaskCard(task: task)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(minWidth: 250)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TaskCard: View {
    let task: AgentTask
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if !task.taskDescription.isEmpty {
                Text(task.taskDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                if let agent = task.assignedAgent {
                    Label(agent.capitalized, systemImage: "person")
                        .font(.caption2)
                }
                
                Label(task.project.capitalized, systemImage: "folder")
                    .font(.caption2)
                
                Spacer()
                
                Menu {
                    Button("Start") { updateStatus("in_progress") }
                    Button("Complete") { updateStatus("done") }
                    Button("Reset") { updateStatus("todo") }
                    Divider()
                    Button("Delete", role: .destructive) { delete() }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private func updateStatus(_ status: String) {
        task.status = status
        if status == "done" {
            task.completedAt = Date()
        }
    }
    
    private func delete() {
        modelContext.delete(task)
    }
}

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var project = "netmonitor"
    @State private var assignedAgent = "hermes"
    
    let projects = ["growwise", "netmonitor", "agentboard"]
    let agents = ["hermes", "claude", "codex"]
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description", text: $description, axis: .vertical)
                Picker("Project", selection: $project) {
                    ForEach(projects, id: \.self) { Text($0.capitalized) }
                }
                Picker("Assign to", selection: $assignedAgent) {
                    ForEach(agents, id: \.self) { Text($0.capitalized) }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let task = AgentTask(title: title, description: description, project: project, assignedAgent: assignedAgent)
                        modelContext.insert(task)
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

**Step 1:** Replace TaskBoardView.swift with the code above

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/TaskBoardView.swift
git commit -m "feat: build task board with agent assignment"
```

---

## Phase 5: Terminal Sessions (Claude Code / Codex)

### Task 7: Build tmux session manager

**Objective:** Create service to launch and capture tmux sessions running Claude Code or Codex CLI

**Files:**
- Create: `AgentBoard/Services/TmuxSessionManager.swift`

```swift
// Services/TmuxSessionManager.swift
import Foundation

@MainActor
@Observable
final class TmuxSessionManager {
    var sessions: [TmuxSession] = []
    
    struct TmuxSession: Identifiable {
        let id: String // tmux session name
        let name: String // display name
        let agent: String // "claude" or "codex"
        let project: String
        let createdAt: Date
        var isActive: Bool = true
        var output: String = ""
    }
    
    func launchSession(name: String, agent: String, project: String, task: String) async {
        let sessionName = "\(agent)-\(project)-\(Int(Date().timeIntervalSince1970))"
        let projectPath = expandPath("~/Projects/\(project.capitalized)")
        
        // Create tmux session
        await runCommand("/opt/homebrew/bin/tmux", args: [
            "new-session", "-d", "-s", sessionName,
            "-c", projectPath
        ])
        
        // Send the agent command
        let command: String
        switch agent {
        case "claude":
            command = "claude \"\(task)\""
        case "codex":
            command = "codex \"\(task)\""
        default:
            command = "echo 'Unknown agent'"
        }
        
        await runCommand("/opt/homebrew/bin/tmux", args: [
            "send-keys", "-t", sessionName, command, "Enter"
        ])
        
        let session = TmuxSession(
            id: sessionName,
            name: name,
            agent: agent,
            project: project,
            createdAt: Date()
        )
        sessions.append(session)
    }
    
    func captureOutput(sessionId: String) async -> String {
        let result = await runCommandWithOutput("/opt/homebrew/bin/tmux", args: [
            "capture-pane", "-t", sessionId, "-p"
        ])
        return result
    }
    
    func attachSession(_ sessionId: String) async {
        // This would open a terminal window attached to the session
        await runCommand("/usr/bin/open", args: [
            "-a", "Terminal",
            "tmux", "attach-session", "-t", sessionId
        ])
    }
    
    func killSession(_ sessionId: String) async {
        await runCommand("/opt/homebrew/bin/tmux", args: [
            "kill-session", "-t", sessionId
        ])
        sessions.removeAll { $0.id == sessionId }
    }
    
    func refreshOutput() async {
        for i in sessions.indices {
            sessions[i].output = await captureOutput(sessionId: sessions[i].id)
        }
    }
    
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return NSString(string: path).expandingTildeInPath
        }
        return path
    }
    
    private func runCommand(_ executable: String, args: [String]) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        try? process.run()
        process.waitUntilExit()
    }
    
    private func runCommandWithOutput(_ executable: String, args: [String]) async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
```

**Step 1:** Create the file with the code above

**Step 2:** Build to verify

**Step 3:** Commit

```bash
git add AgentBoard/Services/TmuxSessionManager.swift
git commit -m "feat: add tmux session manager for Claude Code and Codex"
```

### Task 8: Build the terminal view

**Objective:** Create a view to manage and watch tmux sessions

**Files:**
- Modify: `AgentBoard/Views/TerminalView.swift`

```swift
// TerminalView.swift
import SwiftUI

struct TerminalView: View {
    @State private var sessionManager = TmuxSessionManager()
    @State private var showingLaunchSheet = false
    @State private var selectedSession: TmuxSessionManager.TmuxSession?
    
    var body: some View {
        NavigationSplitView {
            // Session list
            List(selection: $selectedSession) {
                Section("Active Sessions") {
                    ForEach(sessionManager.sessions.filter { $0.isActive }) { session in
                        SessionRow(session: session)
                            .tag(session)
                            .contextMenu {
                                Button("Attach in Terminal") {
                                    Task {
                                        await sessionManager.attachSession(session.id)
                                    }
                                }
                                Button("Kill", role: .destructive) {
                                    Task {
                                        await sessionManager.killSession(session.id)
                                    }
                                }
                            }
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                Button("New Session") {
                    showingLaunchSheet = true
                }
            }
        } detail: {
            if let session = selectedSession {
                SessionDetailView(session: session, sessionManager: sessionManager)
            } else {
                Text("Select a session")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingLaunchSheet) {
            LaunchSessionView(sessionManager: sessionManager)
        }
    }
}

struct SessionRow: View {
    let session: TmuxSessionManager.TmuxSession
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(session.name)
                .font(.headline)
            HStack {
                Label(session.agent.capitalized, systemImage: "terminal")
                Label(session.project.capitalized, systemImage: "folder")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

struct SessionDetailView: View {
    let session: TmuxSessionManager.TmuxSession
    let sessionManager: TmuxSessionManager
    @State private var output = ""
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(session.name)
                        .font(.title2)
                    Text("\(session.agent.capitalized) • \(session.project.capitalized)")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        output = await sessionManager.captureOutput(sessionId: session.id)
                    }
                }
                
                Button("Attach") {
                    Task {
                        await sessionManager.attachSession(session.id)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Output
            ScrollView {
                Text(output.isEmpty ? "No output yet..." : output)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .task {
            output = await sessionManager.captureOutput(sessionId: session.id)
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                output = await sessionManager.captureOutput(sessionId: session.id)
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct LaunchSessionView: View {
    let sessionManager: TmuxSessionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var agent = "claude"
    @State private var project = "netmonitor"
    @State private var task = ""
    
    let agents = ["claude", "codex"]
    let projects = ["growwise", "netmonitor", "agentboard"]
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Session Name", text: $name)
                Picker("Agent", selection: $agent) {
                    ForEach(agents, id: \.self) { Text($0.capitalized) }
                }
                Picker("Project", selection: $project) {
                    ForEach(projects, id: \.self) { Text($0.capitalized) }
                }
                TextField("Task description", text: $task, axis: .vertical)
            }
            .navigationTitle("Launch Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Launch") {
                        Task {
                            await sessionManager.launchSession(
                                name: name.isEmpty ? "\(agent)-\(project)" : name,
                                agent: agent,
                                project: project,
                                task: task
                            )
                            dismiss()
                        }
                    }
                    .disabled(task.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 350)
    }
}
```

**Step 1:** Replace TerminalView.swift with the code above

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/TerminalView.swift
git commit -m "feat: build terminal session view with live tmux output"
```

---

## Phase 6: Telegram Integration for Chat

### Task 9: Integrate chat with Telegram bot

**Objective:** Connect the chat view to actually send/receive messages via the Telegram bot

**Files:**
- Create: `AgentBoard/Services/TelegramService.swift`
- Modify: `AgentBoard/Views/ChatView.swift` (connect to service)

```swift
// Services/TelegramService.swift
import Foundation

@MainActor
@Observable
final class TelegramService {
    var botToken: String = ""
    var chatId: String = ""
    var isPolling = false
    var lastUpdateId: Int = 0
    
    init() {
        loadTokenFromKeychain()
    }
    
    private func loadTokenFromKeychain() {
        // Load from 1Password via CLI or stored preference
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/op")
        process.arguments = [
            "item", "get", "Telegram token",
            "--vault", "Daneel",
            "--fields", "credential",
            "--format", "json"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["value"] as? String {
                botToken = token
            }
        } catch {
            print("Failed to load token: \(error)")
        }
    }
    
    func sendMessage(_ text: String) async {
        guard !botToken.isEmpty, !chatId.isEmpty else { return }
        
        let url = URL(string: "https://api.telegram.org/bot\(botToken)/sendMessage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "HTML"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                print("Telegram send failed: \(httpResponse.statusCode)")
            }
        } catch {
            print("Telegram error: \(error)")
        }
    }
    
    func pollForUpdates() async -> [(String, Bool)] {
        guard !botToken.isEmpty else { return [] }
        
        let urlString = "https://api.telegram.org/bot\(botToken)/getUpdates?offset=\(lastUpdateId + 1)&timeout=1"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["ok"] as? Bool == true,
                  let result = json["result"] as? [[String: Any]] else {
                return []
            }
            
            var messages: [(String, Bool)] = []
            
            for update in result {
                guard let updateId = update["update_id"] as? Int,
                      let message = update["message"] as? [String: Any],
                      let text = message["text"] as? String,
                      let from = message["from"] as? [String: Any],
                      let fromId = from["id"] as? Int else {
                    continue
                }
                
                lastUpdateId = max(lastUpdateId, updateId)
                
                // Check if it's from the authorized user
                if chatId.isEmpty {
                    chatId = String(fromId)
                }
                
                if fromId == Int(chatId) {
                    messages.append((text, false)) // false = from bot/agent
                }
            }
            
            return messages
        } catch {
            print("Poll error: \(error)")
            return []
        }
    }
}
```

**Step 1:** Create TelegramService.swift with the code above

**Step 2:** Update ChatView.swift to use TelegramService:

```swift
// Add to ChatView.swift
@State private var telegramService = TelegramService()

// Replace the TODO in sendMessage():
private func sendMessage() {
    guard !inputText.isEmpty else { return }
    
    let userMessage = ChatMessage(content: inputText, isFromUser: true, agent: selectedAgent)
    modelContext.insert(userMessage)
    
    let text = inputText
    inputText = ""
    
    if selectedAgent == "hermes" {
        Task {
            await telegramService.sendMessage(text)
            // Response will come via polling
        }
    } else {
        // For claude/codex, launch a terminal session
        Task {
            try? await Task.sleep(for: .seconds(1))
            let response = ChatMessage(content: "Launch \(selectedAgent) session with: \(text)", isFromUser: false, agent: selectedAgent)
            modelContext.insert(response)
        }
    }
}

// Add polling task
.task {
    while true {
        try? await Task.sleep(for: .seconds(2))
        let updates = await telegramService.pollForUpdates()
        for (text, isFromUser) in updates {
            let message = ChatMessage(content: text, isFromUser: isFromUser, agent: selectedAgent)
            modelContext.insert(message)
        }
    }
}
```

**Step 3:** Build and verify

**Step 4:** Commit

```bash
git add AgentBoard/Services/TelegramService.swift AgentBoard/Views/ChatView.swift
git commit -m "feat: integrate chat with Telegram bot API"
```

---

## Summary

**Total Tasks:** 9
**Estimated Time:** 4-6 hours for full implementation
**Dependencies:** macOS 15+, Xcode 16+, `gh` CLI, `tmux`, `op` (1Password CLI)

**Key Files Created:**
- `AgentBoardApp.swift` - App entry
- `Models/ChatMessage.swift` - Chat data
- `Models/Task.swift` - Task data  
- `Services/GitHubService.swift` - GitHub integration
- `Services/TelegramService.swift` - Telegram bot
- `Services/TmuxSessionManager.swift` - Terminal sessions
- `Views/ChatView.swift` - Chat UI
- `Views/KanbanView.swift` - Issues board
- `Views/TaskBoardView.swift` - Task board
- `Views/TerminalView.swift` - Session viewer

**Next Steps After Implementation:**
1. Add drag-and-drop to Kanban (`.onDrag`/`.onDrop`)
2. Add notifications for new messages
3. Add session persistence
4. Add dark/light theme toggle
5. Add keyboard shortcuts

---

*Plan saved to `docs/plans/agent-command-center-implementation.md`*