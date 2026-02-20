# AgentBoard

A native macOS command center for AI-assisted software development.

[![macOS](https://img.shields.io/badge/macOS-15%2B-blue)]()
[![Swift](https://img.shields.io/badge/Swift-6-orange)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

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

**Kanban Board** — View and manage issues powered by [Beads](https://github.com/nicobailon/beads), a git-backed issue tracker. Drag cards between columns, create and edit issues, filter by kind/assignee/epic. Live filesystem watching keeps the board in sync when agents commit changes externally.

**OpenClaw Chat** — Full-featured chat connected to the [OpenClaw](https://github.com/nicobailon/openclaw) gateway via WebSocket JSON-RPC. Streaming responses, session switching, thinking level control, abort support, markdown rendering with syntax-highlighted code blocks, and bead context linking.

**Coding Session Monitor** — Live sidebar showing running coding agent sessions (Claude Code, Codex CLI, OpenCode). Click any session to view its terminal output. Launch new sessions from the UI with project, agent type, bead linking, and optional seed prompts. Sessions run in tmux for persistence.

**Canvas Panel** — Rich content area rendered in WKWebView. Supports markdown, HTML, code diffs, Mermaid diagrams, and images. Agents push content via canvas directives in chat; users can drag-and-drop files or paste from clipboard. History navigation, zoom, and export controls.

**Split Mode** — Default layout shows canvas (60%) and chat (40%) side by side with a draggable divider. Collapse either panel by dragging to the edge, or double-click to reset.

**Dark Mode** — Full dark mode support with adaptive theming. The sidebar stays dark in both themes.

**Keyboard Shortcuts** — `Cmd+N` new bead, `Cmd+Shift+N` new session, `Cmd+1-4` tab navigation, `Cmd+[`/`Cmd+]` canvas history, `Cmd+L` focus chat, `Esc` back to board from terminal view.

**Git Integration** — Task cards show latest commit SHA, branch name, and commit count. Click a SHA to view the diff in the canvas. Bead IDs in commit messages are automatically linked.

## Requirements

- macOS 15 (Sequoia) or later
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
│  (220pt)   │   (flexible)         │  (380pt)       │
│            │                      │                │
│  Projects  │  Board / Epics /     │  Chat          │
│  Sessions  │  Agents / History /  │  Canvas        │
│  Views     │  Terminal            │  Split         │
└───────────┴──────────────────────┴────────────────┘
```

**Key services:**

| Service | Role |
|---------|------|
| `GatewayClient` | WebSocket JSON-RPC client for the OpenClaw gateway |
| `OpenClawService` | Thin actor wrapper around `GatewayClient` |
| `BeadsWatcher` | Filesystem watcher for `.beads/issues.jsonl` changes |
| `SessionMonitor` | tmux + process polling for coding agent sessions |
| `CanvasRenderer` | WKWebView content rendering (markdown, HTML, diffs, diagrams) |
| `GitService` | Commit discovery and diff retrieval for task cards |

**Technology stack:** SwiftUI, URLSession WebSocket, WKWebView, Swift Package Manager. No external database — beads files on the filesystem are the source of truth.

## Contributing

Contributions are welcome. To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Read `DESIGN.md` for architecture context and `IMPLEMENTATION-PLAN.md` for the task breakdown
4. Build and test before committing:
   ```bash
   xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build
   xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test
   ```
5. Open a pull request

## License

MIT License. See [LICENSE](LICENSE) for details.
