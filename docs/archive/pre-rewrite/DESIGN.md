# AgentBoard — Design Document

**Version:** 0.1 (Draft)
**Date:** 2026-02-14
**Author:** Blake Crane + R. Daneel Olivaw

## 1. Vision

AgentBoard is a **native macOS and iOS application** for managing AI-assisted software development. It combines a Kanban-style issue tracker (powered by GH Issues, a live coding agent session monitor, and a full-featured  Hermes chat interface wth session and profile switching

**The core insight:** Modern AI-assisted dev workflows involve three simultaneous activities — tracking work, communicating with agents, and reviewing agent output. Today these are spread across Terminal, browser, and various CLIs. AgentBoard unifies them into a single, purpose-built interface.

### Target User

Solo developers or small teams using Hermes Agent with coding agents (Claude Code, Codex CLI, OpenCode). The user manages multiple projects, spawns coding sessions, reviews agent work, and iterates through chat — all from one window.

### 3.3 Coding Session

Represents a running (or completed) coding agent session.
  - Invoked from left sidebar or within ticket. 
    - Options include :
            -Claude Code
            -Codex Cli
            -Opencode
  -  prompt can be preloaded with Ticket context, and workflow preset (Ralph Loop, Superpowers,  Custom)
  -session launches into swiftterm window taking over center board view
  - session can me minimized to left panel where it shows session name and a status indicatior
  -clicking on a session in the left panel casues it to expand over center bopard. 

##  MAC UI Design

###  Left Sidebar 

**Sections:**
1. **Projects** — List of configured projects with bead counts. Click to select. Source: user config file (`~/.agentboard/config.json`) listing project paths.

2. **Coding Sessions** — Live list of running/idle/completed coding agent sessions. Each shows:
   - Status dot (green=running, yellow=idle, gray=done, red=error)
   - Session name (truncated)
   - Elapsed time or status label
   - Click → expands to terminal view in center panel

3. **Views** — Navigation shortcuts: Board, Epics, History, Settings.

4. **Actions** — "+ New Session" button at bottom. Opens a sheet to configure and launch a new coding agent session.

###  Center Panel 

**Project Header:**
- Project name, live status badge
- "Plan" button (opens epic planning view)
- Stats: Open / In Progress / Total counts

**Tab Bar:**
- **Board** — Kanban columns: Open, In Progress, Blocked, Done
- **Agents** — Agent Task list 
- **History** — Timeline of recent bead changes, commits, session events

**Board View (default):**
- Four columns with colored headers
- Task cards show: bead ID, title, kind tag, date, agent indicator
- Drag-and-drop between columns (writes bead status via `bd` CLI)
- Right-click context menu: Edit, Assign to Agent, Start Session, Dependencies
- Filter bar: by kind, assignee, epic, label

**Terminal View (session expand):**
- When a coding session is clicked in the sidebar
- Full terminal emulator (SwiftTerm) showing tmux pane output
- Toolbar: session name, elapsed time, model, linked Issue, nudge, "Back to Board" button
- Can send keystrokes to the tmux session 


#### Chat Mode
- Standard chat interface connected to hermes gateway
- Messages stream via WebSocket (SSE fallback)

###  Session Linking

When AgentBoard launches a coding session, it:
1. Creates a tmux session with a known name pattern: `ab-<project>-<bead-id>`
2. Starts the coding agent with the GH ticket context as the prompt
3. Monitors the session via SessionMonitor
4. When the agent commits with GH ID in the message, updates the bead status

### Coding Session

Represents a running (or completed) coding agent session.
  - Invoked from left sidebar or within ticket. 
    - Options include :
            -Claude Code
            -Codex Cli
            -Opencode
  -  prompt can be preloaded with Ticket context, and workflow preset (Ralph Loop, Superpowers,  Custom)
  -session launches into swiftterm window taking over center board view
  - session can me minimized to left panel where it shows session name and a status indicatior
  -clicking on a session in the left panel casues it to expand over center bopard. 

---
