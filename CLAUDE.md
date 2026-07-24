# AgentBoard — Claude Context

Swift 6 / SwiftUI app (macOS 26+ / iOS 26+) for driving Hermes agents: chat, two kanban boards (agent tasks + GitHub issues), sessions, dashboard. Feature-complete as of 2026-07-18 (`docs/implementation-status.md`).

## Build & verify (every PR)

- Project is **XcodeGen-managed**: edit `project.yml`, never `project.pbxproj` directly; run `xcodegen generate` after adding/removing files and commit the regenerated pbxproj.
- Three schemes must build: `AgentBoard` (macOS), `AgentBoardMobile` (iOS Simulator, `CODE_SIGNING_ALLOWED=NO`), `AgentBoardCompanion` (macOS tool).
- Full suite locally (gateway host): `xcodebuild test -scheme AgentBoard -configuration Debug -destination 'platform=macOS' -derivedDataPath ./DerivedData CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:AgentBoardTests` — **always pass `-derivedDataPath ./DerivedData`** (sandbox blocks `~/Library` DerivedData). mac-mini via SSH is the preferred runner when reachable.
- `swiftlint --strict` must be clean; a pre-commit hook enforces SwiftLint + SwiftFormat.
- New tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) matching neighboring files.
- After merging any PR that received bot-applied "Potential fix" commits, verify main still compiles before branching — those commits have broken main twice.

## Architecture ground truth (verified, don't re-derive)

- **Hermes gateway API server is on port 8641** (bearer key in `~/.hermes/config.yaml` under platforms.api_server.extra). Chat = HTTP POST `/v1/chat/completions` + SSE (NOT WebSocket). Tool activity = named SSE events `hermes.tool.progress`. Remote history = `/api/sessions/{id}/messages` + `X-Hermes-Session-Id` headers (ADR-014). The completions endpoint accepts ONLY `messages`/`stream`/`model` — capability toggles are client-side prompt injection. Route source: `~/.hermes/hermes-agent/gateway/platforms/api_server.py`.
- **`hermes kanban` CLI has no generic set-status** — transitions are semantic (promote/block/unblock/complete/archive); `running` is entered only by agent claim. `KanbanBoardMove` encodes the legal drag table.
- **Session→task joins are impossible in this deployment** (kanban tasks run inline inside long-lived per-profile gateway daemons; nothing externally observable maps daemon→task — see issue #157). Agent activity = running kanban tasks per assignee. Don't re-attempt the join.
- `AgentSummary.activeSessionCount` is populated for real only by the Companion's probe (`CompanionLocalProbe`); client-built summaries leave it 0. `CompanionClient.listAgents()` currently has no callers — it's a live but unconsumed feature; don't delete it.
- Test target imports **only AgentBoardCore + AgentBoardCompanionKit** as modules; `AgentBoardUI` sources compile directly into the app targets — unit-testable logic must live in Core; UI is covered by source-text pins (`AccessibilityIdentifierTests`, `NativeSwiftUIInterfaceTests`).

## Guardrails that bite mid-feature

- `NativeSwiftUIInterfaceTests` caps `ChatStore.swift`'s line count — spill new store logic into `ChatStore+Internals.swift`.
- SwiftLint caps actor body length (400) and file length — move private Codable structs to file scope or split extensions into `+Feature.swift` files.
- SwiftData cache records have **fixed column sets**: a new model field silently drops on cache round-trip unless the record type gains the column — write the round-trip test first (this bug shipped twice before the tests caught it).
- `CompanionSQLiteStore` migrations: `CREATE TABLE IF NOT EXISTS` won't alter existing tables — use the file's `PRAGMA table_info` + `ALTER TABLE` pattern. SQLite string binds from Swift need `SQLITE_TRANSIENT`, not `SQLITE_STATIC`.
- A qa-agent guard hook blocks Edit/Write tool payloads containing the dot-env secret-file pattern — it false-positives on SwiftUI's `.environment(` modifier (and on this very sentence); apply such edits via a bash/python script instead.

## Conventions

- Accessibility identifiers on every interactive element: `{screen}_{element}_{description}`.
- Issue tracking per global CLAUDE.md (`type:`/`priority:`/`status:` labels); phase plans live in `docs/superpowers/plans/`.
- Project lessons: `lessons-learned.md` (repo root); update at session end.
