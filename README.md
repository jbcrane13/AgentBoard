# AgentBoard

A native macOS command center for AI-assisted software development.

[![macOS](https://img.shields.io/badge/macOS-15%2B-blue)]()
[![Swift](https://img.shields.io/badge/Swift-6.0-orange)]()
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## Screenshots

> Screenshots coming soon. To see AgentBoard in action, build from source and connect to an OpenClaw gateway.

<!--
![Board View](docs/screenshots/board.png)
![Chat + Canvas Split](docs/screenshots/split.png)
![Terminal View](docs/screenshots/terminal.png)
![Dark Mode](docs/screenshots/dark-mode.png)
-->

## What is AgentBoard?

Modern AI-assisted dev workflows involve three simultaneous activities: **tracking work**, **communicating with agents**, and **reviewing agent output**. Today these are spread across Terminal, browser, and various CLIs. AgentBoard unifies them into a single, purpose-built macOS interface.

## Features

### Kanban Board

View and manage issues powered by [Beads](https://github.com/nicobailon/beads), a git-backed issue tracker. Four columns — Open, In Progress, Blocked, Done — with drag-and-drop to move cards between statuses. Filter by kind (task, bug, feature, epic, chore), assignee, or epic. Create and edit issues with full metadata: title, description, kind, priority (P0–P4), assignee, labels, and epic linking. Right-click cards to edit, delete, assign to an agent, or view in terminal. Live filesystem watching via `BeadsWatcher` keeps the board in sync when agents commit changes externally.

### Epics

Dedicated epics view with progress bars showing child issue completion (e.g. "3/5"). Expandable disclosure groups list all child issues with status. Create new epics and link existing issues as children.

### Agent Chat

Full-featured chat connected to the [OpenClaw](https://github.com/nicobailon/openclaw) gateway via WebSocket JSON-RPC. Session picker dropdown to switch between gateway sessions. Streaming responses with animated typing indicator, abort button (red stop) during generation, and markdown rendering with syntax-highlighted fenced code blocks. Bead reference detection in assistant output links to board issues. Context bar shows selected bead and gateway session count. Right-click code blocks to open them in the canvas. Emoji picker for quick reactions.

### Coding Session Monitor

Live sidebar showing running coding agent sessions (Claude Code, Codex CLI, OpenCode). Status indicators (running, idle, stopped, error) with elapsed time. Click any session to view its terminal output in a read-only capture view with auto-refresh every 2 seconds. Nudge button sends Enter into the tmux session. Launch new sessions from the UI with project, agent type, linked bead ID, and optional seed prompt. Sessions run in tmux for persistence.

### Agents Dashboard

Table view of all local and remote agent sessions with columns for name, agent type, model, project, linked bead, status, elapsed time, token usage, and estimated cost. Aggregate stats at the top: sessions today, total tokens, estimated cost.

### Canvas

Rich content panel rendered in WKWebView. Supports markdown, HTML, images, code diffs, Mermaid diagrams, and terminal output. Agents push content via canvas directives in chat (`<!-- canvas:markdown -->...<!-- /canvas -->`). Users can drag-and-drop files, open via file picker, or paste images from clipboard. Toolbar includes history navigation (back/forward), zoom controls with percentage display, export, and clear. Content type label updates dynamically (Markdown, HTML, Image, Diff, Mermaid, Terminal).

### Split Mode

Right panel supports three modes via a segmented picker: Chat only, Canvas only, or Split. Split mode defaults to 60% canvas / 40% chat with a draggable divider. Collapse either panel by dragging to the edge. Double-click the divider to reset to the default ratio.

### History

Reverse-chronological event timeline with filters for project, event type (bead events, session events, commits), and date range (24h, 7d, 30d, all time). Events include bead creation/status changes, session starts/completions, and git commits.

### Git Integration

Task cards show latest commit SHA, branch name, and commit count badge for in-progress issues. Click a SHA to view the commit diff in the canvas. Bead IDs in commit messages are automatically linked.

### Dark Mode

Full dark mode support with adaptive theming via `AppTheme`. Sidebar stays dark in both light and dark themes. Cards, panels, and borders adapt automatically.

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New bead |
| `Cmd+Shift+N` | New coding session |
| `Cmd+1`–`Cmd+4` | Tab navigation (Board, Epics, Agents, History) |
| `Cmd+[` / `Cmd+]` | Canvas history back/forward |
| `Cmd+L` | Focus chat input |
| `Esc` | Back to board from terminal view |
| `Enter` | Send chat message |
| `Shift+Enter` | Newline in chat input |

### Notifications

Unread chat message badge in the right panel header. Session update badges for stopped/error transitions in the sidebar session list.

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 16.2+ with Swift 6.0
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (if regenerating the project file)
- An [OpenClaw](https://github.com/nicobailon/openclaw) gateway running (default: `ws://127.0.0.1:18789`)
- [Beads](https://github.com/nicobailon/beads) initialized in your project directories (for the Kanban board)
- tmux installed (for coding session management)

## Installation

### From Source (Xcode)

```bash
git clone https://github.com/nicobailon/AgentBoard.git
cd AgentBoard
open AgentBoard.xcodeproj
```

Build and run from Xcode (`Cmd+R`).

If you need to regenerate the Xcode project after editing `project.yml`:

```bash
brew install xcodegen  # if not already installed
xcodegen generate
```

### From Source (Command Line)

```bash
git clone https://github.com/nicobailon/AgentBoard.git
cd AgentBoard
xcodebuild -project AgentBoard.xcodeproj \
  -scheme AgentBoard \
  -destination 'platform=macOS' \
  build
```

The built app will be in `DerivedData/`. To build a release archive:

```bash
xcodebuild -project AgentBoard.xcodeproj \
  -scheme AgentBoard \
  -configuration Release \
  archive
```

### Running Tests

```bash
xcodebuild -project AgentBoard.xcodeproj \
  -scheme AgentBoard \
  -destination 'platform=macOS' \
  test
```

This runs both the unit tests (`AgentBoardTests`) and UI tests (`AgentBoardUITests`).

## Configuration

### Gateway Connection

AgentBoard connects to the OpenClaw gateway for chat and session management. By default it connects to `ws://127.0.0.1:18789`.

**Automatic discovery:** On launch, AgentBoard reads gateway configuration from `~/.openclaw/openclaw.json`:

```json
{
  "gateway": {
    "url": "ws://127.0.0.1:18789",
    "auth": {
      "token": "your-gateway-token"
    }
  }
}
```

**Manual configuration:** Switch to Manual mode in Settings and enter the gateway URL and auth token directly. Auth tokens are stored securely in the macOS Keychain.

### Remote Gateway Setup

AgentBoard supports connecting to an OpenClaw gateway running on a different machine. There are several ways to reach a remote gateway:

**LAN / Direct IP**

If the gateway machine is on the same network, use its LAN IP:

1. On the gateway machine, start OpenClaw with `gateway.bind` set to `"0.0.0.0"` (or the machine's LAN IP) in `~/.openclaw/openclaw.json`
2. In AgentBoard, open Settings, switch to Manual, and enter `http://<gateway-ip>:18789`
3. Click "Scan Network" to auto-discover gateways advertising via Bonjour/mDNS

**Tailscale / VPN**

With [Tailscale](https://tailscale.com) or another VPN, use the gateway machine's VPN IP:

```
http://100.x.y.z:18789
```

No port forwarding or firewall changes needed.

**SSH Tunnel**

Forward the gateway port over SSH for encrypted access without exposing ports:

```bash
ssh -L 18789:localhost:18789 user@gateway-host
```

Then connect to `http://127.0.0.1:18789` in AgentBoard as if the gateway were local.

**Device Pairing**

Each device must be approved by the gateway on first connection:

1. Connect to the gateway — AgentBoard will show a pairing guide if approval is needed
2. On the gateway machine, run the approval command shown in the guide (e.g. `openclaw devices approve <device-id>`)
3. Click "Retry Connection" in AgentBoard

Device identity is stored in `~/.agentboard/device-identity.json` (Ed25519 keypair generated on first launch).

**Token Security**

Gateway auth tokens are stored in the macOS Keychain, not in plain-text config files. When you save a token in Settings, it is written to Keychain and stripped from `~/.agentboard/config.json`. Existing plain-text tokens are automatically migrated to Keychain on first launch.

### Projects

AgentBoard auto-discovers projects by scanning a configured directory for folders containing a `.beads/` subfolder. The default scan directory is `~/Projects`. You can change it in the Settings view, or add individual project folders manually.

You can also provide a config file at `~/.agentboard/config.json`:

```json
{
  "projects": [
    {
      "name": "MyProject",
      "path": "~/Projects/MyProject",
      "icon": "🚀"
    }
  ]
}
```

### tmux Socket

Coding session monitoring uses the OpenClaw tmux socket at `/tmp/openclaw-tmux-sockets/openclaw.sock`. This is configurable in the app settings.

## Architecture

AgentBoard is a SwiftUI application with a three-panel layout:

```
┌───────────┬──────────────────────┬────────────────┐
│  Sidebar   │   Center Panel       │  Right Panel   │
│  (220pt)   │   (flexible)         │  (resizable)   │
│            │                      │                │
│  Projects  │  Board / Epics /     │  Chat          │
│  Sessions  │  Agents / History /  │  Canvas        │
│  Views     │  Terminal / Settings │  Split         │
└───────────┴──────────────────────┴────────────────┘
```

### Project Structure

```
AgentBoard/
├── App/
│   └── AppState.swift           # Central @Observable state
├── Models/
│   ├── AppConfig.swift           # Persisted app configuration
│   ├── Bead.swift                # Issue model (task, bug, feature, epic, chore)
│   ├── BeadDraft.swift           # Mutable draft for create/edit forms
│   ├── CanvasContent.swift       # Canvas render types (markdown, HTML, diff, diagram, image, terminal)
│   ├── ChatMessage.swift         # Chat message model with role, content, metadata
│   ├── CodingSession.swift       # tmux session model with agent type and status
│   ├── GitCommitRecord.swift     # Commit SHA, branch, message, bead linkage
│   ├── HistoryEvent.swift        # Timeline event model
│   ├── OpenClawConnectionState.swift  # Connection state enum
│   └── Project.swift             # Project model with path, icon, issue counts
├── Services/
│   ├── AppConfigStore.swift      # Config persistence and OpenClaw discovery
│   ├── BeadsWatcher.swift        # DispatchSource file watcher for issues.jsonl
│   ├── CanvasRenderer.swift      # WKWebView content rendering
│   ├── DeviceIdentity.swift      # Ed25519 device keypair for gateway pairing
│   ├── GatewayClient.swift       # WebSocket JSON-RPC client (connect, chat, sessions, events)
│   ├── GatewayDiscovery.swift    # Bonjour/mDNS gateway scanner
│   ├── GitService.swift          # Commit discovery and diff retrieval
│   ├── JSONLParser.swift         # JSONL file parser for beads
│   ├── KeychainService.swift     # Secure token storage
│   ├── OpenClawService.swift     # Thin actor wrapper around GatewayClient
│   └── SessionMonitor.swift      # tmux + process polling for agent sessions
├── Views/
│   ├── Board/                    # Kanban board, task cards, detail sheet, editor forms
│   ├── Canvas/                   # WKWebView canvas with toolbar and drag-drop
│   ├── Chat/                     # Chat panel with streaming, markdown bubbles, emoji picker
│   ├── Epics/                    # Epic cards with progress bars and child issues
│   ├── History/                  # Filterable event timeline
│   ├── Agents/                   # Agent session table with stats
│   ├── MainWindow/               # ContentView (layout), ProjectHeaderView
│   ├── RightPanel/               # Right panel mode switcher, split panel divider
│   ├── Settings/                 # Gateway config, project management, pairing guide
│   ├── Sidebar/                  # Project list, session list, views nav, new session sheet
│   └── Terminal/                 # Read-only terminal capture view
└── Resources/
    └── Assets.xcassets
```

### Key Services

| Service | Role |
|---------|------|
| `GatewayClient` | WebSocket JSON-RPC client for the OpenClaw gateway (chat, sessions, events) |
| `OpenClawService` | Thin actor wrapper around `GatewayClient` |
| `BeadsWatcher` | `DispatchSource` file watcher for `.beads/issues.jsonl` changes |
| `SessionMonitor` | tmux session + process tree polling for coding agent discovery |
| `CanvasRenderer` | WKWebView content rendering (markdown, HTML, diffs, Mermaid diagrams) |
| `GitService` | Commit discovery, bead-ID linkage, and diff retrieval |
| `GatewayDiscovery` | Bonjour/mDNS network scanner for remote gateways |
| `KeychainService` | Secure token storage in macOS Keychain |
| `DeviceIdentity` | Ed25519 keypair generation and persistence for device pairing |

### Dependencies

| Package | Purpose |
|---------|---------|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Terminal emulation |
| [swift-markdown](https://github.com/apple/swift-markdown) | Markdown parsing |

Both are managed via Swift Package Manager. No external databases — beads files on the filesystem are the source of truth.

## Contributing

Contributions are welcome. To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Read `DESIGN.md` for architecture context and `docs/ADR.md` for decision records
4. Build and test before committing:
   ```bash
   xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build
   xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test
   ```
5. Use [conventional commits](https://www.conventionalcommits.org/) for commit messages (e.g. `feat:`, `fix:`, `docs:`)
6. Open a pull request against `main`

## License

MIT License. See [LICENSE](LICENSE) for details.
