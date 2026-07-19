# AgentBoard Lessons Learned

Project-specific lessons. Global lessons live in `~/.claude/lessons-learned.md`.

## 2026-07-19 issue #12 RED phase (assignee forwarding tests)

- **The pre-commit hook can silently drop staged *modified* files from a commit** — a 3-file commit landed with only the newly added file; the two modified files were left staged-but-uncommitted. Always check `git show --stat HEAD` after committing. A guardrail hook also blocks `git push --force-with-lease`, so recover with a follow-up commit, not an amend.

## 2026-07 feature-complete effort (issues #138–#146 + follow-ups, PRs #147–#163)

### Process

- **Bot-applied "Potential fix for pull request finding" commits broke main twice** (#151's merge → `VoicePlaybackView` braces, #154's merge → `KanbanBoardMove` braces). They bypass the branch's test run entirely. Either stop applying them at merge time, or build-check main immediately after any merge that included one. Hotfixes: #153, #158.
- **Spike against the live system before planning integrations.** Reading the Hermes gateway's actual route table (`api_server.py`) and probing live endpoints overturned three design assumptions in one hour: tool calls arrive as named SSE events (not `delta.tool_calls`), a real sessions/history API exists, and the app's default port (8642) was wrong (live server: 8641).
- **"Prove it or report the dead end" beats best-effort wiring.** The #157 session→task join was refuted empirically (worker_pid never populated; session ids in-process only; tmux names GitHub-keyed). Refusing to ship an inert or fabricated mapping led to a simpler, honest fix (running-task counts) and −181 lines.
- **Subagents should surface design conflicts before acting.** Two scope corrections mid-flight (duplicate rail counters; the companion's real-but-unconsumed session-count feature) each avoided shipping something wrong. Verify subagent claims independently: re-run the suite yourself before pushing.

### Technical

- SwiftData cache records silently drop fields their record type lacks — full-fidelity round-trip tests (assert every field) are mandatory when touching models that get cached. Caught `hermesSessionID` (would not have persisted) and prevented a repeat on kanban tasks.
- `CompanionSQLiteStore` schema changes need the `PRAGMA table_info` + `ALTER TABLE` migration pattern; `CREATE TABLE IF NOT EXISTS` does nothing for existing DBs. Swift-bridged C strings in SQLite binds need `SQLITE_TRANSIENT`.
- Recursive SwiftUI `@ViewBuilder` functions produce self-referential opaque-type errors — recurse through a nominal `View` struct instead (see `MarkdownBlockView`).
- A horizontal `ScrollView` inside a chat bubble is greedy on its scroll axis and forces full-width bubbles — use plain stacks for chip rows.
- `MobileRootView`'s tab selection was bound to local `@State`, silently breaking all programmatic navigation on iOS — bind selection to the app model (`@Bindable`) whenever any code needs to navigate.
- The test target can only import Core/CompanionKit; UI files compile into app targets. Testable logic goes in Core; UI is pinned via source-text tests.
- Architecture guardrails to plan around: `ChatStore.swift` line-count cap (use `ChatStore+Internals.swift`), SwiftLint actor-body/file-length caps (file-scope structs, `+Feature.swift` extensions).
- Hermes deployment reality: kanban tasks execute inline in long-lived per-profile gateway daemons — per-task process identity does not exist externally. Any "which task is this agent running" feature must come from kanban.db state, not process observation, unless Hermes itself changes.

## 2026-07-19 issue #12 assignee forwarding

### Process

- **Two agent sessions sharing one checkout race each other's git operations.** A concurrent process's crashed commit left a stale `index.lock`, its commit message got attached to this session's staged files, `git stash` captured its uncommitted `KanbanCLIWriter` rework (nearly lost when the stash was dropped — recovered via the stash SHA), and it reset/renamed branches mid-session. Before any stash/reset/amend, run `git status` + check for other live sessions; verify every commit's stat AND message immediately after creating it; never drop a stash without `git show --stat` on it first.
