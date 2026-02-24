# AgentBoard — Product Requirements Document (PRD)
**Version:** 1.0  
**Date:** 2026-02-24  
**Author:** R. Daneel Olivaw  
**Purpose:** Reference for Claude / Opencode agents tackling ongoing issues — especially around chat sessions, gateway connectivity, and thinking level control.

---

## 1. Vision & Status

AgentBoard is a native **macOS 15+** app (Swift 6, SwiftUI) that unifies three AI-assisted dev workflows:

1. **Kanban Board** — beads-backed issue tracker with FSEvents live refresh
2. **Coding Session Monitor** — tmux session discovery, status, terminal capture, nudge
3. **OpenClaw Chat** — full chat with session switching, thinking level, streaming, abort

**All 6 phases are complete.** The app builds and runs. Current work is bug-fixing and polish.

**Bundle ID:** `com.agentboard.AgentBoard`  
**Repo:** `~/Projects/AgentBoard`  
**Config:** `~/.agentboard/config.json`

---

## 2. Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                          AgentBoard.app                            │
│  ┌────────────┐  ┌──────────────────────┐  ┌──────────────────┐   │
│  │  Sidebar   │  │   Center Panel       │  │  Right Panel     │   │
│  │            │  │                      │  │                  │   │
│  │ Projects   │  │ Board / Epics /       │  │ Chat | Canvas   │   │
│  │ Sessions   │  │ Agents / History      │  │ Split           │   │
│  │ Nav Links  │  │                      │  │                  │   │
│  └────────────┘  └──────────────────────┘  └──────────────────┘   │
│                                                                    │
│  AppState (@Observable @MainActor)                                 │
│  ├── OpenClawService → GatewayClient (WebSocket actor)             │
│  ├── SessionMonitor  (tmux discovery, actor)                       │
│  ├── BeadsWatcher    (FSEvents)                                     │
│  ├── GitService                                                    │
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
| `AgentBoard/App/AppState.swift` | Central state machine (~1700 lines). Owns all domain state, all async loops, all service calls. Main actor. |
| `AgentBoard/Services/GatewayClient.swift` | WebSocket actor. Handles connect/disconnect/reconnect, request/response, event fan-out (~605 lines). |
| `AgentBoard/Services/OpenClawService.swift` | Thin wrapper around GatewayClient. Typed API methods. |
| `AgentBoard/Views/Chat/ChatPanelView.swift` | Chat UI: header (session picker + thinking level), message list, context bar, input. |
| `AgentBoard/Views/Sidebar/SessionListView.swift` | Coding session list with status dots and alert badges. |
| `AgentBoard/Views/Sidebar/NewSessionSheet.swift` | Sheet for launching new tmux + claude sessions. |
| `AgentBoard/Models/CodingSession.swift` | Model for tmux-discovered coding sessions. |
| `AgentBoard/Services/SessionMonitor.swift` | Actor: tmux socket inspection, process scanning, pane capture. |

---

## 3. Gateway WebSocket Protocol

This is the most important area to understand. All chat, session switching, and thinking level control flows through here.

### 3.1 Connection

**URL:** `ws://127.0.0.1:18789` (same port as HTTP, multiplexed)

The URL is discovered from `~/.openclaw/openclaw.json` (fields: `gateway.port`, `gateway.bind`). In **auto** mode (default), this is re-read on every launch to avoid stale token bugs (see ADR-009).

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
  "id": "<uuid>",      ← matches request id
  "ok": true,
  "payload": { ... }
}
```
or on error:
```json
{
  "type": "res",
  "id": "<uuid>",
  "ok": false,
  "error": { "message": "..." }
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
2. Wait ~750ms (gateway emits `connect.challenge` nonce optionally — AgentBoard includes it if received)
3. Send `connect` request with full auth payload (device identity, Ed25519 signature, token)
4. Receive `hello` response → `isConnected = true`

The challenge/nonce flow is handled via a short delay. If the gateway sends a `connect.challenge` event before the connect request is sent, the nonce is included in `connectParams`. This can occasionally race — see §7.

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

When `chat.send` succeeds, the gateway streams `chat` events back:

```json
{
  "type": "event",
  "event": "chat",
  "payload": {
    "sessionKey": "main",
    "runId": "uuid",
    "state": "streaming",         ← "streaming" | "done" | "error"
    "message": {
      "role": "assistant",
      "content": [{ "type": "text", "text": "accumulated text so far" }]
    }
  }
}
```

**Critical:** The `text` field in each `chat` event contains the **full accumulated text**, not a delta. The UI replaces (not appends to) the last assistant message on each event.

Terminal states: `state == "done"` or `state == "error"`.

`chatRunId` is captured from the first `chat` event and used for `chat.abort`.

---

## 4. Chat Session Management

### 4.1 State

In `AppState`:

```swift
var currentSessionKey: String = "main"   // Which gateway session chat is targeting
var gatewaySessions: [GatewaySession]    // All sessions from sessions.list
var chatMessages: [ChatMessage]           // Currently displayed messages
var chatConnectionState: OpenClawConnectionState
var isChatStreaming: Bool                 // True while gateway is streaming a response
var chatRunId: String?                    // runId of current stream (for abort)
var chatThinkingLevel: String?           // "low" | "medium" | "high" | nil
var agentName: String                    // From agent.identity.get
```

### 4.2 Connection Lifecycle

`startChatConnectionLoop()` (called on launch and on config change) runs a `Task` loop:

1. Wait for `appConfig.openClawGatewayURL` and token to be non-nil
2. Set `chatConnectionState = .connecting`
3. Call `openClawService.connect(url:token:)`
4. On success: `chatConnectionState = .connected`, load history, load identity, start event listener
5. On failure: wait 5s, retry

**Reconnect:** If the WebSocket drops (detected in `GatewayClient.startReceiving()` receive loop ending), `AppState` sets `chatConnectionState = .disconnected` and retriggers the connection loop. `GatewayClient.isReconnecting` flag prevents subscriber teardown on transient drops.

### 4.3 Session Switching

`switchSession(to:)` in AppState:

```swift
func switchSession(to sessionKey: String) async {
    guard sessionKey != currentSessionKey else { return }
    currentSessionKey = sessionKey
    chatMessages = []
    chatRunId = nil
    isChatStreaming = false
    await loadChatHistory()
    await loadAgentIdentity()
}
```

**Note:** Does NOT re-connect or change the WebSocket. The single WebSocket connection receives events for all sessions. The event listener in AppState filters events by `sessionKey` matching `currentSessionKey`.

### 4.4 Event Listener

`startChatEventListener()` subscribes to `GatewayClient.events` (an AsyncStream):

```swift
for await event in openClawService.events {
    guard event.isChatEvent,
          event.chatSessionKey == currentSessionKey else { continue }
    
    switch event.chatState {
    case "streaming":
        appendAssistantChunk(text: event.chatMessageText ?? "")
        chatRunId = event.chatRunId
    case "done":
        finalizeChatMessage()
        isChatStreaming = false
        chatRunId = nil
    case "error":
        handleChatError(event.chatErrorMessage)
        isChatStreaming = false
    default: break
    }
}
```

**Watch out:** If `currentSessionKey` changes mid-stream (user switches sessions while a response is in flight), the event filter drops all subsequent events for the old session. The dangling `isChatStreaming = true` is never cleared. This is a known issue.

### 4.5 Gateway Session Refresh

`startGatewaySessionRefreshLoop()` polls `sessions.list` every **15 seconds** when connected, populating `gatewaySessions` for the session picker menu.

---

## 5. Thinking Level Control

**Current Status: Broken (bead AB-2cs)**

### How It's Supposed to Work

1. User opens the "Control UI" (a separate popover/sheet — currently the thinking level is displayed in chat header as read-only)
2. User picks a level (Low / Medium / High / Default)
3. `AppState.setThinkingLevel(_:)` calls `openClawService.patchSession(key:thinkingLevel:)` → `sessions.patch` RPC
4. Gateway applies the thinking level to the session
5. `chatThinkingLevel` is updated locally

### Why It's Broken

The chat header shows a brain icon + current thinking level, but it's marked `.help("Thinking level (change via Control UI)")` — there's no interactive control wired up to actually call `setThinkingLevel`. The bead AB-2cs is open for this.

Also: `sessions.patch` may require the correct `sessions.patch` method name and params format. Verify against the gateway protocol spec if patching isn't working.

### `sessions.patch` RPC

```json
{
  "method": "sessions.patch",
  "params": {
    "key": "main",
    "thinkingLevel": "high"   ← "low" | "medium" | "high" | null
  }
}
```

---

## 6. Coding Session Monitor

Separate from gateway chat sessions. These are **tmux sessions running coding agents** (Claude Code, Codex, Opencode) on the local machine.

### 6.1 Discovery

`SessionMonitor` actor polls every ~10 seconds:

1. `tmux list-sessions -t /tmp/openclaw-tmux-sockets/openclaw.sock` — list session names
2. `tmux list-panes -t <session> -F ...` — get pane details
3. `ps -axo pid,ppid,pcpu,command` — scan processes for `claude`, `codex`, `opencode` by name
4. Derive `SessionStatus`: `.running` (agent process found + CPU > 0), `.idle` (process found, low CPU), `.stopped` (no process)

### 6.2 Actions

- **Open in terminal** — calls `TerminalLauncher.openTmux(session:)` to attach Terminal.app
- **Nudge** — sends a return keypress to the tmux pane (useful when agent is waiting)
- **Capture output** — `tmux capture-pane` for last N lines (used for context in chat)

### 6.3 New Session Sheet

`NewSessionSheet` lets the user configure and launch a new tmux session with a coding agent. The sheet writes a launch script and runs it, then triggers a session monitor refresh.

---

## 7. Known Issues & Open Beads

### AB-2cs — Thinking level control doesn't take effect ● P2
- The thinking level brain icon in the chat header is display-only
- No interactive control exists to call `setThinkingLevel`
- Fix: Add a clickable menu/popover on the thinking level chip in the chat header that calls `appState.setThinkingLevel(_:)`
- Also verify `sessions.patch` RPC params match gateway expectations

### AB-dl5 — UI: Board Create Bead and Task Detail tests ● P2
- Missing UI tests for bead creation flow and task detail panel interactions

### AB-wj0 — UI: Settings and New Session behavioral upgrades ● P2
- Settings UI needs behavioral improvements
- New Session sheet needs upgrades (likely model selection, auto-launch option)

### Untracked Session Issues (from operational experience)

**1. Stream orphan on session switch**  
If user switches sessions while a response is streaming, `isChatStreaming` gets stuck `true`. The event listener drops events for the old session key but never clears the streaming state.  
Fix: When `switchSession` is called while `isChatStreaming == true`, call `abortChat()` first or force-clear `isChatStreaming`.

**2. Connect.challenge race**  
The `connect.challenge` nonce event sometimes arrives before the WebSocket receive loop is fully started, causing the nonce to be missed. The connect succeeds anyway (token auth works without nonce) but logs a warning.  
Fix: Buffer nonce from `connect.challenge` events before sending the `connect` request, with a timeout.

**3. Gateway session list staleness**  
The 15-second refresh means the session picker can show stale data. New sessions spawned externally don't appear until the next poll.  
Fix: Trigger a `sessions.list` refresh immediately after `chat.send` succeeds (to catch newly created sessions).

**4. Token expiry / config staleness**  
If the gateway is restarted (new token), auto-mode refreshes on next app launch. But mid-session restarts cause silent 401-equivalent failures. The reconnect loop retries but doesn't re-read the config file — it reuses the in-memory token.  
Fix: On reconnect attempts (not initial connect), re-read `~/.openclaw/openclaw.json` before calling `connect`.

**5. `isChatStreaming` not cleared on disconnect**  
If the WebSocket drops mid-stream, `isChatStreaming` stays `true` and the input is disabled.  
Fix: In the disconnect handler in AppState, force `isChatStreaming = false`.

---

## 8. Data Flow: Sending a Chat Message

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
    │  Response: { "ok": true } — message accepted
    │
    ▼
[Gateway streams chat events asynchronously]
    │
    ▼
GatewayClient.startReceiving() receive loop
    │  Parses incoming frames
    │  Routes responses to pendingRequests continuations
    │  Routes events to eventSubscribers (fan-out)
    │
    ▼
AppState.startChatEventListener() for-await loop
    │  Filters: event.chatSessionKey == currentSessionKey
    │  "streaming" → appendAssistantChunk, capture chatRunId
    │  "done"      → finalizeChatMessage, isChatStreaming = false
    │  "error"     → handleChatError, isChatStreaming = false
    │
    ▼
ChatPanelView re-renders via @Observable binding
```

---

## 9. Data Flow: Session Switching

```
User picks session in Chat header Menu
    │
    ▼
AppState.switchSession(to: "other-session")
    │  currentSessionKey = "other-session"
    │  chatMessages = []
    │  chatRunId = nil
    │  isChatStreaming = false   ← ⚠️ should abort first if streaming
    │
    ▼
loadChatHistory()  → chat.history RPC
    │  Populates chatMessages with history
    │  Sets chatThinkingLevel from response
    │
    ▼
loadAgentIdentity() → agent.identity.get RPC
    │  Sets agentName, agentAvatar
    │
    ▼
Event listener already running (same WebSocket)
    Now filters for new sessionKey
```

---

## 10. AppConfig & Gateway Discovery

```swift
struct AppConfig: Codable {
    var projects: [ProjectConfig]
    var selectedProjectPath: String?
    var openClawGatewayURL: String?       // constructed from port + bind
    var openClawToken: String?            // in-memory only; stored in Keychain
    var gatewayConfigSource: String?      // "auto" | "manual"
    var projectsDirectory: String?
}
```

In **auto** mode: on every launch, `discoverOpenClawConfig()` reads `~/.openclaw/openclaw.json` and constructs `openClawGatewayURL` from `gateway.port` (default 18789) and `gateway.bind`. The token is read fresh from the openclaw config each time.

In **manual** mode: user-entered values are preserved.

---

## 11. Project & Beads Integration

- `BeadsWatcher` uses `DispatchSource` FSEvents to watch `.beads/issues.jsonl` for changes
- On change: re-parses the JSONL file into `[Bead]` models, updates `AppState.beads`
- Board view renders beads in four columns: Open / In Progress / Blocked / Done
- Bead detail sheet allows status transitions, editing title/description, viewing git history
- `beadGitSummaries` maps bead ID → recent commits mentioning that bead ID

---

## 12. Build & Run

```bash
cd ~/Projects/AgentBoard
xcodegen generate        # regenerate .xcodeproj from project.yml
open AgentBoard.xcodeproj
# ⌘R to build and run
```

Or from CLI:
```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -configuration Debug build
```

**Requirements:** macOS 15+, Xcode 16+, Swift 6.

---

## 13. Priorities for an Incoming Agent

1. **Fix AB-2cs (thinking level):** Add interactive thinking level control to the chat header chip. Should call `appState.setThinkingLevel("low" | "medium" | "high" | nil)`. Verify `sessions.patch` params against gateway.

2. **Fix stream orphan on session switch:** In `switchSession(to:)`, if `isChatStreaming == true`, abort first. In disconnect handler, force-clear `isChatStreaming`.

3. **Fix token re-read on reconnect:** In `startChatConnectionLoop()`, re-read `~/.openclaw/openclaw.json` on each reconnect attempt, not just on first connect.

4. **Fix `isChatStreaming` on disconnect:** Set `isChatStreaming = false` in the disconnect handler path.

5. **AB-wj0 (new session sheet):** Add model picker (claude / codex / opencode), default name generation, and auto-focus.

6. **AB-dl5 (tests):** UI tests for bead creation flow and task detail panel.

---

*Document generated by Daneel from live codebase inspection — 2026-02-24*
