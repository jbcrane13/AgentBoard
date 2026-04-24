# Interactive Terminal Sessions

**Date:** 2026-03-06
**Status:** Approved

## Goal

Embed a full interactive terminal in AgentBoard so complete dev flows — watching agent output, running commands, inspecting failures — can be done without leaving the app.

## Design Decisions

### Sidebar: enriched session rows
`SessionListView` rows get a second line of metadata: bead chip + model label. The status dot, session name, and elapsed time stay where they are. Stopped sessions are non-interactive (tap disabled, dimmed). Active session highlighted with background fill.

### Terminal pane: slim single-line toolbar
When a session is clicked, the center pane takes over (same `activeSessionID` mechanism as today). Toolbar layout (left to right): `← Board` button | vertical divider | session name | status pill | bead tag | elapsed | vertical divider | `Nudge ↵` button. Esc returns to board. The `← Board` button calls the existing `backToBoardFromTerminal()`.

### Terminal library: SwiftTerm
Add `migueldeicaza/SwiftTerm` via Swift Package Manager. It handles full VT100/xterm emulation, PTY management, and window resize — no custom terminal rendering needed.

Attach to existing sessions by spawning `tmux attach-session -t <session-name>` inside a PTY managed by SwiftTerm's `LocalProcessTerminalView`. The app's session discovery and `SessionMonitor` are unchanged.

## Scope

| File | Change |
|------|--------|
| `project.yml` | Add SwiftTerm SPM package |
| `AgentBoard/Views/Sidebar/SessionListView.swift` | Enrich rows with bead chip + model; disable tap on stopped sessions |
| `AgentBoard/Views/Terminal/TerminalView.swift` | Replace read-only output body with `InteractiveTerminalView`; keep slim toolbar shape |
| `AgentBoard/Views/Terminal/InteractiveTerminalView.swift` | New — `NSViewRepresentable` wrapping SwiftTerm's `LocalProcessTerminalView`, spawning `tmux attach-session` |

## What Does Not Change

- `AppState.activeSessionID`, `openSessionInTerminal()`, `backToBoardFromTerminal()` — state machine is correct as-is
- `SessionMonitor` — session discovery and polling unchanged
- New Session launch sheet — tmux session creation unchanged
- `ContentView.centerPanel` routing — already switches on `activeSession`

## Invariants

- Stopped sessions (`SessionStatus.stopped`, `.error`) are dimmed in the sidebar and do not call `openSessionInTerminal`.
- `InteractiveTerminalView` must handle the case where `tmux attach-session` fails (session name not found or tmux not running) — display an error message in the terminal area rather than crashing.
- Window resize events from SwiftTerm must propagate to the tmux PTY so the terminal reflows correctly when the user resizes the pane.
