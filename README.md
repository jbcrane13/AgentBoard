<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS_15+-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/UI-SwiftUI-007AFF?style=flat-square&logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/Version-0.1.0-orange?style=flat-square" alt="Version 0.1.0">
</p>

# AgentBoard

**A native macOS command center for AI-assisted software development.**

AgentBoard unifies the three core activities of working with coding agents — tracking work, communicating with agents, and reviewing agent output — into a single, purpose-built interface. No more switching between Terminal, browser, and CLI tools.

---

## Overview

Modern AI-assisted development involves juggling multiple tools simultaneously: a terminal for coding agent sessions, a browser for chat, a task tracker for issues, and a file browser for reviewing output. AgentBoard brings all of these into one cohesive macOS-native window.

```
┌─────────┬──────────────────────────────┬──────────────┐
│ Sidebar  │ Center Panel                 │ Right Panel  │
│          │                              │              │
│ Projects │  Kanban Board                │  Canvas      │
│ Sessions │  ┌──────┬──────┬──────┐      │  (Markdown,  │
│ Views    │  │ Open │ Prog │ Done │      │   Diffs,     │
│          │  │      │      │      │      │   Diagrams)  │
│          │  │ ░░░░ │ ░░░░ │ ░░░░ │      ├──────────────┤
│          │  │ ░░░░ │ ░░░░ │      │      │  Chat        │
│          │  └──────┴──────┴──────┘      │  (Agent)     │
└─────────┴──────────────────────────────┴──────────────┘
```

## Features

### Kanban Board
Track issues and tasks with a drag-and-drop board powered by [Beads](https://github.com/openclaw/beads). Four status columns — Open, In Progress, Blocked, and Done — with live updates from the filesystem. Cards display bead IDs, titles, kind tags, and agent indicators.

### Live Session Monitor
See all running coding agent sessions at a glance. Status indicators show whether sessions are running, idle, stopped, or errored. Click any session to open a full terminal view powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).

### Integrated Chat
Talk to your agents through a built-in chat panel connected to the OpenClaw gateway. Streaming responses, markdown rendering, code blocks, and bead context linking keep conversations tied to the work at hand.

### Canvas Panel
A rich content area for reviewing agent output. Supports rendered markdown, HTML previews, side-by-side diffs, Mermaid diagrams, and images. Content is auto-pushed from agent responses or manually added by the user.

### Split Mode
The default right-panel layout places the canvas (top 60%) and chat (bottom 40%) side by side with a resizable divider. Review what the agent is showing you while continuing the conversation.

### Multi-Project Support
Manage multiple projects from a single window. Each project maps to a git repository with a `.beads/` directory. Switch between projects instantly from the sidebar.

---

## Architecture

AgentBoard is built with Swift 6 and strict concurrency, targeting macOS 15 (Sequoia) and later.

| Component | Technology |
|---|---|
| UI Framework | SwiftUI |
| Terminal Emulator | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) |
| Rich Content | WKWebView |
| Markdown Parsing | [swift-markdown](https://github.com/apple/swift-markdown) |
| File Watching | DispatchSource / FSEvents |
| Networking | URLSession + WebSocket |
| State Management | `@Observable` (Swift Observation) |
| Data Layer | In-memory + filesystem (Beads as source of truth) |

### Three-Panel Layout

- **Sidebar** (220pt) — Projects, coding sessions, and navigation. Dark background following macOS conventions.
- **Center Panel** (flexible) — The primary workspace. Tabbed views for Board, Epics, Agents, and History.
- **Right Panel** (340pt) — Chat and canvas with three display modes: Chat, Canvas, or Split.

### Service Layer

```
AgentBoard.app
       │
       ├── SessionMonitor ──── tmux + process inspection
       ├── BeadsWatcher ────── .beads/ filesystem events
       └── OpenClawService ─── WebSocket + REST gateway
```

---

## Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16.2+
- Swift 6.0

### Optional (for full functionality)

- [Beads CLI](https://github.com/openclaw/beads) (`bd`) — Issue tracking backend
- [OpenClaw](https://github.com/openclaw) gateway — Chat and agent management
- A coding agent: [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Codex CLI, or OpenCode

---

## Getting Started

### Build from Source

```bash
git clone https://github.com/jbcrane13/AgentBoard.git
cd AgentBoard
open AgentBoard.xcodeproj
```

Build and run with Xcode, or from the command line:

```bash
xcodebuild build \
  -project AgentBoard.xcodeproj \
  -scheme AgentBoard \
  -destination 'platform=macOS'
```

### Configuration

AgentBoard looks for its configuration at `~/.agentboard/config.json`:

```json
{
  "projects": [
    {
      "name": "MyProject",
      "path": "~/Projects/MyProject",
      "icon": "📦"
    }
  ],
  "openClaw": {
    "gatewayUrl": "ws://127.0.0.1:18789",
    "authToken": null
  },
  "appearance": {
    "theme": "auto",
    "accentColor": "#ff9500"
  },
  "agents": {
    "defaultModel": "claude-opus-4-6",
    "defaultAgent": "claude-code"
  }
}
```

On first launch, AgentBoard scans `~/Projects/` for directories containing `.beads/` and auto-populates the project list.

---

## Project Structure

```
AgentBoard/
├── App/
│   ├── AgentBoardApp.swift        # Entry point
│   └── AppState.swift             # Observable root state
├── Models/
│   ├── Project.swift              # Project configuration
│   ├── Bead.swift                 # Issue/task model
│   ├── CodingSession.swift        # Agent session model
│   ├── ChatMessage.swift          # Chat message model
│   └── CanvasContent.swift        # Rich content types
├── Views/
│   ├── MainWindow/                # Three-panel layout
│   ├── Sidebar/                   # Project & session lists
│   ├── Board/                     # Kanban board
│   ├── Chat/                      # Chat interface
│   ├── Canvas/                    # Rich content renderer
│   └── RightPanel/                # Mode switcher
└── Resources/
    └── Assets.xcassets            # Colors & icons
```

---

## Design

AgentBoard follows a warm, focused visual language:

| Element | Value |
|---|---|
| Accent Color | `#ff9500` (warm orange) |
| Background | `#f5f5f0` (warm cream) |
| Sidebar | `#2c2c2e` (dark gray) |
| Cards | White with subtle shadow, 8px radius |
| Status Colors | Blue (open), Orange (in progress), Red (blocked), Green (done) |

Full design specification available in [`DESIGN.md`](DESIGN.md). Implementation roadmap in [`IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md).

---

## Roadmap

- [x] **Phase 1** — Skeleton & Layout (complete app shell, three-panel layout, navigation)
- [ ] **Phase 2** — Beads Integration (live Kanban board from filesystem)
- [ ] **Phase 3** — Chat Integration (OpenClaw gateway, streaming responses)
- [ ] **Phase 4** — Session Monitor (live agent sessions, terminal view)
- [ ] **Phase 5** — Canvas Panel (markdown, diffs, diagrams, images)
- [ ] **Phase 6** — Polish (dark mode, keyboard shortcuts, git integration)

---

## Contributing

AgentBoard is in early development. See [`AGENTS.md`](AGENTS.md) for coding agent instructions and [`IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md) for the phased task breakdown.

---

## License

MIT
