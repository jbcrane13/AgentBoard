# AgentBoard — Implementation Plan

**Reference:** See `DESIGN.md` for full architecture and data models.
**Mockup:** `/Users/blake/Downloads/agentboard-mockup.html`

---

## Phase 1: Skeleton & Layout (MVP Shell)

**Goal:** Three-panel window with navigation, placeholder content, and the basic app lifecycle. Any agent should be able to build from Xcode after this phase.

**Estimated effort:** 1-2 sessions

### 1.1 — Project Setup
- Create Xcode project: macOS App, SwiftUI lifecycle, Swift 6, minimum target macOS 15
- Bundle ID: `com.agentboard.AgentBoard`
- Add SPM dependencies: SwiftTerm, swift-markdown
- Set up file structure per DESIGN.md §8
- Add `.gitignore` (Xcode, DerivedData, .DS_Store)

### 1.2 — Three-Panel Layout
- `ContentView.swift` using `NavigationSplitView` (sidebar + detail) with an `HSplitView` for center+right
- Left sidebar: 220pt fixed width, dark background (`#2c2c2e`)
- Center panel: flexible, min 400pt
- Right panel: 340pt, resizable
- macOS window: default 1280×820, min 900×600
- Title bar: app icon + "AgentBoard" centered

### 1.3 — Sidebar Structure
- Three collapsible sections: Projects, Sessions, Views
- `ProjectListView` — static list with emoji icons and badge counts (hardcoded data)
- `SessionListView` — static list with status dots (green/yellow/gray)
- `ViewsNavView` — Board, Epics, History, Settings links
- "+ New Session" button at bottom

### 1.4 — Center Panel Tabs
- `ProjectHeaderView` — project name, status badge, stats (Open/In Progress/Total)
- Tab bar: Board, Epics, Agents, History
- Each tab shows a placeholder view with the tab name
- `BoardView` — four empty columns with colored headers (Open, In Progress, Blocked, Done)

### 1.5 — Right Panel Mode Switcher
- Segmented control at top: Chat | Canvas | Split
- `ChatPanelView` — static message list + input field (no backend yet)
- `CanvasPanelView` — empty WKWebView with "No content" placeholder
- `SplitPanelView` — vertical split of canvas (top) + chat (bottom), resizable divider

### Deliverables
- [x] Xcode project builds and runs
- [x] Three-panel layout renders correctly
- [x] Tab switching works
- [x] Right panel mode switching works
- [x] All placeholder views in place

### Phase 1 Decisions (Implemented)
- `project.yml` owns targets/schemes; `AgentBoardTests` was added and project regenerated via `xcodegen`.
- Smoke tests in `AgentBoardTests` are `@MainActor` because `AppState` is main-actor isolated.
- Main shell uses `NavigationSplitView` + nested `HSplitView` (sidebar/detail split + center/right split).
- Title bar uses a centered principal item with app icon + `AgentBoard`.
- Sidebar uses collapsible sections (Projects, Sessions, Views) via `DisclosureGroup`.
- Board remains a static Phase 1 placeholder with empty Open/In Progress/Blocked/Done columns.
- Canvas remains a static Phase 1 placeholder with `No content`.

---

## Phase 2: Beads Integration (Board Comes Alive)

**Goal:** The Kanban board reads real bead data from the filesystem. Users can view, create, and update beads through the UI.

**Estimated effort:** 2-3 sessions

### 2.1 — App Configuration
- `AppConfig.swift` — loads/saves `~/.agentboard/config.json`
- First-launch setup: scan `~/Projects/` for directories with `.beads/`, auto-populate project list
- Settings view for adding/removing projects manually
- Store OpenClaw gateway URL + auth token (auto-discover from `~/.openclaw/openclaw.json`)

### 2.2 — Beads Data Layer
- `JSONLParser.swift` — parse `.beads/issues.jsonl` into `[Bead]` array
- `Bead.swift` model matching beads JSONL schema (id, title, status, kind, labels, epic, dates, deps)
- `BeadsWatcher.swift` — `DispatchSource.makeFileSystemObjectSource` on `issues.jsonl`
- On file change: re-parse, diff against in-memory state, publish via `@Observable`
- Handle missing `.beads/` gracefully (show "Initialize beads?" prompt)

### 2.3 — Board View (Read)
- `BoardView.swift` — four `BoardColumnView` columns filtered by status
- `TaskCardView.swift` — bead ID, title, kind tag (colored), date, agent indicator
- Column counts in headers
- Cards sorted by updatedAt descending
- Empty state per column ("No issues" / "All clear 🎉")
- Filter bar: kind (task/bug/feature), assignee, epic dropdown

### 2.4 — Board View (Write)
- Drag-and-drop cards between columns → shells out to `bd edit <id> --status <new>`
- Right-click context menu: Edit, Delete, Assign to Agent, View in Terminal
- "Create Bead" sheet: title, kind, description, labels, epic selector
- "Edit Bead" sheet: all fields editable
- Both shell out to `bd add` / `bd edit` CLI

### 2.5 — Epics View
- `EpicsView.swift` — list of epic beads with child beads nested underneath
- Progress bar per epic (done/total children)
- Expand/collapse children
- "Create Epic" sheet: title, description, child bead selector

### Deliverables
- [x] Board shows real beads from filesystem
- [x] Live updates when beads change externally (e.g., agent commits)
- [x] Create, edit, drag-drop beads
- [x] Epics view with progress
- [x] Config persisted across launches

---

## Phase 3: Chat Integration (Talk to Your Agent)

**Goal:** The chat panel connects to the OpenClaw gateway and supports full conversations with streaming responses.

**Estimated effort:** 2-3 sessions

### 3.1 — OpenClaw Service
- `OpenClawService.swift` — actor-based API client
- Gateway token discovery: read from `~/.openclaw/openclaw.json` → `gateway.auth.token`
- REST: `GET /api/sessions` for session list
- WebSocket: connect to `ws://127.0.0.1:18789/ws` for streaming chat
- Fallback: `POST /v1/chat/completions` with SSE streaming
- Connection state: connected / connecting / disconnected (shown in chat header)
- Auto-reconnect with exponential backoff

### 3.2 — Chat UI
- `ChatPanelView.swift` — scrollable message list + input
- `ChatMessageView.swift` — user messages (blue, right-aligned), assistant messages (white, left-aligned)
- Markdown rendering in assistant messages (bold, code, lists)
- Code blocks with monospace font and subtle background
- Streaming: show partial response as it arrives, with typing indicator
- Auto-scroll to bottom on new messages
- Context chips below messages (linked bead, active sessions)

### 3.3 — Chat Input
- `ChatInputView.swift` — multi-line text field with send button
- Cmd+Enter to send
- Shift+Enter for newline
- Paste image support (sends as attachment)
- "/" command suggestions (optional, stretch)

### 3.4 — Bead Context Linking
- When a bead card is selected in the board, the chat context updates
- Context chip shows the active bead ID
- Messages sent include bead context so the agent knows what's being discussed
- Agent responses that reference bead IDs get linked back to the board

### Deliverables
- [x] Chat connected to OpenClaw gateway
- [x] Streaming responses render in real-time
- [x] Connection status indicator
- [x] Bead context linking between board and chat
- [x] Markdown rendering in messages
- [x] Session switching (picker in chat header)
- [x] Thinking level control (Default/Low/Medium/High)
- [x] Abort button for stopping generation
- [x] Gateway WebSocket RPC protocol (replaces stateless REST — see ADR-008)

---

## Phase 4: Session Monitor (See Your Agents Work)

**Goal:** The sidebar shows live coding agent sessions. Clicking one opens a terminal view in the center panel.

**Estimated effort:** 2 sessions

### 4.1 — Session Discovery
- `SessionMonitor.swift` — polls tmux + ps every 3 seconds
- Discover sessions from: `tmux -S /tmp/openclaw-tmux-sockets/openclaw.sock list-sessions`
- Match running processes: `ps aux | grep -E "claude|codex|opencode"`
- Determine agent type from process command
- Extract project path from process cwd (`lsof -p <pid> | grep cwd`)
- Link to beads via tmux session name pattern or commit messages

### 4.2 — Session List UI
- `SessionListView.swift` — live list in sidebar
- Status dots: green (running, >0% CPU), yellow (idle, 0% CPU but alive), gray (stopped), red (error)
- Session name (truncated with ellipsis)
- Elapsed time or status label
- Click → switches center panel to terminal view

### 4.3 — Terminal View
- `TerminalView.swift` — wraps SwiftTerm's `LocalProcessTerminalView` or renders captured output
- **Option A (Interactive):** SwiftTerm connects to tmux session via `tmux attach -t <session>`
- **Option B (Read-only):** Periodically capture pane output and render as styled AttributedString
- Start with Option B (simpler), upgrade to Option A later
- Toolbar: session name, elapsed, model, linked bead, "← Back to Board" button
- "Nudge" button: sends Enter key to tmux session (unsticks agents)

### 4.4 — Launch Session
- "+ New Session" button in sidebar → sheet
- Select project, select agent type (Claude Code / Codex / OpenCode)
- Optional: link to a bead (pre-populates prompt with bead context)
- Optional: custom prompt
- Launches in tmux session with known name pattern

### Deliverables
- [x] Sidebar shows live coding sessions with status
- [x] Click session → terminal view in center panel
- [x] Launch new sessions from UI
- [x] Session ↔ bead linking

---

## Phase 5: Canvas Panel (Visual Collaboration)

**Goal:** The right panel canvas renders rich content — markdown, HTML, diffs, diagrams, images — pushed by the agent or the user.

**Estimated effort:** 2 sessions

### 5.1 — Canvas Renderer
- `CanvasRenderer.swift` — manages WKWebView content
- `canvas-template.html` — base HTML with embedded JS libraries:
  - highlight.js (syntax highlighting)
  - mermaid.js (diagram rendering)
  - diff2html (diff visualization)
  - marked.js (markdown → HTML)
- Content pushed via `webView.evaluateJavaScript("renderContent(…)")`
- Content history: stack of previous canvas items, back/forward navigation

### 5.2 — Canvas UI
- `CanvasPanelView.swift` — WKWebView with toolbar
- Toolbar: content type indicator, zoom +/-, export (copy image / save file), clear, history nav
- Loading indicator for heavy renders (mermaid diagrams)
- Empty state: "Canvas is empty. Chat with your agent to see content here."

### 5.3 — Agent → Canvas Protocol
- Parse agent responses for canvas directives:
  ```
  <!-- canvas:markdown -->
  content here
  <!-- /canvas -->
  ```
- Support types: `markdown`, `html`, `diff`, `mermaid`, `image`
- When detected, route content to canvas panel automatically
- Show a small "📋 Sent to canvas" indicator in the chat message

### 5.4 — User → Canvas
- Drag-and-drop files onto canvas (images, .md, .html, .swift)
- Paste images from clipboard
- "Open in Canvas" context menu on chat messages containing code blocks
- File picker for local files

### 5.5 — Split Mode Polish
- Default mode: Split (canvas top 60%, chat bottom 40%)
- Resizable divider (drag to resize)
- Double-click divider to reset to default split
- Collapse canvas (full chat) or collapse chat (full canvas) by dragging to edge

### Deliverables
- [x] WKWebView canvas renders markdown, HTML, diffs, mermaid diagrams
- [x] Agent messages auto-push to canvas
- [x] User can drag files / paste images to canvas
- [x] Split mode with resizable divider
- [x] Content history navigation

---

## Phase 6: Polish & Integration

**Goal:** Dark mode, keyboard shortcuts, git integration, notifications, and overall polish.

**Estimated effort:** 2-3 sessions

### 6.1 — Dark Mode
- Full dark mode support (`.preferredColorScheme` or system auto)
- Sidebar stays dark in both themes
- Cards: white → `#2c2c2e`, backgrounds invert
- Canvas template has dark mode CSS variant

### 6.2 — Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `⌘N` | New bead |
| `⌘⇧N` | New coding session |
| `⌘↵` | Send chat message |
| `⌘1-4` | Switch tabs (Board/Epics/Agents/History) |
| `⌘[` / `⌘]` | Canvas history back/forward |
| `⌘L` | Focus chat input |
| `Esc` | Back to board from terminal view |

### 6.3 — Git Integration on Task Cards
- Show latest commit SHA + branch on cards with agent work
- Click SHA → opens diff in canvas
- Commit count badge on in-progress cards
- Parse git log for bead ID references in commit messages

### 6.4 — Agents View
- `AgentsView.swift` — table of running/recent sessions
- Columns: name, agent type, model, project, bead, status, elapsed, token usage
- Token usage: read from OpenClaw session status API
- Aggregate stats: total sessions today, total tokens, estimated cost

### 6.5 — History View
- `HistoryView.swift` — reverse-chronological timeline
- Events: bead created, bead status changed, session started/completed, commits
- Filter by project, event type, date range
- Source: beads state changes + git log + session events

### 6.6 — Notifications
- Badge on chat panel header when agent sends message while viewing board
- Badge on session list when a session completes or errors
- macOS notification center integration for background events (optional)

### Deliverables
- [x] Dark mode
- [x] Keyboard shortcuts
- [x] Git info on task cards
- [x] Agents overview with token usage
- [x] History timeline
- [x] Notification badges

---

## Agent Assignment Guide

Each phase (and many individual tasks) can be worked on independently. Here's how to assign work:

### For Claude Code / Codex / OpenCode:
1. Read `DESIGN.md` for architecture context
2. Read this file for the specific phase/task
3. Work within `~/Projects/AgentBoard/`
4. Build with: `xcodebuild build -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' -quiet`
5. Commit after each logical unit of work

### Task Independence:
- **Phase 1** must be done first (skeleton)
- **Phases 2, 3, 4** can be done in parallel after Phase 1
- **Phase 5** depends on Phase 3 (chat) being functional
- **Phase 6** depends on Phases 2-5

### Key Files to Read First:
- `DESIGN.md` — full architecture, data models, UI design
- `IMPLEMENTATION-PLAN.md` — this file, phased task breakdown
- `/Users/blake/Downloads/agentboard-mockup.html` — visual mockup
