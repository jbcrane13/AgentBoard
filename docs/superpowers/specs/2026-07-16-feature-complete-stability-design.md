# AgentBoard Feature-Complete & Stability Design

- **Date:** 2026-07-16
- **Status:** Approved
- **Author:** Blake Crane + Claude
- **Scope:** Bring the four core surfaces (Hermes chat, agent task kanban, GitHub issues board, dashboard) to feature-complete and stabilize the app. The LifeOps executive-assistant module (docs/PRD-lifeops-executive-assistant.md) is explicitly **out of scope** for this effort.

## Goals

1. Rich, feature-complete Hermes chat: block-level markdown, tool-use display, functional slash-command toggles, resolved history story, voice playback.
2. Agent task kanban at parity with the Work board: drag-and-drop and offline cache.
3. GitHub issues board simplified to three columns: To Do / In Progress / Resolved.
4. A new Dashboard home screen summarizing app state, fed by existing stores.
5. Known instability removed: crash path, hard-coded `gh` path, doc drift.

## Non-Goals

- LifeOps executive-assistant module (dashboard here is app-status only).
- Changes to the Hermes gateway or Companion service beyond what the app consumes.
- Reworking the `status:*` GitHub label schema (presentation remap only).

## Current State (verified 2026-07-15)

- **Chat** (`AgentBoardUI/Screens/ChatScreen.swift`, `ChatStore`, `HermesGatewayClient`): SSE streaming works; ~24 slash commands with autocomplete (`SlashCommandHandler`); conversation CRUD works; sync via Companion. Gaps: `MarkdownText` is inline-only + fenced code; no tool-call rendering; toggle commands (`/think`, `/web`, `/code`, `/image`, `/speak`, `/memory`, `/tools`) post a system message but change nothing; `/skills` always passes an empty list; `HermesGatewayClient.loadConversationHistory` is a stub returning `[]`; voice attachments record but don't play back (`VoiceViews.swift:142` TODO).
- **Agent kanban** (`AgentsScreen`, `AgentsStore`, `KanbanDataService` reading `~/.hermes/kanban.db`, writes via `KanbanCLIWriter`): 6 columns, create/complete/block/comment/reassign work. Gaps: no drag-and-drop; no SwiftData cache (DB reopened every refresh); agent summaries hard-code `activeSessionCount = 0` (`AgentsStore.swift:238`).
- **GitHub issues board** (`WorkScreen`, `WorkStore`, `GitHubWorkService`): most complete surface — REST API + `gh` CLI fallback, drag-and-drop, create/edit/close. Gaps: 4-column layout (Ready/In Progress/Review/Done) vs. desired 3; `gh` fallback path hard-coded to `/usr/local/bin/gh` (`GitHubWorkService.swift:302`).
- **Dashboard:** absent.
- **Stability:** `fatalError` in `AgentBoardBootstrap.makeLiveAppModel()` if SwiftData cache creation fails twice (`AgentBoardAppModel.swift:175`); README/AGENTS claim chat is "WebSocket JSON-RPC" but the client is HTTP POST `/v1/chat/completions` + SSE.
- **Tests:** ~388 unit tests in `AgentBoardTests`, healthy; no E2E UI smoke coverage.

## Design

Approach: **stabilize first, then vertical slices.** Each phase is an independent, PR-sized slice; every slice is filed as a GitHub issue (`type:` / `priority:` / `status:` labels) before work starts.

### Phase 0 — Stabilization

1. **`gh` path resolution** — replace the hard-coded `/usr/local/bin/gh` with resolution via `/usr/bin/env gh` (inherits PATH), falling back to probing `/opt/homebrew/bin/gh` and `/usr/local/bin/gh`. Unit-test the resolver.
2. **Remove crash path** — introduce a no-op cache conforming to `AgentBoardCacheProtocol`; `makeLiveAppModel()` degrades to cache-less mode instead of `fatalError` when both on-disk and in-memory SwiftData containers fail. Log the degradation.
3. **Doc drift** — update `README.md` and `AGENTS.md` transport description to HTTP + SSE (OpenAI-compatible `/v1/chat/completions`).
4. **Gate** — all three targets build, SwiftLint strict clean, full unit suite green on mac-mini.

### Phase 1 — Chat feature-complete

1. **Block-level markdown.** Add Apple's `swift-markdown` package; new renderer walks the AST and emits SwiftUI blocks: headings, ordered/unordered lists (nested), blockquotes, tables (horizontally scrollable), thematic breaks, paragraphs via `AttributedString` inline styling. Existing fenced-code-block presentation (language label, monospaced, horizontal scroll) is preserved. `MarkdownText` keeps its public interface so `ChatBubble` call sites don't change.
2. **Tool-use display.** Extend the SSE decoder in `HermesGatewayClient` to decode `delta.tool_calls` (and non-streaming `message.tool_calls`). Add a tool-call part to the chat message model (name, arguments JSON, optional result). `ChatBubble` renders tool calls as collapsible chips: collapsed shows the tool name + status; expanded shows pretty-printed arguments and result. Unknown/partial payloads render degraded, never crash the stream.
3. **Functional capability toggles.** `ChatStore` holds per-conversation capability flags (think/web/code/image/speak/memory/tools). Toggle commands flip flags and reflect state in `/status`. Flags map to request-body parameters on the gateway call. **Spike first**: probe the running Hermes gateway to confirm which parameters it honors; any unsupported capability falls back to system-prompt injection, clearly labeled in `/status`. Wire `/skills` to real skill discovery if the gateway exposes an endpoint; otherwise keep it listing the local slash-command skill category.
4. **Remote history resolution.** Spike: does Hermes expose a conversations/history endpoint? If yes, implement `loadConversationHistory` against it and reconcile with Companion sync. If no, formally designate the Companion as the history authority, delete the stub, and document the decision (ADR).
5. **Voice playback.** Implement the `VoiceViews.swift` TODO with `AVAudioPlayer`: play/pause button and progress indicator on voice attachments, one active playback at a time.

### Phase 2 — Agent task kanban parity

1. **Drag-and-drop.** Mirror the WorkScreen pattern: cards `.draggable(taskID)`, columns `.dropDestination`. Drop triggers optimistic status move → `KanbanCLIWriter` write → revert + error surface on failure. Valid transitions follow the existing `KanbanStatus` semantics (e.g., anything can move to `blocked`/`done`; `archived` stays out of the board).
2. **SwiftData cache.** Cache kanban tasks through the existing `AgentBoardCacheProtocol` so the board hydrates instantly on launch and renders the last snapshot when `~/.hermes/kanban.db` is unavailable. Refresh replaces the snapshot.
3. **Real agent activity.** Replace the hard-coded `activeSessionCount = 0` in `AgentsStore.buildAgentSummaries` with live session counts from the Companion sessions feed.

### Phase 3 — GitHub issues board: three columns

1. **Column mapping** (presentation only; `status:*` labels preserved):
   - **To Do** — open, `status:ready` or no `status:*` label.
   - **In Progress** — open, `status:in-progress` or `status:review` (`status:blocked` also lands here with a blocked badge on the card).
   - **Resolved** — closed issues.
2. **Transitions.** Drag to Resolved → close the issue. Drag out of Resolved → reopen + set the target `status:*` label. Drag between To Do and In Progress → swap labels as today.
3. **Update** `WorkState` mapping, `WorkStore.updateStatus`, board rendering, and all affected tests.

### Phase 4 — Dashboard home screen

1. **Navigation.** New `.dashboard` case in `AppDestination`; first tab on both macOS (sidebar) and iOS (tab bar).
2. **Content** — tiles fed entirely by existing stores via a lightweight view model derived from `AgentBoardAppModel` (no new services):
   - Agent tasks by status + currently running tasks (AgentsStore).
   - GitHub issue counts per column + recent activity (WorkStore).
   - Active sessions and companion/gateway health (SessionsStore + health checks).
   - Recent conversations with jump-to-chat (ChatStore).
3. **Interaction.** Tapping a tile navigates to its screen. Pull-to-refresh / refresh button triggers the shared refresh loop.
4. **Implementation notes.** Built with the frontend-design skill; every interactive element gets an `accessibilityIdentifier` per the `{screen}_{element}_{description}` convention (`dashboard_*`).

### Cross-cutting

- **TDD** per repo convention; tests run on mac-mini via SSH; SwiftLint strict; all three targets must build per PR.
- **Tracking:** one GitHub issue per slice with `type:` / `priority:` / `status:` labels; issues filed before implementation starts.
- **Rough shape:** ~8 PRs (Phase 0: 1, Phase 1: 3, Phase 2: 1–2, Phase 3: 1, Phase 4: 1–2).

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Hermes gateway may not support capability parameters or a history endpoint | Phase 1 opens with time-boxed spikes; defined fallbacks (system-prompt injection; Companion as history authority) so the phase cannot stall |
| `swift-markdown` AST rendering edge cases (nested lists, tables) | Snapshot-style unit tests over a corpus of representative markdown; degraded-but-safe rendering for unsupported nodes |
| Optimistic kanban DnD vs. CLI write failures | Revert-on-failure with visible error toast; unit tests for the revert path |
| 3-column remap breaks existing label-driven workflows | Labels are never removed/renamed — mapping is read-side + transition-side only |

## Success Criteria

- Chat renders headings, lists, tables, blockquotes, and tool calls; toggles change actual request behavior (or clearly-labeled fallback); voice notes play back; the history stub is gone (implemented or ADR'd away).
- Agent kanban supports drag-between-columns and renders from cache when the DB is unavailable.
- Issues board shows exactly To Do / In Progress / Resolved with working drag transitions including close/reopen.
- Dashboard is the first tab on both platforms and every tile navigates correctly.
- No `fatalError` in the bootstrap path; `gh` fallback works on Apple-silicon; docs match the code.
- Full unit suite green on mac-mini; SwiftLint strict clean; all three targets build.
