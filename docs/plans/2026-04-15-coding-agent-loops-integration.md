# AgentBoard + Coding Agent Loops Integration Plan

> **Goal:** Align AgentBoard fully with the coding-agent-loops skill for PRD-based workflows with ralphy retry loops.

**Current Status:**
- ✅ ralphy-cli installed (v4.7.2)
- ✅ Stable tmux socket at `~/.tmux/sock`
- ✅ SessionMonitor uses ralphy with completion hooks
- ❌ PRD-based workflows not supported
- ❌ Issue → PRD conversion missing
- ❌ UI for launching PRD sessions needed

---

## Integration Design

### 1. PRD Format in AgentBoard Issues

**Convert issues to markdown checklists for ralphy:**

```markdown
# Issue #177: Coverage below target

## Description
NetMonitorCore coverage is at 60.01% vs 70% target.

## Tasks
- [ ] Add DashboardViewModel tests
- [ ] Add ToolViewModel tests  
- [ ] Add service integration tests
- [ ] Update coverage script
- [ ] Verify coverage reaches 70%

## Context
Current coverage: 60.01%
Target: 70%
Gap: 9.99%
```

### 2. Issue → PRD Conversion

**Add to issue detail sheet:**
- "Launch PRD Session" button
- Auto-generates PRD.md from issue description
- Creates tasks from issue comments or subtasks
- Launches ralphy with `--prd PRD.md`

### 3. Session Launch with PRD

**Enhanced SessionLauncher:**
```swift
func launchPRDSession(
    issue: Bead,
    agent: String,  // "claude" or "codex"
    project: String
) async {
    // 1. Generate PRD.md from issue
    let prdContent = generatePRD(from: issue)
    let prdPath = savePRD(content: prdContent, for: issue)
    
    // 2. Launch ralphy with PRD
    await sessionManager.launchSession(
        name: "\(agent)-issue-\(issue.number)",
        agent: agent,
        project: project,
        task: "--prd \(prdPath)"
    )
}
```

### 4. PRD Generation from Issue

**Generate markdown checklist:**
- Main task from issue title
- Subtasks from:
  - Issue body (extract checkboxes)
  - Issue comments (action items)
  - Related subtasks (if using Epic > Tasks)
  - AI-generated breakdown

### 5. Session Completion Tracking

**When ralphy completes:**
- Completion hook fires: `openclaw system event`
- AgentBoard receives wake event
- UI updates: session shows "Completed"
- Issue can be auto-closed or moved to review

---

## Implementation Tasks

### Task 1: Add PRD Generation to Issue Detail Sheet

**Objective:** Create "Launch PRD Session" button that generates PRD from issue

**Files:**
- Modify: `AgentBoard/Views/Board/TaskDetailSheet.swift`

**Implementation:**
```swift
@State private var showingPRDLauncher = false

// In issue detail view
Button("Launch PRD Session") {
    showingPRDLauncher = true
}
.sheet(isPresented: $showingPRDLauncher) {
    PRDLauncherSheet(issue: issue)
}

// New PRD Launcher Sheet
struct PRDLauncherSheet: View {
    let issue: Bead
    @State private var selectedAgent = "claude"
    @State private var generatedPRD = ""
    @State private var isLaunching = false
    
    var body: some View {
        VStack {
            // Agent picker
            Picker("Agent", selection: $selectedAgent) {
                Text("Claude Code").tag("claude")
                Text("Codex").tag("codex")
            }
            
            // PRD preview
            ScrollView {
                Text(generatedPRD)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            
            // Launch button
            Button("Launch Session") {
                launchPRDSession()
            }
            .disabled(isLaunching)
        }
        .onAppear {
            generatedPRD = generatePRD(from: issue)
        }
    }
}
```

**Step 1:** Create the PRD generation function

**Step 2:** Add UI for PRD preview and editing

**Step 3:** Integrate with SessionMonitor for launching

**Step 4:** Build and test

**Step 5:** Commit

---

### Task 2: Create PRD Generator Service

**Objective:** Convert issues to PRD markdown format

**Files:**
- Create: `AgentBoard/Services/PRDGenerator.swift`

**Implementation:**
```swift
import Foundation

@MainActor
@Observable
final class PRDGenerator {
    
    func generatePRD(from issue: Bead) -> String {
        var prd = ""
        
        // Title
        prd += "# \(issue.title)\n\n"
        
        // Description
        if let body = issue.body, !body.isEmpty {
            prd += "## Description\n\n\(body)\n\n"
        }
        
        // Context
        prd += "## Context\n\n"
        prd += "- Issue: #\(issue.number)\n"
        prd += "- Project: \(issue.project)\n"
        if let priority = issue.priority {
            prd += "- Priority: \(priority)\n"
        }
        prd += "\n"
        
        // Tasks (from subtasks or generated)
        let tasks = extractTasks(from: issue)
        if !tasks.isEmpty {
            prd += "## Tasks\n\n"
            for task in tasks {
                prd += "- [ ] \(task)\n"
            }
            prd += "\n"
        }
        
        // Acceptance criteria
        prd += "## Acceptance Criteria\n\n"
        prd += "- [ ] All tests pass\n"
        prd += "- [ ] Code review completed\n"
        prd += "- [ ] No regressions introduced\n"
        prd += "\n"
        
        return prd
    }
    
    private func extractTasks(from issue: Bead) -> [String] {
        var tasks: [String] = []
        
        // Extract from issue body
        if let body = issue.body {
            let checkboxPattern = "- \\[ \\] (.+)"
            if let regex = try? NSRegularExpression(pattern: checkboxPattern) {
                let matches = regex.matches(in: body, range: NSRange(body.startIndex..., in: body))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: body) {
                        tasks.append(String(body[range]))
                    }
                }
            }
        }
        
        // Extract from comments
        // (would need to fetch comments from GitHub)
        
        // If no tasks found, generate from title
        if tasks.isEmpty {
            tasks.append(issue.title)
        }
        
        return tasks
    }
    
    func savePRD(content: String, for issue: Bead) -> String {
        let filename = "PRD-\(issue.number).md"
        let tempDir = FileManager.default.temporaryDirectory
        let prdPath = tempDir.appendingPathComponent(filename)
        
        try? content.write(to: prdPath, atomically: true, encoding: .utf8)
        
        return prdPath.path
    }
}
```

**Step 1:** Create PRDGenerator with extraction logic

**Step 2:** Add checkbox parsing from issue body

**Step 3:** Add PRD file saving

**Step 4:** Build and test

**Step 5:** Commit

---

### Task 3: Update SessionLauncher to Support PRD

**Objective:** Launch ralphy with --prd flag

**Files:**
- Modify: `AgentBoard/Views/Sessions/SessionLauncher.swift`

**Implementation:**
```swift
// Add PRD support to SessionLauncher
struct SessionLauncher: View {
    let issue: Bead
    let agent: String
    @State private var sessionManager = TmuxSessionManager()
    @State private var prdGenerator = PRDGenerator()
    @State private var launchMode: LaunchMode = .simple
    @State private var isLaunching = false
    
    enum LaunchMode {
        case simple
        case prd
    }
    
    var body: some View {
        VStack {
            Picker("Launch Mode", selection: $launchMode) {
                Text("Simple Task").tag(LaunchMode.simple)
                Text("PRD Workflow").tag(LaunchMode.prd)
            }
            .pickerStyle(.segmented)
            
            Button("Start \(agent.capitalized) Session") {
                launchSession()
            }
            .disabled(isLaunching)
        }
    }
    
    private func launchSession() {
        isLaunching = true
        
        Task {
            let task: String
            
            switch launchMode {
            case .simple:
                task = """
                Working on issue #\(issue.number): \(issue.title)
                
                \(issue.body ?? "")
                """
                
            case .prd:
                let prdContent = prdGenerator.generatePRD(from: issue)
                let prdPath = prdGenerator.savePRD(content: prdContent, for: issue)
                task = "--prd \(prdPath)"
            }
            
            await sessionManager.launchSession(
                name: "\(agent)-issue-\(issue.number)",
                agent: agent,
                project: issue.project,
                task: task
            )
            
            // Link session to issue
            issue.activeSessionId = sessionManager.sessions.last?.id
            
            isLaunching = false
        }
    }
}
```

**Step 1:** Add launch mode picker (Simple vs PRD)

**Step 2:** Generate PRD and save to temp file

**Step 3:** Launch with --prd flag

**Step 4:** Build and test

**Step 5:** Commit

---

### Task 4: Add Session Completion Notifications

**Objective:** Notify when ralphy completes via openclaw system event

**Files:**
- Modify: `AgentBoard/Services/SessionMonitor.swift`

**Implementation:**
```swift
// Add completion notification handling
private func handleSessionCompletion(sessionName: String, exitCode: Int) {
    // Parse session name to extract issue number
    if let issueNumber = extractIssueNumber(from: sessionName) {
        // Update issue status
        notifyIssueCompletion(issueNumber: issueNumber, exitCode: exitCode)
        
        // Send Telegram notification
        Task {
            await AgentNotificationService().notifyCompletion(
                agent: extractAgent(from: sessionName),
                task: Bead(/* ... */)
            )
        }
    }
}

private func extractIssueNumber(from sessionName: String) -> Int? {
    // Parse "claude-issue-177" → 177
    let pattern = ".*-issue-(\\d+)"
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: sessionName, range: NSRange(sessionName.startIndex..., in: sessionName)),
       let range = Range(match.range(at: 1), in: sessionName) {
        return Int(sessionName[range])
    }
    return nil
}

private func extractAgent(from sessionName: String) -> String {
    // Parse "claude-issue-177" → "claude"
    return String(sessionName.split(separator: "-").first ?? "unknown")
}
```

**Step 1:** Add completion handler in SessionMonitor

**Step 2:** Parse session name for issue number

**Step 3:** Update issue status and send notifications

**Step 4:** Build and test

**Step 5:** Commit

---

### Task 5: Add PRD Status Tracking to Issues

**Objective:** Show PRD checklist completion in issue cards

**Files:**
- Modify: `AgentBoard/Views/Board/TaskCardView.swift`

**Implementation:**
```swift
// Add PRD progress indicator
struct TaskCardView: View {
    let issue: Bead
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing card content
            
            // PRD progress (if session was launched)
            if let prdProgress = calculatePRDProgress() {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(.secondary)
                    
                    ProgressView(value: prdProgress)
                        .tint(prdProgress == 1.0 ? .green : .accentColor)
                    
                    Text("\(Int(prdProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func calculatePRDProgress() -> Double? {
        // Check if issue has been worked on with PRD
        // Would need to track PRD completion state
        return nil
    }
}
```

**Step 1:** Add PRD progress indicator to cards

**Step 2:** Calculate completion percentage

**Step 3:** Update UI when tasks completed

**Step 4:** Build and test

**Step 5:** Commit

---

## Summary

**Total Tasks:** 5
**Estimated Time:** 2-3 hours
**Focus:** Full integration with coding-agent-loops workflow

**Key Features:**
- Generate PRD.md from issues automatically
- Launch ralphy with --prd for retry loops
- Track PRD checklist completion
- Notify on completion via openclaw system event
- Visual progress indicators in issue cards

**Result:** AgentBoard becomes a complete coding agent command center with reliable, self-healing sessions and PRD-based workflows.