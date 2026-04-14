# AgentBoard Reliability & Polish Improvement Plan

> **Goal:** Fix the instability issues, polish the UI, and add missing workflow features without rebuilding what works.

**Key Pain Points:**
1. Chat interface looks blocky, unclear which session is active
2. GitHub issues integration unstable since migration from Beads
3. Missing features for daily planning and software creation workflows

---

## Phase 1: GitHub Issues Reliability

### Problem: GitHub integration is unstable

**Root causes to investigate:**
- Rate limiting not handled gracefully
- Error states not surfacing clearly to user
- Network failures causing silent failures
- Label/status mapping might be inconsistent

### Task 1: Audit GitHubIssuesService error handling

**Objective:** Identify and fix reliability issues in the existing GitHub integration

**Files:**
- Read: `AgentBoard/Services/GitHubIssuesService.swift`
- Read: `AgentBoard/Models/Bead.swift` (check status mapping)
- Read: `AgentBoard/Views/Board/BoardView.swift` (check error display)

**Step 1:** Review current error handling

Check if these are handled:
- Network timeouts
- Rate limiting (GitHub allows 5000 requests/hour authenticated)
- Invalid tokens
- Repository not found
- Malformed responses

**Step 2:** Add retry logic with exponential backoff

```swift
// Add to GitHubIssuesService
private func fetchWithRetry<T>(
    maxRetries: Int = 3,
    delay: TimeInterval = 1.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    for attempt in 1...maxRetries {
        do {
            return try await operation()
        } catch let error as GitHubError {
            // Don't retry auth errors
            if error == .unauthorized || error == .notFound {
                throw error
            }
            // Retry rate limits and network errors
            if attempt < maxRetries {
                try await Task.sleep(for: .seconds(delay * Double(attempt)))
                continue
            }
            throw error
        } catch {
            if attempt < maxRetries {
                try await Task.sleep(for: .seconds(delay * Double(attempt)))
                continue
            }
            throw error
        }
    }
    fatalError("Unreachable")
}
```

**Step 3:** Add user-visible error states

```swift
// Add to AppState
@Published var githubError: String?
@Published var isGitHubLoading = false

// Wrap all GitHub calls
func loadGitHubIssues() async {
    isGitHubLoading = true
    githubError = nil
    
    do {
        // existing fetch logic
    } catch {
        githubError = error.localizedDescription
    }
    
    isGitHubLoading = false
}
```

**Step 4:** Add error banner to BoardView

```swift
// Add to BoardView.swift
if let error = appState.githubError {
    HStack {
        Image(systemName: "exclamationmark.triangle")
        Text(error)
            .lineLimit(2)
        Spacer()
        Button("Retry") {
            Task { await appState.loadGitHubIssues() }
        }
    }
    .padding(8)
    .background(Color.red.opacity(0.1))
    .cornerRadius(8)
}
```

**Step 5:** Commit

```bash
git add -A
git commit -m "fix: improve GitHub issues reliability with retry logic and error states"
```

### Task 2: Add GitHub connection health check

**Objective:** Show clear status of GitHub connection in the UI

**Files:**
- Modify: `AgentBoard/Views/Sidebar/SidebarView.swift`

```swift
// Add connection status indicator
@ViewBuilder
var githubStatusIndicator: some View {
    HStack {
        Circle()
            .fill(appState.githubError != nil ? Color.red : Color.green)
            .frame(width: 8, height: 8)
        
        if appState.isGitHubLoading {
            ProgressView()
                .scaleEffect(0.5)
        }
        
        Text(appState.githubError != nil ? "GitHub Error" : "GitHub Connected")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.ultraThinMaterial)
    .cornerRadius(6)
}
```

**Step 1:** Add the status indicator to sidebar

**Step 2:** Commit

```bash
git commit -m "feat: add GitHub connection status indicator to sidebar"
```

---

## Phase 2: Chat Interface Polish

### Problem: Chat looks blocky, unclear which session

### Task 3: Redesign chat message bubbles

**Objective:** Modernize chat UI with clearer visual hierarchy

**Files:**
- Modify: `AgentBoard/Views/Chat/ChatPanelView.swift`

```swift
// Improved message bubble design
struct ChatBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 60) }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender label
                Text(message.senderDisplayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                // Message content
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isCurrentUser
                            ? AnyShapeStyle(Color.accentColor.gradient)
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            }
            
            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
}
```

**Step 1:** Replace existing bubble implementation

**Step 2:** Commit

```bash
git commit -m "ui: modernize chat bubbles with better spacing and shadows"
```

### Task 4: Add clear session context header

**Objective:** Always show which session/agent you're talking to

**Files:**
- Modify: `AgentBoard/Views/Chat/ChatPanelView.swift`

```swift
// Add persistent header at top of chat
struct ChatSessionHeader: View {
    let sessionName: String
    let agent: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionName)
                    .font(.headline)
                HStack {
                    Circle()
                        .fill(isActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(agent.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Quick actions
            Button(action: { /* Open session details */ }) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
```

**Step 1:** Add header to chat panel

**Step 2:** Commit

```bash
git commit -m "feat: add clear session context header to chat"
```

---

## Phase 3: Missing Workflow Features

### Task 5: Add daily standup/planning view

**Objective:** Quick view of what's happening today across all projects

**Files:**
- Create: `AgentBoard/Views/Planning/DailyStandupView.swift`

```swift
import SwiftUI

struct DailyStandupView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Today's date
                Text(Date(), style: .date)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // In Progress section
                VStack(alignment: .leading, spacing: 8) {
                    Label("In Progress", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    ForEach(appState.beads.filter { $0.status == .inProgress }) { bead in
                        StandupItemRow(bead: bead)
                    }
                }
                
                // Blocked section
                if !appState.beads.filter({ $0.status == .blocked }).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Blocked", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        ForEach(appState.beads.filter { $0.status == .blocked }) { bead in
                            StandupItemRow(bead: bead)
                        }
                    }
                }
                
                // Ready to Start section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ready to Start", systemImage: "play.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    ForEach(appState.beads.filter { $0.status == .open }.prefix(5)) { bead in
                        StandupItemRow(bead: bead)
                    }
                }
            }
            .padding()
        }
    }
}

struct StandupItemRow: View {
    let bead: Bead
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bead.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Label(bead.project, systemImage: "folder")
                if let agent = bead.assignedAgent {
                    Label(agent, systemImage: "person")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}
```

**Step 1:** Create the file

**Step 2:** Add to navigation (maybe a new tab or sidebar section)

**Step 3:** Commit

```bash
git commit -m "feat: add daily standup planning view"
```

### Task 6: Add quick task creation from anywhere

**Objective:** Cmd+N to create a task from any view

**Files:**
- Modify: `AgentBoard/App/AppState.swift`

```swift
// Add keyboard shortcut handler
.onReceive(NotificationCenter.default.publisher(for: .createNewTask)) { _ in
    showingQuickCreate = true
}
```

**Step 1:** Add the shortcut

**Step 2:** Create QuickCreateTaskView (simplified task creation sheet)

**Step 3:** Commit

```bash
git commit -m "feat: add Cmd+N quick task creation shortcut"
```

---

## Summary

**Total Tasks:** 6
**Focus:** Reliability first, then polish, then missing features
**Estimated Time:** 2-3 hours

**Priority Order:**
1. Fix GitHub issues reliability (Tasks 1-2)
2. Polish chat interface (Tasks 3-4)  
3. Add workflow features (Tasks 5-6)

**Key Principles:**
- Fix what exists, don't rebuild
- Focus on daily pain points
- Add error handling everywhere
- Make current state always visible

---

*Save to: `docs/plans/agentboard-reliability-improvements.md`*