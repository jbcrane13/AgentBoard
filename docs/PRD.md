# AgentBoard — Product Requirements Document (PRD)
**Version:** 1.2  
**Date:** 2026-02-25  
**Author:** R. Daneel Olivaw  
**Purpose:** Reference for Claude / Opencode agents tackling ongoing issues — covers all implemented features, architecture, known bugs, and open work.

---

## 1. Vision & Status

AgentBoard is a native **macOS 15+** app (Swift 6, SwiftUI) that unifies three AI-assisted dev workflows:

1. **Kanban Board** — beads-backed issue tracker with CLI refresh + FSEvents live sync
2. **Coding Session Monitor** — tmux session discovery, status, terminal capture, nudge
3. **OpenClaw Chat** — full chat with session switching, thinking level control, streaming, abort

**All 6 phases are complete.** The app builds and runs. Current work is bug-fixing, polish, and test coverage.

**Bundle ID:** `com.agentboard.AgentBoard`  
**Repo:** `~/Projects/AgentBoard`  
**Config:** `~/.agentboard/config.json`  
**Min OS:** macOS 15 (Sequoia)

---

## 2. Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                          AgentBoard.app                            │
│  ┌────────────┐  ┌──────────────────────┐  ┌──────────────────┐   │
│  │  Sidebar   │  │   Center Panel       │  │  Right Panel     │   │
│  │            │  │                      │  │                  │   │
│  │ Projects   │  │ Board / Epics /       │  │ Chat | Canvas   │   │
│  │ Sessions   │  │ Agents / History /    │  │ Split           │   │
│  │ Nav Links  │  │ Notes                 │  │                  │   │
│  └────────────┘  └──────────────────────┘  └──────────────────┘   │
│                                                                    │
│  AppState (@Observable @MainActor)                                 │
│  ├── OpenClawService → GatewayClient (WebSocket actor)             │
│  ├── SessionMonitor  (tmux discovery, actor)                       │
│  ├── BeadsWatcher    (FSEvents)                                     │
│  ├── GitService                                                    │
│  ├── CoordinationService (shared agent store)                      │
│  ├── WorkspaceNotesService (daily logs + ontology)                 │
│  └── AppConfigStore  (~/.agentboard/config.json + Keychain)        │
└────────────────────────────────────────────────────────────────────┘
         │                            │
         ▼                            ▼
  OpenClaw Gateway              tmux sockets
  ws://127.0.0.1:18789          /tmp/openclaw-tmux-sockets/openclaw.sock
```

### Key Files

| File | Purpose |
|------|---------|
| `AgentBoard/App/AppState.swift` | Central state machine (~1800 lines). Owns all domain state, all async loops, all service calls. Main actor. |
| `AgentBoard/Services/GatewayClient.swift` | WebSocket actor. Handles connect/disconnect/reconnect, request/response, event fan-out. |
| `AgentBoard/Services/OpenClawService.swift` | Thin wrapper around GatewayClient. Typed API methods. |
| `AgentBoard/Services/CoordinationService.swift` | Reads `~/.openclaw/shared/coordination.jsonl` — agent status + handoff store. |
| `AgentBoard/Services/WorkspaceNotesService.swift` | Daily note files + ontology graph reading from workspace. |
| `AgentBoard/Views/Chat/ChatPanelView.swift` | Chat UI: header (session picker + thinking level), message list, context bar, input. |
| `AgentBoard/Views/Board/BoardView.swift` | Kanban board: four-column layout, filter bar, drag-and-drop, create/edit/detail sheets, manual refresh. |
| `AgentBoard/Views/Notes/NotesView.swift` | Daily workspace logs + ontology knowledge graph entries, browsable by date. |
| `AgentBoard/Views/Agents/AgentsView.swift` | Agent status cards, active handoffs, coordination store display, session table. |
| `AgentBoard/Views/Sidebar/SessionListView.swift` | Coding session list with status dots and alert badges. |
| `AgentBoard/Views/Sidebar/NewSessionSheet.swift` | Sheet for launching new tmux + claude sessions. |
| `AgentBoard/Models/CodingSession.swift` | Model for tmux-discovered coding sessions. |
| `AgentBoard/Services/SessionMonitor.swift` | Actor: tmux socket inspection, process scanning, pane capture. |

---

## 3. Gateway WebSocket Protocol

All chat, session switching, and thinking level control flows through the gateway WebSocket JSON-RPC protocol (ADR-008).

### 3.1 Connection

**URL:** `ws://127.0.0.1:18789` (default; user-configurable in Settings)

Discovered from `~/.openclaw/openclaw.json` (fields: `gateway.port`, `gateway.bind`) in **auto** mode. Re-read fresh on every launch (ADR-009).

### 3.2 Message Framing

All messages are JSON text frames.

**Request (client → server):**
```json
{
  "type": "req",
  "id": "<uuid>",
  "method": "chat.send",
  "params": { ... }
}
```

**Response (server → client):**
```json
{
  "type": "res",
  "id": "<uuid>",
  "ok": true,
  "payload": { ... }
}
```

**Server Event (server → client, unsolicited):**
```json
{
  "type": "event",
  "event": "chat",
  "payload": { ... },
  "seq": 42
}
```

### 3.3 Handshake

1. Open WebSocket
2. Wait ~750ms for optional `connect.challenge` nonce
3. Send `connect` request with device identity, Ed25519 signature, token
4. Receive `hello` response → `isConnected = true`

### 3.4 Key RPC Methods

| Method | Direction | Purpose |
|--------|-----------|---------|
| `connect` | C→S | Handshake / auth |
| `chat.send` | C→S | Send a chat message to a session |
| `chat.history` | C→S | Fetch message history for a session |
| `chat.abort` | C→S | Abort an in-progress generation |
| `sessions.list` | C→S | List gateway sessions |
| `sessions.patch` | C→S | Modify session (e.g. thinkingLevel) |
| `agent.identity.get` | C→S | Get agent name/avatar for a session |

### 3.5 Chat Event Stream

Gateway streams `chat` events during generation. Each event contains the **full accumulated text** (not a delta) — the UI replaces the last assistant message on each event.

```json
{
  "type": "event",
  "event": "chat",
  "payload": {
    "sessionKey": "main",
    "runId": "uuid",
    "state": "streaming",
    "message": {
      "role": "assistant",
      "content": [{ "type": "text", "text": "accumulated text so far" }]
    }
  }
}
```

Terminal states: `state == "done"` or `state == "error"`.

---

## 4. Chat Session Management

### 4.1 State (AppState)

```swift
var currentSessionKey: String = "main"
var gatewaySessions: [GatewaySession]
var chatMessages: [ChatMessage]
var chatConnectionState: OpenClawConnectionState
var isChatStreaming: Bool
var chatRunId: String?
var chatThinkingLevel: String?   // nil | "off" | "low" | "medium" | "high"
var agentName: String
var agentAvatar: String?
```

### 4.2 Connection Lifecycle

`startChatConnectionLoop()` runs on launch and on config change:

1. Wait for gateway URL and token
2. `chatConnectionState = .connecting`
3. `openClawService.connect(url:token:)`
4. On success: `chatConnectionState = .connected`, load history, load identity, start event listener
5. On failure: wait 5s, retry

On WebSocket drop: sets `.disconnected`, retriggers loop.

### 4.3 Session Switching

`switchSession(to:)` — does NOT re-connect. Single WebSocket handles all sessions; events are filtered by `sessionKey`.

### 4.4 Thinking Level Control

**Status: Working ✅**

The chat header shows a brain icon + current thinking level as an interactive **Menu button**. Tapping it presents options: Default / Off / Low / Medium / High. Selecting one calls `appState.setThinkingLevel(_:)` → `sessions.patch` RPC.

```json
{
  "method": "sessions.patch",
  "params": {
    "key": "main",
    "thinkingLevel": "high"
  }
}
```

### 4.5 Gateway Session Refresh

`startGatewaySessionRefreshLoop()` polls `sessions.list` every **15 seconds** when connected.

---

## 5. Kanban Board

### 5.1 Columns

Four columns matching beads status: **Open** (blue) · **In Progress** (orange) · **Blocked** (red) · **Done** (green)

### 5.2 Filter Bar

- **Kind picker** — All / Task / Bug / Feature / Epic / Chore
- **Assignee picker** — All / daneel / quentin / argus (dynamic from loaded beads)
- **Epic picker** — All / <epic IDs from current project>
- **Refresh button** — manual ↻ button; spins while in flight, disabled during refresh
- **Create Bead button** — opens `BeadEditorForm` sheet

### 5.3 Refresh Behavior

Three triggers:
1. **Manual** — ↻ button in filter bar (calls `refreshBeadsFromCLI`)
2. **On launch / project switch** — `reloadSelectedProjectAndWatch` now fires `refreshBeadsFromCLI` immediately after the initial file load (added 2026-02-25)
3. **File change** — `BeadsWatcher` FSEvents watcher re-parses `issues.jsonl` on write

`refreshBeadsFromCLI` runs `bd list --all --json`, writes the result back to `issues.jsonl`, then reloads.

### 5.4 Task Cards

- Click → opens `TaskDetailSheet` (view + edit)
- Right-click → context menu: Edit / Delete / Assign to Agent / View in Terminal
- Drag-and-drop between columns → calls `bd update` to change status

### 5.5 Bead CRUD

All writes go through `bd` CLI to maintain compatibility with the beads ecosystem. AppState exposes: `createBead`, `updateBead`, `closeBead`, `moveBead`, `assignBeadToAgent`.

---

## 6. Coding Session Monitor

### 6.1 Discovery

`SessionMonitor` actor polls every ~10 seconds:

1. `tmux list-sessions` on the openclaw socket
2. `tmux list-panes` for pane details
3. `ps -axo pid,ppid,pcpu,command` for agent processes (`claude`, `codex`, `opencode`)
4. Derives status: `.running` (process + CPU > 0) · `.idle` (process, low CPU) · `.stopped`

### 6.2 Actions

- **Open in terminal** — `TerminalLauncher.openTmux(session:)` attaches Terminal.app
- **Nudge** — sends return keypress to tmux pane
- **Capture output** — `tmux capture-pane` for last N lines

### 6.3 New Session Sheet

Configure and launch a tmux coding agent session. Writes a launch script, runs it, triggers session monitor refresh. Known issues: AB-wj0 (UI upgrades needed — model picker, better defaults).

---

## 7. Notes Tab

**Status: Implemented ✅** (bead AB-zd9 done)

`NotesView` backed by `WorkspaceNotesService`. Shows:

- **Daily notes** — reads `~/.openclaw/workspace/memory/YYYY-MM-DD.md` for any date
- **Date navigation** — prev/next day arrows, "Today" button
- **Ontology knowledge graph** — renders entities/decisions/lessons from `memory/ontology/graph.jsonl`

Agents write to these files (session summaries, decisions, lessons). AgentBoard provides a read-only browse UI so Blake can review what agents have been doing without touching the terminal.

---

## 8. Agents View

**Status: Implemented ✅** (bead AB-572 done)

`AgentsView` shows:

- **Agent status cards** — Daneel / Quentin / Argus current task and status from `~/.openclaw/shared/coordination.jsonl`
- **Active handoffs** — expandable rows showing pending handoffs between agents
- **Session table** — running coding sessions with model, elapsed time, linked bead, token/cost estimates

Backed by `CoordinationService` which reads the shared coordination store.

---

## 9. Sidebar

- **Projects** — list with bead open/in-progress counts
- **Coding sessions** — live list with status dots and unread alert badges
- **Nav links** — Board / Epics / Agents / History / Notes / Settings
- **Collapsible** — toggle button collapses sidebar to icon-only strip for compact chat-focused layout (AB-3nu done)

---

## 10. Right Panel — Chat + Canvas

Three modes toggled by segmented control:

- **Chat** — full chat interface (session picker, thinking level, message list, input)
- **Canvas** — WKWebView rendering: markdown, HTML, images, diffs, Mermaid diagrams
- **Split** — canvas top ~60%, chat bottom ~40% (resizable divider) — default mode

---

## 11. Settings & Gateway Config

**Status: Implemented ✅** (ADR-009, bead AB-uzu done)

Settings panel (`SettingsView`) provides:

- **Auto mode** (default) — reads gateway URL and token fresh from `~/.openclaw/openclaw.json` on every launch. Read-only display with a "Refresh" button to re-read mid-session.
- **Manual mode** — user-entered gateway URL and token. Editable text fields, persisted to `~/.agentboard/config.json` (token in Keychain).
- **Test Connection** button — attempts a gateway handshake and reports success/failure
- **Projects list** — add/remove project paths with file picker

Token stored in macOS Keychain (not in config JSON).

---

## 12. Data Flow: Sending a Chat Message

```
User types → ChatPanelView.sendButton
    │
    ▼
AppState.sendChatMessage(text)
    │  Appends user + empty assistant ChatMessage to chatMessages
    │
    ▼
OpenClawService.sendChat(sessionKey:message:)
    │
    ▼
GatewayClient.request("chat.send", params: {...})
    │  Sends JSON over WebSocket, awaits response
    │
    ▼
[Gateway streams chat events asynchronously]
    │
    ▼
AppState.startChatEventListener()
    │  Filters: event.chatSessionKey == currentSessionKey
    │  "streaming" → appendAssistantChunk, capture chatRunId
    │  "done"      → finalizeChatMessage, isChatStreaming = false
    │  "error"     → handleChatError, isChatStreaming = false
    │
    ▼
ChatPanelView re-renders via @Observable binding
```

---

## 13. Known Issues & Open Beads

### Active (open)

| Bead | Priority | Description |
|------|----------|-------------|
| AB-dl5 | P2 | UI tests: board create-bead flow and task detail panel interactions |
| AB-wj0 | P2 | New Session sheet: model picker, better defaults, auto-focus |
| AB-mzp | P1 | App should launch with autodetect gateway selected (first-time experience) |
| AB-n36 | P2 | App should default to Chat mode instead of Split on launch |

### Untracked Issues (operational experience)

**1. Stream orphan on session switch**  
If user switches sessions while a response is streaming, `isChatStreaming` gets stuck `true` and the input is disabled.  
Fix: In `switchSession(to:)`, abort if `isChatStreaming == true` before switching.

**2. Connect.challenge race**  
Nonce event sometimes arrives before the receive loop starts → missed. Connect succeeds anyway (token auth works) but logs a warning.

**3. `isChatStreaming` not cleared on disconnect**  
If the WebSocket drops mid-stream, `isChatStreaming` stays `true` and the input is disabled.  
Fix: Force `isChatStreaming = false` in the disconnect handler.

**4. Token expiry on mid-session gateway restart**  
The reconnect loop reuses the in-memory token. If the gateway restarts with a new token, reconnects fail silently until the next app launch.  
Fix: Re-read `~/.openclaw/openclaw.json` on each reconnect attempt.

---

## 14. Build & Run

```bash
cd ~/Projects/AgentBoard
xcodegen generate        # regenerate .xcodeproj from project.yml
open AgentBoard.xcodeproj
# ⌘R to build and run
```

CLI:
```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -configuration Debug build
```

**Requirements:** macOS 15+, Xcode 16+, Swift 6.

---

## 15. Priorities for an Incoming Agent

1. **Fix stream orphan on session switch** — In `switchSession(to:)`, if `isChatStreaming == true`, call `abortChat()` first. In disconnect handler, force-clear `isChatStreaming`.

2. **Fix token re-read on reconnect** — Re-read `~/.openclaw/openclaw.json` in `startChatConnectionLoop()` on each reconnect attempt, not just initial connect.

3. **AB-n36** — Default `rightPanelMode` to `.chat` on first launch (or always). Currently defaults to `.split`.

4. **AB-mzp** — Ensure `gatewayConfigSource` defaults to `"auto"` and the auto-discovery runs on first launch without requiring any user action.

5. **AB-wj0** — New Session sheet: add model picker (claude / codex / opencode), auto-generate default session name, auto-focus the name field.

6. **AB-dl5** — UI tests: bead creation flow (fill form → save → verify card appears in board) and task detail sheet (click card → verify detail → edit → verify change).

---

*Updated by Daneel from live codebase inspection — 2026-02-25*
