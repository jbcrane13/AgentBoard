# AgentBoard Implementation Status

Last updated: 2026-07-18

This document tracks what the Hermes-first rewrite currently has, what is only partial, and what remains unfinished.

## Documentation structure

- Active documentation lives in:
  - `docs/PRD.md` — product intent and scope
  - `docs/implementation-status.md` — this ledger
  - `docs/architecture.md` — structure and data flow
  - `docs/ADR.md` — major decisions (ADR-014 covers chat-history authority)
  - `docs/superpowers/specs/` + `docs/superpowers/plans/` — the 2026-07 feature-complete effort's design spec and per-phase implementation plans
- Pre-rewrite documentation is archived under `docs/archive/pre-rewrite/`.

## Feature-complete milestone (2026-07-16 → 2026-07-18)

The roadmap specced in `docs/superpowers/specs/2026-07-16-feature-complete-stability-design.md` is fully delivered (issues #138–#146 plus follow-ups #152/#155/#157, PRs #147–#163). Test suite grew 392 → 483 across the effort.

## Implemented Feature Areas

### Chat (Hermes gateway, HTTP + SSE on port 8641)

- Streaming replies via OpenAI-compatible `/v1/chat/completions` with SSE; connection state; multiple conversations; local snapshots; Companion cross-device sync.
- Block-level markdown rendering (headings, nested lists, tables, blockquotes, fenced code) via swift-markdown (`MarkdownBlockParser`).
- Live tool-activity chips from `hermes.tool.progress` named SSE events.
- Slash commands with autocomplete; `/think` `/web` `/code` `/image` `/speak` are functional per-conversation toggles (client-side prompt injection, labeled in `/status` — the gateway accepts no capability params); `/skills` lists real skills from `GET /v1/skills`.
- Remote history: conversations bind to Hermes gateway sessions via `X-Hermes-Session-Id`; empty synced conversations hydrate from `GET /api/sessions/{id}/messages` (ADR-014). `hermesSessionID` survives Companion sync (SQLite column + migration).
- Voice notes record and play back (`AudioPlaybackService`, AVAudioPlayer).

### Work (GitHub Issues board)

- Multi-repo issue loading (REST API + `gh` CLI fallback with Apple-silicon-aware path resolution), normalized work items, list + board presentation.
- Three-column board: To Do / In Progress / Resolved (`WorkBoardColumn`, presentation-only remap — `status:*` labels preserved). Blocked items carry a badge inside In Progress.
- Drag-and-drop with real transitions: drop on Resolved closes the issue, drag out reopens; header stat chips bucket identically to the columns.

### Agent Tasks (kanban, `~/.hermes/kanban.db`)

- Six-column board read from the kanban DB; writes via the `hermes kanban` CLI; create/complete/block/comment/reassign/archive.
- Drag-and-drop mapped to the CLI's semantic transitions (`KanbanBoardMove`: promote/block/unblock/complete); illegal drops (e.g. into Running — agent-claimed by design) revert with an explanatory message. Compact layout renders empty columns as drop targets.
- SwiftData cache: instant board render on launch; board stays visible with a "showing cached tasks" notice when the DB is unreachable.
- Agent rail activity = count of running kanban tasks per assignee (`activeTaskCount`). Session→task joins are impossible in this deployment (tasks run inline in per-profile gateway daemons); see issue #157 for the evidence and the Hermes-side change that would enable them.

### Dashboard

- First destination on both platforms. `DashboardSnapshot` aggregates existing stores (no new services): agent-task counts + running titles, work-item counts per column, sessions + sync status, chat connection + recent conversations. Tiles navigate; refresh button + pull-to-refresh.

### Sessions, Settings, Persistence

- Active/recent session display from the Companion (SQLite-backed REST + event stream), jittered auto-refresh, live events.
- Separate Hermes/GitHub/Companion configuration; Keychain secrets; SwiftData cache behind `AgentBoardCacheProtocol` (conversations, messages, work items, sessions, agent summaries, kanban tasks) with a `NoopAgentBoardCache` fallback instead of a crash when container creation fails.

## Stability posture

- No `fatalError` in the bootstrap path; degraded modes everywhere external services can be absent (gateway down, kanban.db missing, companion unreachable).
- 483 unit tests (Swift Testing + XCTest), SwiftLint strict, three schemes (AgentBoard, AgentBoardMobile, AgentBoardCompanion) build per PR.

## Unfinished / open

- **#157-adjacent:** per-agent *session* counts (as opposed to running-task counts) need a Hermes-side change (`_set_worker_pid` from the inline claim path) — parked; do not re-attempt an AgentBoard-side join. The companion's probe-based `activeSessionCount` is real but unconsumed by the app (`CompanionClient.listAgents()` has no callers).
- Session controls / deeper session detail / transcript UX remain open.
- Full GitHub issue editing beyond status + detail-sheet fields remains open.
- Companion runtime discovery is heuristic rather than production-grade.
- End-to-end UI smoke coverage (XCUITest) remains open; unit coverage is strong.
- LifeOps executive-assistant module (`docs/PRD-lifeops-executive-assistant.md`) is specced but intentionally out of scope / unimplemented.
- `DemoFixtures.swift` is orphaned (nothing references it) — cleanup candidate.

## Canonical Usage

- Use `docs/PRD.md` for product intent and scope.
- Use `docs/implementation-status.md` for implemented versus unfinished status.
- Use `docs/architecture.md` for structure and data flow.
- Use `docs/ADR.md` for major decisions.
