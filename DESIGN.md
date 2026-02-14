# AgentBoard — Design Document

**Version:** 0.1 (Draft)
**Date:** 2026-02-14
**Author:** Blake Crane + R. Daneel Olivaw

---

## 1. Vision

AgentBoard is a **native macOS application** for managing AI-assisted software development. It combines a Kanban-style issue tracker (powered by [Beads](https://github.com/openclaw/beads)), a live coding agent session monitor, and a full-featured OpenClaw chat interface with an integrated canvas for visual collaboration.

**The core insight:** Modern AI-assisted dev workflows involve three simultaneous activities — tracking work, communicating with agents, and reviewing agent output. Today these are spread across Terminal, browser, and various CLIs. AgentBoard unifies them into a single, purpose-built interface.

### Target User

Solo developers or small teams using OpenClaw with coding agents (Claude Code, Codex CLI, OpenCode). The user manages multiple projects, spawns coding sessions, reviews agent work, and iterates through chat — all from one window.

### Non-Goals (v1)

- Not a full IDE or code editor
- Not a replacement for Xcode/VS Code (complements them)
- Not a team collaboration tool (single-user focus for v1)
- Not a mobile app

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        AgentBoard.app                           │
│                    (SwiftUI, macOS 15+)                         │
├─────────────┬──────────────────────┬────────────────────────────┤
│  Sidebar    │   Center Panel       │   Right Panel              │
│             │                      │                            │
│ • Projects  │ • Board (Kanban)     │ • Chat Mode                │
│ • Sessions  │ • Epics View         │ • Canvas Mode              │
│ • Views     │ • Agents View        │ • Split Mode (both)        │
│ • Actions   │ • Terminal View      │                            │
│             │ • History View       │                            │
└──────┬──────┴──────────┬───────────┴──────────┬─────────────────┘
       │                 │                      │
       ▼                 ▼                      ▼
┌──────────────┐ ┌───────────────┐ ┌────────────────────────────┐
│ SessionMonitor│ │ BeadsWatcher  │ │ OpenClawService            │
│ (tmux/ps)    │ │ (FSEvents)    │ │ (WebSocket + REST)         │
└──────────────┘ └───────────────┘ └────────────────────────────┘
                         │                      │
                         ▼                      ▼
                  ┌──────────────┐    ┌─────────────────────┐
                  │ .beads/ dirs │    │ OpenClaw Gateway     │
                  │ (filesystem) │    │ ws://127.0.0.1:18789 │
                  └──────────────┘    └─────────────────────┘
```

### Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| UI Framework | SwiftUI | Native macOS feel, declarative, good for complex layouts |
| Minimum Target | macOS 15 (Sequoia) | Access to latest SwiftUI features (Inspector, custom containers) |
| Networking | URLSession + WebSocket | Native, no dependencies for OpenClaw API |
| Terminal | SwiftTerm (package) | Mature terminal emulator for macOS, renders tmux output |
| Rich Content | WKWebView | Canvas panel needs HTML/CSS/Markdown rendering |
| File Watching | DispatchSource / FSEvents | Real-time beads state updates |
| Data Layer | In-memory + filesystem | Beads files are the source of truth; no local database needed |
| Markdown | swift-markdown (Apple) | Parse markdown for canvas rendering |
| Package Manager | Swift Package Manager | Standard, no CocoaPods/Carthage complexity |

### Key Dependencies

```swift
// Package.swift dependencies
.package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0"),
.package(url: "https://github.com/apple/swift-markdown", from: "0.4.0"),
```

---

## 3. Data Model

### 3.1 Project

A project maps to a git repository with a `.beads/` directory.

```swift
struct Project: Identifiable, Hashable {
    let id: UUID
    let name: String           // e.g. "NetMonitor-iOS"
    let path: URL              // e.g. ~/Projects/NetMonitor-iOS
    let beadsPath: URL         // e.g. ~/Projects/NetMonitor-iOS/.beads
    let icon: String           // emoji or SF Symbol
    var isActive: Bool         // currently selected

    // Computed from beads state
    var openCount: Int
    var inProgressCount: Int
    var totalCount: Int
}
```

### 3.2 Bead (Issue/Task)

Read from `.beads/issues.jsonl`. Each line is a JSON object representing a bead.

```swift
struct Bead: Identifiable, Hashable, Codable {
    let id: String              // bead ID (short hash)
    let title: String
    let body: String?
    let status: BeadStatus      // open, in-progress, blocked, done
    let kind: BeadKind          // task, bug, feature, epic
    let epicId: String?         // parent epic ID
    let labels: [String]
    let assignee: String?       // "agent" or "human" or specific agent name
    let createdAt: Date
    let updatedAt: Date
    let dependencies: [String]  // other bead IDs
    let gitBranch: String?
    let lastCommit: String?     // short SHA
}

enum BeadStatus: String, Codable, CaseIterable {
    case open, inProgress = "in-progress", blocked, done
}

enum BeadKind: String, Codable, CaseIterable {
    case task, bug, feature, epic
}
```

### 3.3 Coding Session

Represents a running (or completed) coding agent session.

```swift
struct CodingSession: Identifiable {
    let id: String              // tmux session name or PID
    let name: String            // display name (e.g. "NetMonitor — NWPath")
    let agentType: AgentType    // claude-code, codex, opencode
    let projectPath: URL?
    let beadId: String?         // linked bead
    let status: SessionStatus
    let startedAt: Date
    let elapsed: TimeInterval
    let model: String?          // e.g. "claude-opus-4-6"
}

enum AgentType: String, CaseIterable {
    case claudeCode = "claude-code"
    case codex = "codex"
    case openCode = "opencode"
}

enum SessionStatus: String {
    case running, idle, stopped, error
}
```

### 3.4 Chat Message

```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole       // user, assistant, system
    let content: String
    let timestamp: Date
    let beadContext: String?     // linked bead ID
    let canvasContent: CanvasContent?  // content pushed to canvas
}

enum MessageRole: String {
    case user, assistant, system
}
```

### 3.5 Canvas Content

Content the agent (or user) pushes to the canvas panel.

```swift
enum CanvasContent: Identifiable {
    case markdown(id: UUID, title: String, content: String)
    case html(id: UUID, title: String, content: String)
    case image(id: UUID, title: String, url: URL)
    case diff(id: UUID, title: String, before: String, after: String, filename: String)
    case diagram(id: UUID, title: String, mermaid: String)
    case terminal(id: UUID, title: String, output: String)
}
```

---

## 4. UI Design

### 4.1 Window Layout

```
┌─────────┬───────────────────────────────────────┬──────────────┐
│ Sidebar  │ Center Panel                          │ Right Panel  │
│ (220pt)  │ (flexible, min 400pt)                 │ (340pt)      │
│          │                                       │              │
│ Projects │ ┌─────────────────────────────────┐   │ ┌──────────┐ │
│          │ │ Project Header + Stats          │   │ │ Mode Bar │ │
│ ──────── │ ├─────────────────────────────────┤   │ │ Chat|Can │ │
│          │ │ Tabs: Board|Epics|Agents|History│   │ │ |Split   │ │
│ Sessions │ ├─────────────────────────────────┤   │ ├──────────┤ │
│ • live   │ │                                 │   │ │          │ │
│ • idle   │ │  Active Tab Content             │   │ │ Canvas   │ │
│ • done   │ │  (Board columns, Epics list,    │   │ │ Area     │ │
│          │ │   Terminal view, etc.)           │   │ │          │ │
│ ──────── │ │                                 │   │ ├──────────┤ │
│          │ │                                 │   │ │          │ │
│ Views    │ │                                 │   │ │ Chat     │ │
│ Board    │ │                                 │   │ │ Messages │ │
│ Epics    │ │                                 │   │ │          │ │
│ History  │ │                                 │   │ ├──────────┤ │
│ Settings │ │                                 │   │ │ Context  │ │
│          │ └─────────────────────────────────┘   │ │ Input    │ │
│ ──────── │                                       │ └──────────┘ │
│ + New    │                                       │              │
└─────────┴───────────────────────────────────────┴──────────────┘
```

### 4.2 Left Sidebar (220pt fixed)

**Dark background** (`#2c2c2e`), consistent with macOS sidebar conventions.

**Sections:**

1. **Projects** — List of configured projects with bead counts. Click to select. Source: user config file (`~/.agentboard/config.json`) listing project paths.

2. **Coding Sessions** — Live list of running/idle/completed coding agent sessions. Each shows:
   - Status dot (green=running, yellow=idle, gray=done, red=error)
   - Session name (truncated)
   - Elapsed time or status label
   - Click → expands to terminal view in center panel

3. **Views** — Navigation shortcuts: Board, Epics, History, Settings.

4. **Actions** — "+ New Session" button at bottom. Opens a sheet to configure and launch a new coding agent session.

### 4.3 Center Panel (flexible)

**Light background** (`#f5f5f0`), the primary workspace.

**Project Header:**
- Project name, live status badge
- "⚡ Live Edit" button (toggles real-time bead sync)
- "Plan" button (opens epic planning view)
- Stats: Open / In Progress / Total counts

**Tab Bar:**
- **Board** — Kanban columns: Open, In Progress, Blocked, Done
- **Epics** — Grouped view of epics with child beads, progress bars
- **Agents** — Running sessions detail view (model, tokens, time, linked beads)
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
- Toolbar: session name, elapsed time, model, linked bead, "Back to Board" button
- Can send keystrokes to the tmux session (for nudging stuck agents)

### 4.4 Right Panel — Chat + Canvas (340pt)

The right panel has **three modes**, toggled via a segmented control at the top:

#### Chat Mode
- Standard chat interface connected to OpenClaw gateway
- Messages stream via WebSocket (SSE fallback)
- Context chips below messages show linked bead and active sessions
- Input area with text field and send button
- Supports markdown rendering in assistant messages
- Code blocks with syntax highlighting

#### Canvas Mode
- Rich content area rendered in WKWebView
- Agent can push content via a canvas protocol (part of the chat API)
- User can also paste images, HTML, or open local files
- Toolbar: zoom, export, clear
- Content types:
  - **Markdown** — rendered with syntax highlighting
  - **HTML** — live preview (great for UI mockups)
  - **Images** — screenshots, diagrams, generated images
  - **Diffs** — side-by-side or unified diff view
  - **Mermaid diagrams** — rendered to SVG
  - **Terminal output** — styled monospace

#### Split Mode (Default)
- Canvas takes top ~60%, chat takes bottom ~40%
- Resizable divider
- Agent messages that include canvas content auto-push to the canvas area
- Best of both worlds — see what the agent is showing you while continuing to chat

### 4.5 Visual Design Language

| Element | Value |
|---------|-------|
| Font (UI) | SF Pro Display |
| Font (Body) | SF Pro Text |
| Font (Code) | SF Mono / JetBrains Mono |
| Accent color | `#ff9500` (warm orange) |
| Background | `#f5f5f0` (warm cream) |
| Sidebar bg | `#2c2c2e` (dark gray) |
| Cards | White with subtle shadow |
| Border radius | 8px (cards), 12px (containers) |
| Status colors | Blue=open, Orange=progress, Red=blocked, Green=done |

**Dark Mode:** Invert the cream/white palette. Sidebar stays dark. Cards become `#2c2c2e`. Text inverts. Accent orange stays.

---

## 5. Service Layer

### 5.1 OpenClawService

Handles all communication with the OpenClaw gateway.

```swift
actor OpenClawService {
    let baseURL: URL           // ws://127.0.0.1:18789
    let authToken: String

    // Chat
    func sendMessage(_ text: String, sessionKey: String?) async throws -> AsyncStream<ChatChunk>
    func getChatHistory(sessionKey: String, limit: Int) async throws -> [ChatMessage]

    // Sessions
    func listSessions(activeMinutes: Int?) async throws -> [OpenClawSession]
    func getSessionStatus(sessionKey: String) async throws -> SessionStatus

    // Canvas
    func pushCanvas(_ content: CanvasContent) async throws
    func onCanvasUpdate() -> AsyncStream<CanvasContent>

    // Config
    func getConfig() async throws -> OpenClawConfig
}
```

**Connection strategy:**
1. WebSocket for streaming chat responses (primary)
2. REST polling for session list, status (every 5s when visible)
3. SSE fallback if WebSocket unavailable

### 5.2 BeadsWatcher

Watches `.beads/` directories for changes and publishes updates.

```swift
actor BeadsWatcher {
    // Watch a project's .beads/ directory
    func watch(project: Project) async

    // Stop watching
    func unwatch(project: Project) async

    // Stream of bead state changes
    var updates: AsyncStream<BeadsUpdate>

    // Read current state
    func loadBeads(from path: URL) async throws -> [Bead]

    // Write operations (shell out to `bd` CLI)
    func createBead(title: String, kind: BeadKind, project: Project) async throws -> Bead
    func updateBead(id: String, status: BeadStatus?, title: String?, project: Project) async throws
    func createEpic(title: String, children: [String], project: Project) async throws -> Bead
}
```

**Implementation:** Uses `DispatchSource.makeFileSystemObjectSource` on the `.beads/issues.jsonl` file. On change, re-parses the file and diffs against in-memory state. Publishes `BeadsUpdate` events for added/changed/removed beads.

**Write operations** shell out to the `bd` CLI to maintain compatibility with the beads ecosystem. We don't write JSONL directly.

### 5.3 SessionMonitor

Monitors coding agent sessions via tmux and process inspection.

```swift
actor SessionMonitor {
    let tmuxSocket: String  // /tmp/openclaw-tmux-sockets/openclaw.sock

    // Discover sessions
    func listSessions() async throws -> [CodingSession]

    // Capture pane output for terminal view
    func capturePane(session: String, lines: Int) async throws -> String

    // Send keys to session (for nudging)
    func sendKeys(session: String, keys: String) async throws

    // Stream session state changes
    var updates: AsyncStream<SessionUpdate>
}
```

**Implementation:**
1. Polls `tmux -S <socket> list-sessions` every 3 seconds
2. Polls `ps aux | grep -E "claude|codex|opencode"` for agent processes
3. Matches processes to tmux sessions by TTY
4. For terminal view: `tmux capture-pane -t <session> -p -S -500` for scrollback

### 5.4 CanvasRenderer

Handles rendering of canvas content in the WKWebView.

```swift
class CanvasRenderer {
    let webView: WKWebView

    func render(_ content: CanvasContent)
    func renderMarkdown(_ md: String)
    func renderHTML(_ html: String)
    func renderDiff(before: String, after: String, filename: String)
    func renderMermaid(_ diagram: String)
    func renderImage(_ url: URL)
    func clear()
    func export() -> NSImage?
}
```

**Implementation:** A pre-loaded HTML template with JS libraries (highlight.js, mermaid.js, diff2html). Content is pushed via `webView.evaluateJavaScript()`. The template handles rendering and styling.

---

## 6. OpenClaw Integration Protocol

### 6.1 Chat API

Uses the existing OpenClaw chat completions endpoint:

```
POST /v1/chat/completions
WebSocket: ws://127.0.0.1:18789/ws

Headers:
  Authorization: Bearer <gateway-token>
  X-Agent-Id: main (or specific agent)
```

### 6.2 Canvas Protocol (New)

Agent messages can include canvas directives via a convention in the response:

```
<!-- canvas:markdown -->
# Architecture Review
...content...
<!-- /canvas -->
```

Or via structured tool output that includes canvas content. AgentBoard parses these from the streamed response and routes them to the canvas panel.

**Alternative approach:** Use OpenClaw's existing A2UI canvas feature. AgentBoard registers as a canvas target and receives push updates.

### 6.3 Session Linking

When AgentBoard launches a coding session, it:
1. Creates a tmux session with a known name pattern: `ab-<project>-<bead-id>`
2. Starts the coding agent with the bead context as the prompt
3. Monitors the session via SessionMonitor
4. When the agent commits with a bead ID in the message, updates the bead status

---

## 7. Configuration

### 7.1 App Configuration

Stored at `~/.agentboard/config.json`:

```json
{
  "projects": [
    {
      "name": "NetMonitor-iOS",
      "path": "~/Projects/NetMonitor-iOS",
      "icon": "📡"
    },
    {
      "name": "AgentBoard",
      "path": "~/Projects/AgentBoard",
      "icon": "🎛️"
    }
  ],
  "openClaw": {
    "gatewayUrl": "ws://127.0.0.1:18789",
    "authToken": null
  },
  "tmux": {
    "socketPath": "/tmp/openclaw-tmux-sockets/openclaw.sock"
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

### 7.2 Gateway Token Discovery

On first launch, AgentBoard attempts to read the gateway token from:
1. `~/.openclaw/openclaw.json` → `gateway.auth.token`
2. Environment variable `OPENCLAW_GATEWAY_TOKEN`
3. Prompt user to paste it

---

## 8. File Structure

```
AgentBoard/
├── AgentBoard.xcodeproj
├── AgentBoard/
│   ├── App/
│   │   ├── AgentBoardApp.swift          // @main, WindowGroup, app lifecycle
│   │   ├── AppState.swift               // @Observable root state
│   │   └── AppConfig.swift              // Config loading/saving
│   ├── Models/
│   │   ├── Project.swift
│   │   ├── Bead.swift
│   │   ├── CodingSession.swift
│   │   ├── ChatMessage.swift
│   │   └── CanvasContent.swift
│   ├── Services/
│   │   ├── OpenClawService.swift        // Gateway API client
│   │   ├── BeadsWatcher.swift           // Filesystem watcher for .beads/
│   │   ├── SessionMonitor.swift         // tmux + process monitoring
│   │   └── CanvasRenderer.swift         // WKWebView content rendering
│   ├── Views/
│   │   ├── MainWindow/
│   │   │   └── ContentView.swift        // Three-panel NavigationSplitView
│   │   ├── Sidebar/
│   │   │   ├── SidebarView.swift
│   │   │   ├── ProjectListView.swift
│   │   │   ├── SessionListView.swift
│   │   │   └── ViewsNavView.swift
│   │   ├── Board/
│   │   │   ├── BoardView.swift          // Kanban board
│   │   │   ├── BoardColumnView.swift
│   │   │   ├── TaskCardView.swift
│   │   │   └── TaskDetailSheet.swift
│   │   ├── Epics/
│   │   │   ├── EpicsView.swift
│   │   │   └── EpicRowView.swift
│   │   ├── Agents/
│   │   │   └── AgentsView.swift
│   │   ├── History/
│   │   │   └── HistoryView.swift
│   │   ├── Terminal/
│   │   │   └── TerminalView.swift       // SwiftTerm wrapper
│   │   ├── Chat/
│   │   │   ├── ChatPanelView.swift
│   │   │   ├── ChatMessageView.swift
│   │   │   └── ChatInputView.swift
│   │   ├── Canvas/
│   │   │   ├── CanvasPanelView.swift
│   │   │   └── CanvasWebView.swift      // WKWebView wrapper
│   │   └── RightPanel/
│   │       └── RightPanelView.swift     // Mode switcher (Chat/Canvas/Split)
│   ├── Utilities/
│   │   ├── ShellRunner.swift            // Process/exec helper
│   │   ├── JSONLParser.swift            // Parse .beads/issues.jsonl
│   │   └── MarkdownRenderer.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── canvas-template.html         // WKWebView template with JS libs
│       └── Preview Content/
├── AgentBoardTests/
├── DESIGN.md                            // This file
├── IMPLEMENTATION-PLAN.md
└── README.md
```

---

## 9. Open Questions

1. **Canvas protocol:** Should we use OpenClaw's A2UI system, or define our own simpler protocol? A2UI is more capable but adds dependency on OpenClaw's internal API.

2. **Terminal emulator choice:** SwiftTerm is mature but heavy. Alternative: just render captured tmux output as styled AttributedString (simpler, less interactive but covers 90% of use cases).

3. **Multi-window:** Should AgentBoard support detaching the terminal view or canvas into separate windows? Nice to have but adds complexity.

4. **Keyboard shortcuts:** What's the shortcut vocabulary? Cmd+N for new bead, Cmd+Shift+N for new session, Cmd+Enter to send chat, etc.

5. **Auth flow:** Should AgentBoard auto-discover the gateway token from the OpenClaw config, or require explicit setup? (Recommendation: auto-discover with manual override.)

---

## 10. References

- **Mockup:** `/Users/blake/Downloads/agentboard-mockup.html`
- **Beads CLI:** `bd` command — `bd list`, `bd add`, `bd edit`, `bd epic`
- **OpenClaw Gateway API:** `http://127.0.0.1:18789` — REST + WebSocket
- **OpenClaw Docs:** `/opt/homebrew/lib/node_modules/openclaw/docs`
- **SwiftTerm:** https://github.com/migueldeicaza/SwiftTerm
- **swift-markdown:** https://github.com/apple/swift-markdown
