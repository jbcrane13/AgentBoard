<div align="center">

# AgentBoard

**The command center for AI-assisted development.**

A native macOS app that unifies issue tracking, agent chat, and coding session monitoring into a single, purpose-built interface.

[![macOS](https://img.shields.io/badge/macOS-15%2B-007AFF?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-4A4A4A?style=flat-square)](LICENSE)
[![XcodeGen](https://img.shields.io/badge/XcodeGen-ready-00B4D8?style=flat-square)](https://github.com/yonaskolb/XcodeGen)

[Features](#features) • [Quick Start](#quick-start) • [Architecture](#architecture) • [Configuration](#configuration) • [Contributing](#contributing)

</div>

---

## The Problem

Modern AI-assisted development involves three simultaneous activities:

| Activity | Current Tools | Pain Point |
|----------|---------------|------------|
| **Track work** | Terminal + `bd` CLI | Scattered across windows |
| **Talk to agents** | Telegram/Discord/web | Switching contexts constantly |
| **Review output** | Browser + Terminal | No unified view of agent work |

**AgentBoard unifies all three.**

---

## Features

### 🎯 Kanban Board

Issue tracking powered by [Beads](https://github.com/nicobailon/beads) — a git-backed issue tracker.

- **Four columns:** Open, In Progress, Blocked, Done
- **Drag-and-drop** to move cards between statuses
- **Rich metadata:** title, description, kind (task/bug/feature/epic/chore), priority (P0–P4), assignee, labels, epic linking
- **Live sync:** filesystem watcher keeps the board in sync when agents commit changes externally
- **Context menu:** edit, delete, assign to agent, view in terminal

### 📊 Epics View

Track progress across related issues.

- Progress bars showing child issue completion (e.g., "3/5")
- Expandable disclosure groups listing all child issues
- Create new epics and link existing issues

### 💬 Agent Chat

Full-featured chat connected to [OpenClaw](https://github.com/nicobailon/openclaw) gateway.

- **Session picker:** switch between gateway sessions
- **Streaming responses** with typing indicator and abort button
- **Markdown rendering** with syntax-highlighted code blocks
- **Bead linking:** assistant messages auto-detect bead references
- **Thinking levels:** control reasoning depth (low/medium/high)

### 🖥️ Coding Session Monitor

Track running coding agent sessions in real time.

- **Status indicators:** running (green), idle (yellow), stopped (gray), error (red)
- **Session details:** agent type, model, project, linked bead, elapsed time
- **Terminal view:** read-only capture with auto-refresh
- **Nudge button:** send Enter to stuck sessions
- **Launch from UI:** configure project, agent, bead ID, and seed prompt

### 🤖 Agents Dashboard

Aggregate view of all agent sessions.

- **Columns:** name, agent type, model, project, bead, status, elapsed, tokens, cost
- **Stats:** sessions today, total tokens, estimated cost

### 🖼️ Canvas

Rich content panel for agent output.

- **Formats:** Markdown, HTML, images, code diffs, Mermaid diagrams, terminal output
- **Toolbar:** back/forward history, zoom controls, export
- **Drag-and-drop:** paste images or open files directly

### 🔀 Split Mode

Right panel supports three modes:

| Mode | Layout |
|------|--------|
| **Chat** | Full-height chat |
| **Canvas** | Full-height canvas |
| **Split** (default) | 60% canvas / 40% chat, resizable divider |

### 📜 History

Reverse-chronological event timeline.

- **Filters:** project, event type (bead events, session events, commits), date range
- **Events:** bead creation/status changes, session starts/completions, git commits

### 🔗 Git Integration

- Task cards show commit SHA, branch name, and commit count
- Click a SHA to view the diff in canvas
- Bead IDs in commit messages auto-linked

### ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New bead |
| `Cmd+Shift+N` | New coding session |
| `Cmd+1`–`Cmd+4` | Tab navigation |
| `Cmd+[` / `Cmd+]` | Canvas history back/forward |
| `Cmd+L` | Focus chat input |
| `Esc` | Back to board from terminal |
| `Enter` | Send chat message |
| `Shift+Enter` | Newline in chat |

### 🌙 Dark Mode

Full dark mode support with adaptive theming. Sidebar stays dark in both modes.

---

## Quick Start

### Prerequisites

- macOS 15 (Sequoia) or later
- Xcode 16.2+ with Swift 6.0
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [Beads](https://github.com/nicobailon/beads) (`brew install beads`)
- An [OpenClaw](https://github.com/nicobailon/openclaw) gateway running
- tmux (for coding session management)

### Build & Run

```bash
# Clone
git clone https://github.com/nicobailon/AgentBoard.git
cd AgentBoard

# Generate Xcode project (if needed)
xcodegen generate

# Open in Xcode
open AgentBoard.xcodeproj

# Or build from CLI
xcodebuild -project AgentBoard.xcodeproj \
  -scheme AgentBoard \
  -destination 'platform=macOS' \
  build
```

### First Launch

1. AgentBoard auto-discovers projects in `~/Projects` with `.beads/` directories
2. Configure your OpenClaw gateway in **Settings** (default: `ws://127.0.0.1:18789`)
3. Auth tokens are stored securely in macOS Keychain

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AgentBoard.app                           │
│                    (SwiftUI, macOS 15+)                         │
├─────────────┬──────────────────────┬────────────────────────────┤
│  Sidebar    │   Center Panel       │   Right Panel              │
│  (220pt)    │   (flexible)         │   (resizable)              │
│             │                      │                            │
│ • Projects  │ • Board (Kanban)     │ • Chat Mode                │
│ • Sessions  │ • Epics View         │ • Canvas Mode              │
│ • Views     │ • Agents View         │ • Split Mode               │
│ • Actions   │ • Terminal View      │                            │
│             │ • History View       │                            │
└──────┬──────┴──────────┬───────────┴──────────┬─────────────────┘
       │                 │                      │
       ▼                 ▼                      ▼
┌──────────────┐ ┌───────────────┐ ┌────────────────────────────┐
│ SessionMonitor│ │ BeadsWatcher  │ │ OpenClawService            │
│ (tmux/ps)    │ │ (FSEvents)    │ │ (WebSocket JSON-RPC)       │
└──────────────┘ └───────────────┘ └────────────────────────────┘
                         │                      │
                         ▼                      ▼
                  ┌──────────────┐    ┌─────────────────────┐
                  │ .beads/ dirs │    │ OpenClaw Gateway     │
                  │ (filesystem) │    │ ws://127.0.0.1:18789 │
                  └──────────────┘    └─────────────────────┘
```

### Project Structure

```
AgentBoard/
├── App/
│   └── AppState.swift           # @Observable central state
├── Models/
│   ├── AppConfig.swift           # Persisted configuration
│   ├── Bead.swift                # Issue model (task, bug, feature, epic)
│   ├── CanvasContent.swift       # Canvas render types
│   ├── ChatMessage.swift         # Chat message with streaming support
│   ├── CodingSession.swift       # tmux session model
│   └── Project.swift             # Project with bead counts
├── Services/
│   ├── AppConfigStore.swift      # Config persistence
│   ├── BeadsWatcher.swift        # DispatchSource file watcher
│   ├── CanvasRenderer.swift      # WKWebView content rendering
│   ├── DeviceIdentity.swift      # Ed25519 device keypair
│   ├── GatewayClient.swift       # WebSocket JSON-RPC client
│   ├── GitService.swift          # Commit discovery and diffs
│   └── SessionMonitor.swift      # tmux + process polling
├── Views/
│   ├── Board/                    # Kanban board and cards
│   ├── Canvas/                   # WKWebView canvas
│   ├── Chat/                    # Chat panel with streaming
│   ├── Epics/                   # Epic progress view
│   ├── History/                 # Event timeline
│   ├── Sidebar/                 # Project and session list
│   └── Terminal/                # SwiftTerm wrapper
└── Resources/
    └── Assets.xcassets
```

### Key Services

| Service | Role |
|---------|------|
| `GatewayClient` | WebSocket JSON-RPC client for OpenClaw gateway |
| `OpenClawService` | Actor wrapper around `GatewayClient` |
| `BeadsWatcher` | `DispatchSource` file watcher for `.beads/issues.jsonl` |
| `SessionMonitor` | tmux session + process tree polling |
| `CanvasRenderer` | WKWebView rendering (markdown, HTML, diffs, Mermaid) |
| `GitService` | Commit discovery, bead-ID linkage, diff retrieval |
| `KeychainService` | Secure token storage in macOS Keychain |

### Dependencies

| Package | Purpose |
|---------|---------|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Terminal emulation |
| [swift-markdown](https://github.com/apple/swift-markdown) | Markdown parsing |

Both managed via Swift Package Manager. No local database — beads files are the source of truth.

---

## Configuration

### Gateway Connection

AgentBoard connects to an OpenClaw gateway for chat and session management.

**Auto-discovery:** On launch, reads from `~/.openclaw/openclaw.json`:

```json
{
  "gateway": {
    "url": "ws://127.0.0.1:18789",
    "auth": { "token": "your-gateway-token" }
  }
}
```

**Manual configuration:** Switch to Manual mode in Settings and enter URL + token directly. Tokens are stored in macOS Keychain.

### Remote Gateway Setup

| Method | Configuration |
|--------|---------------|
| **LAN/Direct IP** | Set `gateway.bind: "0.0.0.0"` on gateway, connect to `http://<ip>:18789` |
| **Tailscale/VPN** | Use gateway's VPN IP: `http://100.x.y.z:18789` |
| **SSH Tunnel** | `ssh -L 18789:localhost:18789 user@host`, then connect locally |

### Projects

Projects are auto-discovered by scanning `~/Projects` for folders with `.beads/` subdirectories. Configure manually in Settings or via `~/.agentboard/config.json`:

```json
{
  "projects": [
    { "name": "NetMonitor-iOS", "path": "~/Projects/NetMonitor-iOS", "icon": "📡" },
    { "name": "AgentBoard", "path": "~/Projects/AgentBoard", "icon": "🎛️" }
  ]
}
```

### Device Pairing

Each device must be approved on first connection:

1. AgentBoard shows a pairing guide if approval is needed
2. Run `openclaw devices approve <device-id>` on the gateway machine
3. Click "Retry Connection" in AgentBoard

Device identity (Ed25519 keypair) is stored in `~/.agentboard/device-identity.json`.

---

## Development

### Running Tests

```bash
# Unit + UI tests
xcodebuild -project AgentBoard.xcodeproj \
  -scheme AgentBoard \
  -destination 'platform=macOS' \
  test

# Run specific test file
swift test --filter BoardViewTests
```

### Code Quality

```bash
# SwiftLint runs automatically as a build phase
# Manual run:
swiftlint lint

# SwiftFormat
swiftformat --lint .
```

### Project Generation

After editing `project.yml`:

```bash
xcodegen generate
```

**Never edit `project.pbxproj` directly** — it's regenerated from `project.yml`.

---

## Contributing

Contributions welcome! Here's how to get started:

1. **Fork** the repository
2. **Create a feature branch:** `git checkout -b feature/my-change`
3. **Read the docs:**
   - [`DESIGN.md`](DESIGN.md) — Architecture and decisions
   - [`docs/ADR.md`](docs/ADR.md) — Architecture Decision Records
4. **Build and test before committing:**
   ```bash
   xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard build test
   ```
5. **Use conventional commits:** `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
6. **Open a pull request** against `main`

### Code Style

- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`)
- SwiftUI with `@Observable` (not `@ObservableObject`)
- Actor-based services for thread safety
- No force unwraps (`!`) — use `guard`, `if let`, or `??`

---

## Roadmap

- [ ] **Direct Launch:** Launch coding agents from AgentBoard with bead context
- [ ] **Multi-window:** Detach terminal/canvas into separate windows
- [ ] **Cloud Sync:** Sync settings across devices via iCloud
- [ ] **Team Collaboration:** Multi-user support with presence
- [ ] **iOS Companion:** Read-only board on the go

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- [Beads](https://github.com/nicobailon/beads) — Git-backed issue tracking
- [OpenClaw](https://github.com/nicobailon/openclaw) — Agent gateway
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) — Terminal emulation
- [swift-markdown](https://github.com/apple/swift-markdown) — Markdown parsing

---

<div align="center">

**[Report a Bug](https://github.com/nicobailon/AgentBoard/issues/new?labels=bug)** • 
**[Request a Feature](https://github.com/nicobailon/AgentBoard/issues/new?labels=enhancement)** • 
**[Ask a Question](https://github.com/nicobailon/AgentBoard/discussions)**

</div>