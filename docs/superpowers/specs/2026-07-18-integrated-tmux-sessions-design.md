# Integrated Interactive tmux Sessions Design

- **Date:** 2026-07-18
- **Status:** Awaiting review
- **Author:** Blake Crane + Claude
- **Supersedes:** the terminal/session-monitor sections of the pre-rewrite root `DESIGN.md` (OpenClaw-era socket paths are dead); consolidates ADR-005 (tmux monitoring) and ADR-006 (SwiftTerm) into a current design.
- **Scope:** Live embedded terminal for coding-agent tmux sessions (Claude Code / Codex / OpenCode), session lifecycle controls, minimize/restore, and persistent transcripts. Closes the "session controls / deeper session detail / transcript UX" open item in `docs/implementation-status.md`.

## Decisions (made 2026-07-18)

1. **Interactivity:** read-only live terminal by default; explicit **Take Control** toggle enables input, with a visible active-input state.
2. **Controls in scope:** kill session, nudge (send a line without takeover), restart/relaunch, detach/minimize-to-rail.
3. **Transcripts:** persisted by the Companion (SQLite), viewable after session end, cross-device.
4. **iOS:** live read-only view via Companion-streamed snapshots; no keystroke proxying.

## Architecture

Two transports, chosen per platform capability:

- **macOS — native tmux client attach.** The existing `EmbeddedTerminalView` (real PTY + SwiftTerm) spawns `tmux attach-session -r -t <name>` for the read-only live view. tmux's own `-r` flag enforces read-only at the server — safety is not a UI promise. **Take Control** detaches the read-only client and re-attaches read-write (`tmux attach-session -t <name>`). Detach/minimize terminates only the local tmux *client* process; the agent's session is never disturbed.
- **iOS + post-session everywhere — Companion transcripts.** The Companion's existing probe loop gains a capture step: periodic `tmux capture-pane -p -S -2000` per tracked session, stored as the latest-snapshot transcript; finalized when the session disappears. iOS renders this as a live-updating read-only view while the session runs (refetch on the existing companion event stream) and both platforms use it as post-session history.

Rejected alternatives: polling `capture-pane` diffs on macOS (laggy, flickery, no cursor — but correct for iOS where a tmux client is impossible); tmux control mode `-CC` (protocol parser with no user-visible gain over native attach).

## Components

### 1. `SessionAttachmentController` (new, AgentBoardCore)

`@MainActor @Observable`. Owns at most one attached session at a time (the board center panel):

- `state: AttachmentState` — `.detached`, `.attachedReadOnly(sessionName:)`, `.attachedInteractive(sessionName:)`, `.failed(message:)`
- `attach(sessionName:)` — builds the read-only attach command and hands it to the terminal view layer
- `takeControl()` / `releaseControl()` — swaps the client between `-r` and read-write attach
- `detach()` — terminates the local client PTY only
- Pure, testable helper: `static func attachArguments(sessionName:readOnly:) -> [String]`

### 2. `TmuxController` additions (AgentBoardCore)

Extends the existing protocol + actor (same wrapper style as `capturePane`/`openInTerminal`):

- `sendKeys(name:text:)` — `tmux send-keys -t <name> -l <text>` followed by `Enter` (nudge; literal `-l` so agent-prompt answers aren't interpreted as key names)
- `killSession(name:)` — `tmux kill-session -t <name>`

### 3. `SessionLauncher` additions (AgentBoardCore)

- Persist `LaunchConfig` keyed by generated session name at launch time (UserDefaults-backed via `SettingsRepository` pattern; small codable dictionary).
- `relaunch(sessionName:)` — kill + launch with the stored config. Restart is **only offered for sessions AgentBoard launched**; discovered foreign sessions get attach/nudge/kill but no restart.

### 4. Companion transcript capture (AgentBoardCompanionKit)

- Probe loop addition: for each tracked session, capture scrollback every ~10s (best-effort; never blocks discovery) and upsert into a new `session_transcripts` table: `(session_id TEXT PRIMARY KEY, content TEXT, updated_at INTEGER, is_final INTEGER)`. When a session disappears from discovery, mark its transcript `is_final = 1`.
- Migration follows the house `PRAGMA table_info` + `ALTER/CREATE` pattern; binds use `SQLITE_TRANSIENT`.
- REST: `GET /sessions/{id}/transcript` on `CompanionServer`; `CompanionClient.fetchTranscript(sessionID:)` on the app side.

### 5. UI (AgentBoardUI)

- **`SessionTerminalView` (macOS):** hosts the attached terminal in the center panel. Header: session name + agent icon, **Take Control** toggle (accent-colored active state + banner "Keyboard input live"), Nudge field (single-line + send), Restart (when eligible), Kill (confirmation dialog), Minimize. Keystrokes are additionally swallowed at the view layer unless interactive — defense in depth alongside `-r`.
- **Sessions rail:** minimized attachment shows a compact restorable chip.
- **iOS `SessionDetailSheet`:** live transcript view (monospaced, auto-refresh on companion events) while running; final transcript when ended. macOS session detail gains the same transcript tab for ended sessions.
- Accessibility identifiers: `session_terminal_view`, `session_button_takecontrol`, `session_textfield_nudge`, `session_button_nudge_send`, `session_button_restart`, `session_button_kill`, `session_button_minimize`, `session_transcript_view`.

## Error handling

- Attach failure (session gone, tmux missing): state → `.failed`, view falls back to the transcript view with a status message.
- Take Control re-attach failure: revert to read-only state with a toast.
- Kill/nudge/restart failures: toast via the existing store `errorMessage` pattern; optimistic UI only for detach (which cannot fail meaningfully).
- Companion capture failures: logged, skipped; transcript simply staler.
- Session ends while attached: PTY exits → controller transitions to `.detached`, view offers the final transcript.

## Testing

- Pure: `attachArguments` (read-only vs interactive), restart eligibility, transcript finalization logic, nudge argument construction (Core/CompanionKit unit tests).
- `TmuxControlling` fake drives controller state-machine tests (attach/take-control/detach/fail paths).
- SQLite: `session_transcripts` round-trip + legacy-DB migration test (house pattern).
- `CompanionClient.fetchTranscript` via MockURLProtocol; server handler covered through store tests.
- UI: source-text pins for the identifiers above; no XCUITest dependency.

## Out of scope

- iOS keystroke proxying (rejected — scope + security surface).
- Multiple simultaneous attached terminals (one center-panel attachment; rail chips for the rest).
- Terminal theming/preferences; transcript search; hermes gateway daemon sessions (this feature is about *coding-agent* tmux sessions per ADR-005 — Hermes profile daemons are not tmux sessions and are explicitly not in scope, see issue #157).

## Delivery shape

Three PR-sized slices: (1) Companion transcripts (capture loop, table, REST, client, detail views incl. iOS live view); (2) macOS attach (`SessionAttachmentController`, terminal view rework, take-control, minimize/restore); (3) lifecycle controls (nudge/kill/restart + LaunchConfig persistence). Slice 1 is independently valuable and unblocks the iOS experience first.
