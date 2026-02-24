# Claude Notes

## Key Documents

- **`docs/ADR.md`** — Architecture Decision Records. Read before making structural changes. Append when making new decisions.
- **`DESIGN.md`** — Design document with architecture overview and panel layout.
- **`IMPLEMENTATION-PLAN.md`** — Phased implementation plan with status.

## Phase 1 Completed (2026-02-14)

- Tracking: `AgentBoard-qrw` (and children `.1` to `.5`) are closed.
- Baseline shell is implemented with `NavigationSplitView` + nested `HSplitView`.
- Window/layout contract:
  - Default: `1280x820`
  - Minimum: `900x600`
  - Sidebar fixed: `220`
  - Center min: `400`
  - Right panel ideal: `340` (resizable)
- Sidebar sections are collapsible: Projects, Sessions, Views.
- Phase 1 placeholders are intentional:
  - Board: empty Open/In Progress/Blocked/Done columns
  - Canvas: `No content`
- Project config decision:
  - `project.yml` is the source of truth
  - Re-run `xcodegen generate` after target/scheme edits
- Test gate decision:
  - `AgentBoardTests` exists with smoke tests
  - Run both:
    - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build`
    - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test`

## Phase 3 Completed (2026-02-15)

- Tracking closed:
  - Epic `AgentBoard-69u`
  - Tasks `AgentBoard-69u.1` to `AgentBoard-69u.4`
- OpenClaw integration:
  - Added `OpenClawService` actor for gateway config, session fetch, chat streaming, and WS lifecycle.
  - WS endpoint: `/ws` for connection health + ping checks.
  - Chat endpoint: `POST /v1/chat/completions` (SSE streaming with non-stream fallback).
  - Config discovery reads `~/.openclaw/openclaw.json` (`gateway.url`, `gateway.auth.token`) when app config values are empty.
- App state and UI:
  - Added connection state model (`connected/connecting/reconnecting/disconnected`) and header indicator.
  - Added streaming chat flow with incremental assistant updates and typing indicator.
  - Added markdown + fenced code rendering in assistant bubbles.
  - Added chat context chips (selected bead + remote session count).
  - Added bead reference detection in assistant output and board jump behavior.
  - Chat send shortcut remains `Cmd+Enter`.
- Verification run completed:
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build` ✅
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test` ✅

## Phase 4 Completed (2026-02-15)

- Tracking closed:
  - Epic `AgentBoard-52n`
  - Tasks `AgentBoard-52n.1` to `AgentBoard-52n.5`
- Session monitor integration:
  - Added `SessionMonitor` actor for tmux/session/process discovery and terminal pane capture.
  - Uses tmux socket `/tmp/openclaw-tmux-sockets/openclaw.sock`.
  - Discovery strategy:
    - `tmux list-sessions` + `tmux list-panes`
    - `ps -axo pid,ppid,pcpu,command`
    - Agent detection by command (`claude`, `codex`, `opencode`)
  - Session status derived from process detection and CPU activity.
- App state + UI behavior:
  - `AppState` now polls sessions every 3 seconds and keeps a live `sessions` list.
  - Sidebar sessions are now live and selectable.
  - Selecting a session opens `TerminalView` in the center panel (read-only capture mode).
  - Terminal toolbar includes back-to-board and nudge controls.
  - Nudge sends Enter (`C-m`) into tmux session.
- Session launch flow:
  - `+ New Session` now opens a launch sheet.
  - Inputs: project, agent type, optional bead ID, optional prompt.
  - Launches detached tmux session with naming pattern `ab-<project>-<bead-or-timestamp>`.
  - Optional seed prompt is sent after launch.
- Verification run completed:
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build` ✅
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test` ✅

## Phase 5 Completed (2026-02-15)

- Tracking closed:
  - Epic `AgentBoard-df9`
  - Tasks `AgentBoard-df9.1` to `AgentBoard-df9.5`
- Canvas system:
  - Added `CanvasRenderer` service for WKWebView rendering.
  - Render support includes markdown, HTML, image, diff, mermaid diagram, and terminal output.
  - `AppState` owns canvas history, navigation index, zoom, and loading state.
- Protocol + chat behavior:
  - Assistant output now parses canvas directives:
    - `<!-- canvas:markdown --> ... <!-- /canvas -->`
  - Supported directive types: markdown/html/diff/mermaid|diagram/image.
  - Parsed content is pushed to canvas automatically.
  - Assistant bubbles display `📋 Sent to canvas` when directive content is routed.
- User canvas flows:
  - Drag-and-drop files onto canvas.
  - File importer and clipboard image paste.
  - Chat context-menu action to open code-block messages in canvas.
  - Canvas toolbar includes history, zoom, export, and clear controls.
- Split mode polish:
  - Split mode defaults to 60% canvas / 40% chat.
  - Divider is draggable, supports edge collapse (full chat/full canvas), and double-click reset.
- Verification run completed:
  - `xcodegen generate` ✅
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build` ✅
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test` ✅

## Phase 6 Completed (2026-02-15)

- Tracking closed:
  - Epic `AgentBoard-fi5`
  - Tasks `AgentBoard-fi5.1` to `AgentBoard-fi5.6`
- Theme and dark mode:
  - Added `AppTheme` utility for adaptive app/panel/card/border colors.
  - Updated core center/right panel surfaces and cards for dark-mode parity.
  - Sidebar remains dark in both themes.
- Keyboard shortcuts and focus controls:
  - App command menus now provide:
    - `Cmd+N` new bead
    - `Cmd+Shift+N` new coding session
    - `Cmd+1-4` tab navigation
    - `Cmd+[` / `Cmd+]` canvas back/forward
    - `Cmd+L` focus chat input
  - Terminal view supports `Esc` to return to board.
  - Board and sidebar sheets are command-triggerable via AppState request tokens.
- Git integration:
  - Added `GitService` for commit discovery and diff retrieval.
  - Parses bead IDs from git commit messages.
  - `TaskCardView` now shows latest SHA + branch + commit count badges.
  - Clicking SHA opens commit diff in canvas.
- Agents and history:
  - `AgentsView` replaced placeholder with session table + aggregate metrics.
  - `HistoryView` replaced placeholder with reverse-chronological event timeline and filters.
  - Added `HistoryEvent` and `GitCommitRecord` models, and AppState rebuilds history from beads/sessions/commits.
- Notifications:
  - Added unread chat badge in right panel header.
  - Added session update badges for stopped/error transitions in session list.
- Phase 6 verification run completed:
  - `xcodegen generate` ✅
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build` ✅
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test` ✅

## Gateway Connection: Implementation Reference (2026-02-24)

### How the connection works end-to-end

AgentBoard connects to the OpenClaw gateway over a **WebSocket JSON-RPC** protocol.

**Config discovery (automatic)**

`AppConfigStore.discoverOpenClawConfig()` reads `~/.openclaw/openclaw.json` and extracts:
- Gateway URL: constructed from `gateway.port` + `gateway.bind` → `http://127.0.0.1:18789`
- Auth token: `gateway.auth.token`

This is used when the user hasn't manually configured a gateway URL in app settings.

**Connection sequence (`GatewayClient.connect`)**

1. Convert `http://` → `ws://` (or `https://` → `wss://`), strip path to root.
2. Create `URLSessionWebSocketTask` with a 15 s timeout and 16 MB max message size.
3. Call `task.resume()` + start receive loop.
4. Wait for `connect.challenge` and read `payload.nonce`.
5. Load (or generate) `DeviceIdentity` from `~/.agentboard/device-identity.json` — Ed25519 keypair, device ID = SHA-256 of public key raw bytes.
6. Call `buildAuthPayload(nonce: nonce)` → v2 payload string (pipe-separated: `v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce`).
7. Sign the payload with the Ed25519 private key → base64url signature.
8. Send `connect` RPC with `minProtocol/maxProtocol: 3`, client metadata, `device: { id, publicKey, signature, signedAt, nonce }`, and `auth: { token }`.
9. Await `connect` response. On success, set `isConnected = true` and start the ping loop (30 s interval).
10. Start watchdog timers:
   - request timeout: default ~15 s
   - connect challenge timeout: ~6 s
   - connect request timeout: ~12 s
   - inbound-frame watchdog: ~2x gateway `policy.tickIntervalMs` (triggers reconnect when stale)

**RPC message format**

Requests: `{ type: "req", id: "<uuid>", method: "<method>", params: { ... } }`
Responses: `{ type: "res", id: "<uuid>", ok: true/false, payload: { ... } }`
Events: `{ type: "event", event: "<name>", payload: { ... }, seq: N }`

**Chat streaming**

Events with `event: "chat"` carry `state: "delta" | "final" | "error" | "aborted"`:
- `delta`: accumulated text so far (not a diff — replace current bubble)
- `final`: stream complete; reload history via `chat.history` RPC
- `error` / `aborted`: surfaced in UI

### Issues found and fixed (2026-02-24)

**1. App Transport Security (ATS) blocked `ws://` on loopback**

- **Symptom:** `nw_read_request_report Receive failed with error "Socket is not connected"` on every connection attempt. `wasConnected=false` — never connected. `nw_flow_service_reads No output handler`.
- **Root cause:** macOS 26 enforces ATS for `URLSessionWebSocketTask` even on loopback (`127.0.0.1`). The auto-generated Info.plist had no ATS config, so `ws://` (unencrypted) was blocked by default.
- **Diagnosis:** `curl` WebSocket upgrade to `http://127.0.0.1:18789/` returned **101** — the gateway was fine. The failure was purely in-app ATS enforcement.
- **Fix:** Replaced `GENERATE_INFOPLIST_FILE = YES` with a real `AgentBoard/AgentBoard-Info.plist` containing:
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>NSAllowsLocalNetworking</key>
      <true/>
  </dict>
  ```
  `NSAllowsLocalNetworking` grants an ATS exception for loopback + link-local without disabling ATS globally for remote connections.
- **Build setting:** Set `GENERATE_INFOPLIST_FILE = NO` + `INFOPLIST_FILE = AgentBoard/AgentBoard-Info.plist` in both Debug and Release.

**2. Gateway rejected handshake: missing `nonce` in device object**

- **Symptom:** `/device must have required property 'nonce'` error from gateway schema validation after WebSocket connected.
- **Root cause:** `GatewayClient.connect()` passed `nonce: nil` to `buildAuthPayload()`, selecting v1 format, and omitted `nonce` from the `device` dict in `connectParams`. The gateway's schema requires `nonce`.
- **Fix:** Wait for `connect.challenge` and use `payload.nonce`; pass it to `buildAuthPayload(nonce: nonce)` (v2 format), and include `"nonce": nonce` in the `device` dict.

**3. `Preview Content` folder missing**

- **Symptom:** Xcode warning: `One of the paths in DEVELOPMENT_ASSET_PATHS does not exist: .../Preview Content`.
- **Fix:** `mkdir -p "AgentBoard/Resources/Preview Content"`.

### Key invariants for future coding agents

- **ATS is active.** `ws://` requires `NSAllowsLocalNetworking = YES` in Info.plist. `wss://` works without exception.
- **`nonce` is required** in the `device` dict and must come from the server's `connect.challenge`.
- **`buildAuthPayload` v2** is selected when `nonce != nil`. Always pass a nonce.
- **DeviceIdentity keypair** lives at `~/.agentboard/device-identity.json`. Generated once, reused. Device ID = SHA-256 of raw Ed25519 public key bytes.
- **Protocol version:** `minProtocol: 3, maxProtocol: 3`.
- **Token auth:** include `auth: { token: "<gateway token>" }` in connect params. Token is read from `~/.openclaw/openclaw.json` → `gateway.auth.token`.
- **Reconnect on disconnect:** `handleDisconnect()` does NOT finish event subscribers — streams remain live across reconnects. Only `disconnect()` (user-initiated) finishes subscribers.
- **`project.yml` is the source of truth** — XcodeGen regenerates the xcodeproj from it. Never edit `AgentBoard.xcodeproj/project.pbxproj` directly; changes will be overwritten on the next `xcodegen generate`. All build settings, plist properties, and target config belong in `project.yml`.
- **ATS config lives in `project.yml` under `targets.AgentBoard.info.properties`** — XcodeGen's `info` key generates `AgentBoard/AgentBoard-Info.plist` and sets `INFOPLIST_FILE` automatically. Adding `NSAppTransportSecurity.NSAllowsLocalNetworking: true` there is the correct and durable way to configure ATS. Do not use `INFOPLIST_KEY_*` build settings for nested dict values — they only work for flat strings.

---

## Chat Integration Rewrite (2026-02-16)

**Problem:** Phase 3's chat used `POST /v1/chat/completions` (a stateless REST endpoint) which
created throwaway sessions per request — never talking to the real main session. The `/api/sessions`
REST endpoint didn't exist. The WebSocket was only used for ping health checks.

**Fix:** Rewrote to use the gateway's native WebSocket JSON-RPC protocol.

- **New file:** `AgentBoard/Services/GatewayClient.swift`
  - WebSocket JSON-RPC client actor (connect handshake, request/response with UUIDs, event stream)
  - Connect handshake uses protocol version 3 with token auth
  - `JSONPayload` wrapper for `[String: Any]` to satisfy Swift 6 strict concurrency
  - Convenience methods: `sendChat`, `chatHistory`, `abortChat`, `listSessions`, `patchSession`, `agentIdentity`
  - Content extraction helper handles both string and array-of-parts message formats

- **Rewritten:** `AgentBoard/Services/OpenClawService.swift`
  - Now a thin wrapper around `GatewayClient` instead of managing raw HTTP/WS
  - Removed: `streamChat`, `connectWebSocket`, `pingWebSocket`, `fetchSessions` (REST)
  - Added: `sendChat`, `chatHistory`, `abortChat`, `listSessions`, `patchSession`, `agentIdentity`
  - `OpenClawRemoteSession` type kept for `AgentsView` backward compat

- **Modified:** `AgentBoard/App/AppState.swift`
  - New state: `currentSessionKey`, `gatewaySessions`, `chatThinkingLevel`, `chatRunId`, `agentName`, `agentAvatar`
  - Gateway event listener loop handles `chat` events (delta/final/error/aborted streaming states)
  - `sendChatMessage` uses `chat.send` + event-driven streaming (not request/response)
  - New methods: `switchSession`, `setThinkingLevel`, `loadChatHistory`, `loadAgentIdentity`, `abortChat`
  - Gateway session list refreshes every 15 seconds via `sessions.list`
  - History loaded on connect and session switch

- **Modified:** `AgentBoard/Views/Chat/ChatPanelView.swift`
  - Chat header: session picker dropdown, thinking level menu (brain icon), connection status
  - Abort button (red stop) replaces send button during streaming
  - Agent name from gateway identity instead of hardcoded "AgentBoard"
  - `ChatMessageBubble` now accepts `agentName` parameter
  - Context bar shows gateway session count instead of remote session count

- **Spec:** `docs/CHAT-REWRITE-SPEC.md` documents the full gateway WS protocol
- **ADR:** ADR-004 superseded by ADR-008

- Chat rewrite verification run completed:
  - `xcodegen generate` ✅
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build` ✅
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test` ✅
