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

## 2026-07-20 — App icon / asset catalog
- xcodegen has **no `resources:` target key** — the repo's `resources: - path: SharedResources/Assets.xcassets` blocks were silently ignored for months, so the asset catalog (AppIcon AND AccentColor) never compiled into any app bundle; the app silently fell back to system-blue accent. Fix: list `.xcassets` under `sources:` (xcodegen auto-routes it to the resources phase) and set `ASSETCATALOG_COMPILER_APPICON_NAME`. The global "verify compiled output, not git diff" rule caught it: always `plutil -p Built.app/Contents/Info.plist | grep -i icon` + check for `Assets.car`.

## 2026-08-19 — Interactive sessions / live kanban / per-profile chat (ADR-020..022)

- **`hermes serve` is the :9119 dashboard, not the :8641 API gateway.** The `--help` text ("the JSON-RPC/WebSocket gateway the desktop app connects to") reads like the chat gateway but is a different service. The per-agent OpenAI-compatible gateways (Daneel 8641, Argus 8643, Quentin 8644, Friend 8645, Dessin 8646) are started by the user's own tooling; there is no `hermes` subcommand that brings them up. Don't try to start them to unblock a smoke test.
- **Tailscale is already a first-class gateway host.** `ChatEndpointValidator.isLocalOrPrivateHost` whitelists `100.64.0.0/10` (CGNAT), and the https-to-private-host rule only fires for `https`, so `http://100.x.y.z:8641` validates unchanged. ATS is open on both app targets. Remote gateways need no code change — only a profile URL + that profile's API key.
- **Kanban does NOT follow the gateway host.** `KanbanDataService` hardcodes `~/.hermes/kanban.db` and `KanbanCLIWriter` shells out to the *local* `hermes`. Point chat at another Mac and the board silently shows this Mac's tasks with no error, because the `task_events` poll simply never advances. Filed as #207.
- **Every meaningful feature addition trips a SwiftLint `--strict` size cap.** This change hit six at once (type_body_length x3, file_length, function_body_length, identifier_name for a 2-char `pi`). Budget for it: nested models -> `extension Type {}` in the same file (extensions don't count toward type body length), `@Model` records -> their own file (requires dropping `private`), catch blocks -> a named private helper.
- **A pre-commit hook runs SwiftFormat in lint mode on top of SwiftLint.** `swiftlint --strict` passing is not sufficient to commit; run `swiftformat --config .swiftformat AgentBoard AgentBoardTests` too. It enforces `hoistTry` and `wrapIfStatementBodies`, which hand-written test code violates constantly.
- **Fakes-only test suites hide SQL column-index drift.** Workstream B extended a 15-column `SELECT` to 22 and remapped `taskFromRow` by index, but every existing kanban test used a `KanbanDataReading` fake, so nothing would have caught an off-by-one. `KanbanDataService` takes an injectable `databasePath` — building a temp SQLite file in the test is cheap and is the only thing that actually guards the mapping. Added `KanbanDataServiceTests`.
- **Verify tmux attach mode from tmux, not from the UI.** `tmux -S ~/.tmux/sock list-clients -F 'readonly=#{client_readonly}'` returning `readonly=0` is the definitive proof that an interactive session attached read-write; a "Keyboard input live" banner is just a label.

## 2026-08-19 (later) — Remote kanban via the dashboard plugin API (ADR-023)

- **Mock-backed tests cannot catch wire-format surprises, because the fixtures encode the same assumptions as the code.** The HTTP kanban backend passed a full mock suite, then failed on the first live call. Three defects only a live cross-check found: `goal_mode` is a JSON **bool** though the SQLite column is `INTEGER`; `task_events.payload` is a JSON **object** though the column is `TEXT`; and events sharing an epoch second ordered differently between backends. Whenever a new backend is meant to be a drop-in for an existing one, run both against the same live data and diff field-by-field — that is the test that matters, and it is cheap: `swiftc -o /tmp/smoke main.swift <the few real source files>` builds a runnable binary straight from the app sources, no Xcode target needed.
- **Optional-everything is not drift tolerance.** Making every DTO field `Optional` only survives *missing* keys. A *type* change still throws and fails the entire decode — one bool blanked the whole board. Real tolerance needs lenient scalar wrappers (accept bool/int/string for a flag) plus per-element `Failable<T>` so one bad record drops instead of the container.
- **`ORDER BY created_at DESC` alone is nondeterministic** when Hermes writes several events in the same second (`spawned`/`claimed` routinely collide). Add `, id DESC`. This was latent in `KanbanDataService` before any of the HTTP work.
- **Hermes dashboard auth has two modes and they are not interchangeable** (`hermes_cli/web_server.py:448-475`): gated hosts (any remote) authenticate by session cookie from `POST /auth/password-login`, ungated loopback wants the ephemeral `window.__HERMES_SESSION_TOKEN__` scraped from the SPA HTML and echoed as `X-Hermes-Session-Token`. Distinguish them by the 401 body: `reason: no_cookie` means gated, a bare `{"detail":"Unauthorized"}` means the token path. A cookie sent to an ungated host is silently rejected.
- **A remote Hermes host's `config.yaml` `basic_auth.password` can be stale** when a `password_hash` is also present — the hash wins. Do not conclude the login flow is broken from a 401 with that plaintext.
- **The kanban dashboard API is a bundled plugin, not core**, which is why grepping `hermes_cli/web_routers/` for kanban routes finds nothing. It lives at `plugins/kanban/dashboard/plugin_api.py` and mounts under `/api/plugins/kanban/*`. When hunting a Hermes endpoint, read `GET /openapi.json` from the running server instead of grepping the source tree — it is authoritative and takes one call.
