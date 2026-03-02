# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Agent Readiness

**Read `docs/agent-readiness/README.md` before starting any work session.**

It contains the current agent readiness score, all conventions established by past sessions, key file locations, and quality gate commands. The README is the single source of truth for what tooling is configured and what rules are in effect.

Quick orientation:
- **Score as of 2026-02-28:** Level 2 → targeting Level 3
- **Lint:** `swiftlint lint --strict` (install: `brew install swiftlint`)
- **Test:** `xcodebuild test -scheme AgentBoard -destination 'platform=macOS' -skip-testing:AgentBoardUITests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- **Regenerate xcodeproj after `project.yml` edits:** `xcodegen generate`
- **CI:** `.github/workflows/ci.yml` — SwiftLint → Build → Test → Coverage ≥ 30%

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

## Gateway Connection (read this before touching GatewayClient or OpenClawService)

AgentBoard connects to the local OpenClaw gateway over **WebSocket JSON-RPC** (`ws://127.0.0.1:18789`).

### Required: Info.plist ATS exception

The project uses a **real** `AgentBoard/AgentBoard-Info.plist` — `GENERATE_INFOPLIST_FILE = NO`.
**Do not re-enable auto-generation.** The plist must contain:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

Without this, macOS 26 ATS blocks `ws://` (unencrypted WebSocket) on loopback and the app silently fails to connect with `"Socket is not connected"` on every attempt.

### Required: nonce in every connect handshake

Every call to `GatewayClient.connect()` must:
1. Wait for `connect.challenge` and read `payload.nonce`
2. Pass it to `buildAuthPayload(nonce: nonce)` (selects v2 format)
3. Include `"nonce": nonce` in the `device` dict sent to the gateway

The gateway's JSON schema enforces `nonce` as a required field. Missing it gives `/device must have required property 'nonce'`.

### Config auto-discovery

`AppConfigStore.discoverOpenClawConfig()` reads `~/.openclaw/openclaw.json`:
- URL: built from `gateway.port` + `gateway.bind`
- Token: `gateway.auth.token`

### Reconnect model

- Transient disconnects → `handleDisconnect()` — fails pending requests, marks reconnecting, does **not** finish event subscribers. AppState's `startChatConnectionLoop()` will reconnect.
- User disconnect → `disconnect()` — finishes subscribers, clears all state.
- Request timeout defaults to ~15s; connect challenge timeout is ~6s; connect RPC timeout is ~12s.
- Gateway watchdog monitors inbound frame activity (`~2x` policy tick interval). Missed ticks/frames trigger disconnect and reconnect.

### ⚠️ Never edit `AgentBoard.xcodeproj/project.pbxproj` directly

`project.yml` is the source of truth. XcodeGen regenerates the xcodeproj from it — direct pbxproj edits are silently overwritten. All build settings, plist properties, and target config go in `project.yml`. After editing, run:
```bash
xcodegen generate
```

The ATS config (`NSAllowsLocalNetworking`) lives in `project.yml` under `targets.AgentBoard.info.properties` and is written to `AgentBoard/AgentBoard-Info.plist` by XcodeGen.

### Verified working on macOS 26 after 2026-02-24 fixes

See `CLAUDE.md` → "Gateway Connection: Implementation Reference" for full protocol details, diagnosis notes, and the list of issues that were found and fixed.

---

## Phase 1 Snapshot (2026-02-14)

- Epic `AgentBoard-qrw` and child tasks `AgentBoard-qrw.1` through `AgentBoard-qrw.5` are closed.
- `project.yml` is the source of truth for targets/schemes; regenerate project files with `xcodegen generate` after project config changes.
- `AgentBoardTests` exists with smoke tests, and `xcodebuild ... test` is now part of the required quality gate.
- UI shell decision: `NavigationSplitView` for sidebar/detail, with `HSplitView` for center + right panel.
- Layout baseline: default window `1280x820`, minimum `900x600`, sidebar fixed to `220`, center minimum `400`, right panel ideal `340`.
- Phase 1 board and canvas are intentionally placeholders (`BoardView` empty canonical columns, canvas shows `No content`).

## Phase 3 Snapshot (2026-02-15)

- Tracking: `AgentBoard-69u` and child tasks `AgentBoard-69u.1` to `AgentBoard-69u.4` are closed.
- OpenClaw config is auto-hydrated from `~/.openclaw/openclaw.json` (`gateway.url`, `gateway.auth.token`) when local config fields are unset.
- Chat service split:
  - Connection lifecycle uses WebSocket (`/ws`) with ping health checks and reconnect backoff in `AppState`.
  - Message streaming uses `POST /v1/chat/completions` SSE parsing with a non-streaming fallback path.
- Chat UI decisions:
  - Streaming assistant bubble updates in place with typing indicator.
  - Assistant markdown supports inline formatting and fenced code blocks with monospace styling.
  - Context chips include selected bead and remote session count.
  - Cmd+Enter sends, TextEditor newline remains available while composing.
  - Assistant message bead references render as clickable chips and route back to board selection.
- Verification gate passed:
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build`
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test`

## Phase 4 Snapshot (2026-02-15)

- Tracking: `AgentBoard-52n` and child tasks `AgentBoard-52n.1` to `AgentBoard-52n.5` are closed.
- Session monitoring architecture:
  - `SessionMonitor` is the tmux/process integration point.
  - Tmux socket default is `/tmp/openclaw-tmux-sockets/openclaw.sock`.
  - Discovery uses `tmux list-sessions` + `tmux list-panes` + `ps` snapshots.
  - Status mapping uses detected agent process + CPU threshold (`> 0.1` => running, otherwise idle; no agent process => idle/stopped by attachment state).
- Center panel behavior:
  - Selecting a session in sidebar opens a read-only terminal center view (`TerminalView`) with:
    - Back to board
    - Nudge action (sends `C-m` via tmux)
    - Periodic pane capture refresh
- Session launch behavior:
  - Sidebar `+ New Session` now opens a sheet with project/agent/bead/prompt fields.
  - Sessions launch as detached tmux sessions with name pattern `ab-<project>-<bead-or-timestamp>`.
  - Optional prompt is sent into the launched session after start.
- Verification gate passed:
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build`
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test`

## Phase 5 Snapshot (2026-02-15)

- Tracking: epic `AgentBoard-df9` and child tasks `AgentBoard-df9.1` through `.5` are closed.
- Canvas rendering:
  - `CanvasRenderer` drives WKWebView rendering for markdown, HTML, image, diff, mermaid, and terminal content.
  - Canvas state is centralized in `AppState` (`canvasHistory`, `canvasHistoryIndex`, `canvasZoom`, `isCanvasLoading`) with back/forward navigation.
- Agent -> canvas protocol:
  - Assistant replies are parsed for `<!-- canvas:type --> ... <!-- /canvas -->`.
  - Supported types: `markdown`, `html`, `diff`, `mermaid`/`diagram`, `image`.
  - Parsed content is auto-pushed to canvas history, and assistant bubbles show `📋 Sent to canvas`.
- User -> canvas interactions:
  - Drag/drop file URLs onto canvas.
  - File picker (`Open`) and clipboard image paste (`Paste Image`).
  - Chat message context menu supports `Open in Canvas` for fenced code blocks.
  - Export and clear actions are available from the canvas toolbar.
- Split mode behavior:
  - Default split ratio is 60/40 (canvas/chat).
  - Divider is draggable, edge drag collapses either pane, and double-click resets to default split.
- Verification gate passed:
  - `xcodegen generate`
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build`
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test`

## Phase 6 Snapshot (2026-02-15)

- Tracking: epic `AgentBoard-fi5` and child tasks `AgentBoard-fi5.1` through `.6` are closed.
- Dark mode + visual polish:
  - Added shared adaptive theme values in `AppTheme`.
  - Updated center/right surfaces and cards to render correctly in dark mode while keeping the sidebar dark.
- Keyboard shortcuts:
  - Added app command shortcuts:
    - `Cmd+N` new bead
    - `Cmd+Shift+N` new coding session
    - `Cmd+1-4` tab switch
    - `Cmd+[` / `Cmd+]` canvas history navigation
    - `Cmd+L` focus chat input
    - `Esc` returns from terminal to board
- Git integration on board cards:
  - Added `GitService` to parse git log and map bead IDs in commit messages.
  - Task cards now show branch + latest SHA and commit count badges for in-progress work.
  - Clicking a SHA opens the commit diff in canvas.
- Agents + history views:
  - `AgentsView` now renders a real table with session metadata and aggregate stats (sessions today, tokens, estimated cost).
  - `HistoryView` now renders reverse-chronological events with project/type/date filters.
- Notifications:
  - Chat header badge increments for unread assistant activity when canvas mode is active on board.
  - Session list shows alert badge/dots for sessions transitioning to stopped/error.
- Verification gate passed:
  - `xcodegen generate`
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build`
  - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test`
