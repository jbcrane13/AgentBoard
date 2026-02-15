# Claude Notes

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
