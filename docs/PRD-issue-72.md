# PRD: Implement Coding Agent Session Management (#72)

## Issue
#72 in jbcrane13/AgentBoard — implement coding agent session management

## Overview
Enable launching integrated coding sessions from within a ticket (IssueDetailSheet) or from the left sidebar. Sessions should render in a SwiftTerm terminal view taking over the center board panel, support minimize to sidebar, and click-to-expand from sidebar.

## Tasks

### 1. Add SwiftTerm as SPM dependency
- [ ] Add SwiftTerm package to `project.yml` under the AgentBoard target dependencies
- [ ] Run `xcodegen generate` to regenerate the Xcode project
- [ ] Verify the build compiles with SwiftTerm imported

### 2. Add AgentType enum to SessionLauncher
- [ ] Add `AgentType` enum: `.claude`, `.codex`, `.opencode` with icon, launch command, and display name
- [ ] Update `ExecutionPreset` to reference an `AgentType` instead of hardcoded string
- [ ] Add `.codexSuperpowers` preset that uses `.codex` agent
- [ ] Add `.opencodeSession` preset that uses `.opencode` agent
- [ ] Update `LaunchConfig` to include an `agentType: AgentType` field

### 3. Add "Launch Session" button to IssueDetailSheet
- [ ] Add a prominent "Launch Session" button in the IssueDetailSheet readView (after descriptionCard, before timelineCard)
- [ ] Tapping it creates an AgentTask from the WorkItem and opens LaunchSessionSheet
- [ ] Update LaunchSessionSheet to accept either an AgentTask OR a WorkItem directly (make task optional, add workItem parameter)
- [ ] When launched from IssueDetailSheet, pre-fill the repo name from the WorkItem's repository

### 4. Create TerminalView using SwiftTerm
- [ ] Create `AgentBoardUI/Screens/TerminalView.swift` — a macOS NSViewRepresentable wrapping `SwiftTerm.TerminalView`
- [ ] The view should:
  - Accept a tmux session name and socket path
  - Attach to an existing tmux session via the socket on appear
  - Display the terminal output in real-time
  - Support keyboard input to the attached tmux session
- [ ] On macOS, use `MacLocalTerminalView` or attach to a tmux session via `tmux -S <socket> attach -t <session>`
  - **IMPORTANT**: Since we're attaching to an already-running tmux session (launched by SessionLauncher), we need to use Process to run `tmux -S <socket> attach -t <name>` inside a PTY. The simplest approach: use SwiftTerm's `LocalProcess` to spawn a shell that runs `tmux attach`, OR use a simpler approach of showing session output via `tmux capture-pane` polling for a read-only view, with an option to "Open in Terminal.app" for full interactive control.
  - **Recommended MVP approach**: Use a polling `tmux capture-pane` approach to show session output in a ScrollView with monospace text, plus a "Open in Terminal.app" button that runs `open -a Terminal.app` with the tmux attach command. This is simpler and more reliable than embedding SwiftTerm directly.
- [ ] Create `AgentBoardUI/Screens/SessionTerminalView.swift` — the actual session terminal UI using the polling approach:
  - Shows session name, status badge, and elapsed time at the top
  - Shows tmux capture-pane output in a scrollable monospace view, refreshed every 3 seconds
  - Has a toolbar with: "Open in Terminal.app" button, "Refresh" button, "Stop Session" button
  - Has a "Minimize" button that returns to the Sessions screen

### 5. Wire session click in sidebar to open terminal view
- [ ] In DesktopRootView, add `@State private var activeSessionTerminal: SessionLauncher.ActiveSession?` 
- [ ] Make sidebar "LIVE SESSIONS" rows tappable — clicking a session row sets `activeSessionTerminal`
- [ ] In the centerPanel, when `activeSessionTerminal` is non-nil, show `SessionTerminalView` instead of the tab content
- [ ] Add a "minimize" / back button in SessionTerminalView that clears `activeSessionTerminal`
- [ ] Also track locally-launched sessions (from SessionLauncher.activeSessions) in the sidebar

### 6. Add SessionLauncher.activeSessions to sidebar
- [ ] In DesktopRootView sidebar "LIVE SESSIONS" section, also show sessions from `appModel.sessionLauncher.activeSessions`
- [ ] Merge companion sessions (from sessionsStore) with locally-launched sessions (from sessionLauncher)
- [ ] Show locally-launched sessions with their preset name and agent type
- [ ] Make locally-launched session rows tappable to open SessionTerminalView

### 7. Add "Quick Launch" button in sidebar
- [ ] Add a "+" button next to the "LIVE SESSIONS" header in the sidebar
- [ ] Tapping it opens LaunchSessionSheet with a blank configuration
- [ ] User picks a repo, agent type, and preset to launch

### 8. Add session status polling to SessionLauncher
- [ ] Add a timer-based polling method that checks tmux session status every 30 seconds
- [ ] When a session transitions from running → completed, update the activeSessions array
- [ ] Post a notification or callback so the UI can update
- [ ] Add a `startMonitoring()` method that begins the polling loop
- [ ] Call `startMonitoring()` after launching a session

## Constraints
- Swift 6 strict concurrency
- @Observable not ObservableObject
- accessibilityIdentifier on every interactive element
- macOS 26.0 deployment target
- All new files must be added to project.yml sources, then `xcodegen generate`

## Anti-Stall Rules
- Never wait for input. Never pause for confirmation. Keep moving.
- When done: commit, push to feature branch, STOP.
- Report: "DONE: [accomplished] | BLOCKED: [anything open]"
