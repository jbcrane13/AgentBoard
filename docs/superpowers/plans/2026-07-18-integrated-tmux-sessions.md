# Integrated tmux Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the integrated tmux-session experience per `docs/superpowers/specs/2026-07-18-integrated-tmux-sessions-design.md`: companion-persisted transcripts (+ iOS live view), macOS live read-only attach with Take Control, and lifecycle controls.

**Architecture:** Three sequential PR slices (M → N → O), each independently shippable. Slice M is transport-agnostic groundwork both platforms consume; N and O are macOS-centric. All decisions and non-goals are in the spec — read it first.

**Global Constraints:** identical to prior plans (Swift 6 strict concurrency, TDD, Swift Testing, SwiftLint strict, three schemes build, full suite green per PR — baseline 483; `xcodegen generate` for new files; `-derivedDataPath ./DerivedData`; accessibility ids per convention; the CompanionSQLiteStore migration + SQLITE_TRANSIENT house patterns; dot-env guard-hook workaround via scripts).

**Verified prior art (build on these, don't reinvent):**
- `CompanionLocalProbe` already has `captureOutput(for:)`, `nudge(session:)`, `stop(session:)` (~lines 143–170) — the probe knows how to capture panes and poke sessions.
- `CompanionServer.route` switches on `(method, pathComponents)` (~line 329; see `("GET", ["v1", "sessions"])` and `handleSessionAction`).
- `SessionLauncher` has `LaunchConfig` (~97), `ActiveSession` (~125), `activeSessions` (~187), `launch(config:)` (~205), `checkSession` (~258).
- `EmbeddedTerminalView` spawns an executable in a real PTY with interactive keystrokes; `SessionTerminalView` already embeds it (~line 149) — inspect how it's currently invoked before rework.
- `TmuxController` protocol + actor wraps tmux subprocess calls (`capturePane`, `openInTerminal`).

---

## PR M — Companion transcripts + iOS live view (slice 1)

1. **Store:** `session_transcripts` table in `CompanionSQLiteStore` — `(session_id TEXT PRIMARY KEY, content TEXT NOT NULL, updated_at INTEGER NOT NULL, is_final INTEGER NOT NULL DEFAULT 0)`, created + migrated per house pattern. Methods: `upsertTranscript(sessionID:content:isFinal:)`, `transcript(sessionID:) -> (content: String, updatedAt: Date, isFinal: Bool)?`, `finalizeTranscriptsExcept(activeSessionIDs:)`.
2. **Capture loop:** in the companion's refresh cycle (find where `CompanionLocalProbe.snapshot()` is polled — likely `AgentBoardCompanionMain`/server runtime), after each snapshot: for every live session call `probe.captureOutput` (bound scrollback ~2000 lines — check what captureOutput currently captures and extend with a `-S` depth if needed) and upsert; then `finalizeTranscriptsExcept(active)`. Best-effort: failures logged, never block discovery. Throttle to ~every 10s (not every snapshot if snapshots are more frequent).
3. **REST + client:** `GET /v1/sessions/{id}/transcript` route → JSON `{content, updatedAt, isFinal}`; `CompanionClient.fetchTranscript(sessionID:) -> SessionTranscript?` (new small Codable in Core), mirroring existing client call style.
4. **UI:** transcript view in session detail on BOTH platforms (`SessionDetailSheet` — monospaced, scrollable, `session_transcript_view` id). While the session is running, refresh on the existing companion event stream (find how SessionsStore reacts to events and hang refetch off the same path); when `isFinal`, static. This IS the iOS live view.
5. **Tests:** SQLite round-trip + legacy-migration + finalize logic; client fetch via MockURLProtocol; capture-throttle/finalize pure logic if extracted.

Branch `feat/tmux-transcripts`. Commits: `feat: companion session transcripts (capture + store + API)`, `feat: transcript view with live refresh in session detail`.

## PR N — macOS live attach + Take Control (slice 2)

1. **`SessionAttachmentController`** (new, Core, `@MainActor @Observable`): states `.detached/.attachedReadOnly(sessionName:)/.attachedInteractive(sessionName:)/.failed(message:)`; `attach(sessionName:)`, `takeControl()`, `releaseControl()`, `detach()`; pure `static func attachArguments(sessionName:readOnly:) -> [String]` (`["attach-session", "-r", "-t", name]` / without `-r`). The controller doesn't spawn processes itself — it publishes the desired command; the view layer owns the PTY (respect the existing EmbeddedTerminalView contract; check how it takes executable+args and how termination is observed).
2. **Terminal rework:** `SessionTerminalView` hosts the attached client: attach on appear via tmux path resolution (reuse whatever TmuxController/ShellEnvironment does to find tmux), re-attach on Take Control toggle (kill client PTY, respawn without `-r`), banner when interactive, swallow keystrokes at the view layer when read-only (defense in depth), `.failed` falls back to the PR M transcript view. Minimize kills the client PTY only and shows a restorable chip in the sessions rail (inspect the rail in `SessionsScreen`/`DesktopSidebar` and follow its existing item pattern). One attachment at a time — attaching another session detaches the first.
3. **Accessibility ids:** `session_terminal_view`, `session_button_takecontrol`, `session_button_minimize` (+ pin in source-text tests).
4. **Tests:** controller state machine with a fake command-runner seam; `attachArguments` matrix; source pins. PTY behavior is compile-verified (test target can't exercise UI).

Branch `feat/tmux-attach` (stacked on M). Commits: `feat: SessionAttachmentController with read-only/interactive attach`, `feat: live attached terminal with Take Control and minimize`.

## PR O — Lifecycle controls (slice 3)

1. **TmuxController:** add `sendKeys(name:text:)` (`send-keys -t <name> -l <text>` then `Enter` as a separate send) and `killSession(name:)` (`kill-session -t <name>`), wrapper style as existing; extend the `TmuxControlling` protocol + all fakes.
2. **SessionLauncher:** persist `LaunchConfig` by session name at launch (small Codable dict via `SettingsRepository`-style storage — inspect how launcher currently persists anything; if nothing, add a minimal UserDefaults-backed store in Core); `canRelaunch(sessionName:) -> Bool`; `relaunch(sessionName:) async -> String?` = killSession + launch(stored config). Foreign sessions: no restart.
3. **UI:** terminal header gains Nudge field + send (`session_textfield_nudge`, `session_button_nudge_send`), Restart (`session_button_restart`, only when `canRelaunch`), Kill with confirmation dialog (`session_button_kill`). Failures surface via the existing store `errorMessage`/toast pattern.
4. **Tests:** sendKeys/killSession argument construction via writer-fake pattern; LaunchConfig persistence round-trip; relaunch eligibility; source pins for the new ids.

Branch `feat/tmux-lifecycle` (stacked on N). Commit: `feat: session lifecycle controls — nudge, kill, restart`.

---

## Self-review notes
- The probe's existing `nudge`/`stop` (companion-side) vs new TmuxController `sendKeys`/`killSession` (app-side): PR O uses the APP-side path (macOS talks to tmux directly, same as attach); the companion primitives serve remote/iOS futures and stay untouched. If the probe's implementations are directly reusable app-side, prefer extracting shared argument-building into Core over duplicating.
- PR N's "view owns the PTY" split keeps the controller pure/testable given the UI-untestable constraint.
- Spec non-goals apply: no iOS input proxying, one attachment at a time, Hermes daemons out of scope.
