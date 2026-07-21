# Architecture Decision Records — AgentBoard

A running log of significant architecture and design decisions. Both Daneel (Hermes) and coding agents should consult this before making structural changes, and append new entries when decisions are made.

**Format:** Date → Decision → Context → Consequences

---

## ADR-001: Native macOS SwiftUI app
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** Build AgentBoard as a native macOS SwiftUI app targeting macOS 15+.  
**Context:** Need a purpose-built interface for AI-assisted dev workflows — tracking work, communicating with agents, and reviewing output. Web UI would lose native integration with tmux, filesystem, and system APIs.  
**Consequences:**
- Swift 6, SwiftUI
- Bundle ID: `com.agentboard.AgentBoard`
- Three-panel layout: sidebar (projects + sessions), center (Kanban/board), right (chat + canvas)
- Window default 1280x820, minimum 900x600

---

## ADR-002: XcodeGen for project management
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** Use `project.yml` as source of truth, regenerate `.xcodeproj` via xcodegen.  
**Context:** Same reasoning as NetMonitor — avoid merge conflicts, enable agent-driven project changes.  
**Consequences:**
- Run `xcodegen generate` after target/scheme edits
- Build settings must live in `project.yml`

---

## ADR-003: Beads integration for Kanban board
**Date:** 2026-02-14  
**Status:** Superseded by ADR-011  
**Decision:** ~~Use `beads` (`bd` CLI) as the backing store for the Kanban board, watched via FSEvents.~~  
**Context:** Beads already tracked issues in-repo for all projects. AgentBoard should read from the same source rather than creating a separate task system. beads is now fully decommissioned across all projects.  
**Consequences (historical):**
- `BeadsWatcher` service watched `.beads/` directory via FSEvents (removed)
- Board columns mapped to beads statuses (removed)
- Replaced by kanban.db in ADR-011

---

## ADR-004: OpenClaw integration via WebSocket + REST
**Date:** 2026-02-15  
**Status:** Superseded by ADR-008, then ADR-010  
**Decision:** Originally connected to OpenClaw gateway for chat and session management. Later migrated to Hermes gateway.  
**Context:** AgentBoard is a frontend for agent workflows. OpenClaw was replaced by Hermes in ADR-010.  

---

## ADR-005: tmux-based session monitoring
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Monitor coding agent sessions via tmux socket inspection + process table scanning.  
**Context:** Claude Code, Codex CLI, and other agents run in tmux sessions. AgentBoard needs to show what's running and capture output.  
**Consequences:**
- `CompanionLocalProbe` uses tmux `/usr/bin/env tmux list-panes` + `ps -axo pid=,args=`
- Agent detection by command name (`claude`, `codex`, `opencode`, `hermes-agent`)
- Session status derived from process detection
- Terminal pane capture for output preview

---

## ADR-006: SwiftTerm for terminal rendering
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** Use SwiftTerm library for rendering terminal output in the session monitor view.  
**Consequences:**
- SwiftTerm dependency via SPM (from `migueldeicaza/SwiftTerm`)
- Terminal view embeds SwiftTerm for pane output rendering

---

## ADR-007: Phased implementation plan
**Date:** 2026-02-14  
**Status:** Completed  
**Decision:** Six phases: 1-Skeleton → 2-Beads → 3-Chat → 4-Session Monitor → 5-Canvas → 6-Polish. All phases completed. Rewritten post-ADR-010.

---

## ADR-008: Gateway WebSocket RPC protocol for chat
**Date:** 2026-02-16  
**Status:** Active  
**Decision:** Use the gateway's native WebSocket JSON-RPC protocol for chat, sessions, and agent identity.  
**Consequences:**
- `GatewayClient` actor implements the WebSocket JSON-RPC protocol
- Chat connects to real main session and shows conversation history
- Gateway events stream chat responses
- Session switching, thinking level control, abort support

---

## ADR-009: Always-fresh gateway config discovery
**Date:** 2026-02-18  
**Status:** Active  
**Decision:** Always re-read gateway config on launch in "auto" mode. Allow manual configuration.  
**Consequences:**
- `AppConfig.gatewayConfigSource`: "auto" (default) syncs every launch; "manual" preserves user-entered values
- Settings UI with Auto/Manual picker and Test Connection button

---

## ADR-010: Hermes-first shared SwiftUI rebuild
**Date:** 2026-04-23  
**Status:** Active  
**Decision:** Replace the earlier OpenClaw/beads/macOS-only app with a shared SwiftUI architecture targeting both macOS and iOS, backed by `AgentBoardCore`, GitHub Issues, Hermes gateway chat, and a companion service.  
**Consequences:**
- `AgentBoard` (macOS) and `AgentBoardMobile` (iOS) app shells
- `AgentBoardCore` owns shared state via `ChatStore`, `WorkStore`, `AgentsStore`, `SessionsStore`, `SettingsStore`
- Hermes gateway is the chat transport
- Old OpenClaw/beads/SwiftTerm/canvas code removed from active tree

---

## ADR-011: Kanban.db as task backend, decommission companion task store
**Date:** 2026-05-01  
**Status:** Active  
**Decision:** Replace `AgentTask`/`AgentTaskDraft`/`AgentTaskPatch` types, the companion server's task CRUD routes, and `AgentBoardCache`'s `CachedTaskRecord` with a single source of truth: `~/.hermes/kanban.db`.

Reads: `KanbanDataService` (SQLite3 open/read/close on kanban.db)  
Writes: `KanbanCLIWriter` (subprocess → `hermes kanban` CLI)

**Context:** The companion server was doing double duty — monitoring live tmux/agent sessions AND managing task state. Three problems:

1. **Two sources of truth** — tasks existed in both companion SQLite and kanban.db, no sync
2. **Write contention risk** — both AgentBoard and Hermes dispatcher touching kanban.db
3. **Ghost REST API** — companion task CRUD existed but wasn't integrated with kanban.db

Hermes gateway already owns kanban.db. Route all writes through the same CLI path. AgentBoard is read-mostly viewer + write-through proxy.

**Consequences:**

*New files:*
- `AgentBoardCore/Models/KanbanModels.swift` — `KanbanTask`, `KanbanComment`, `KanbanRun`, `KanbanCreateDraft`
- `AgentBoardCore/Services/KanbanDataService.swift` — read-only SQLite access
- `AgentBoardCore/Services/KanbanCLIWriter.swift` — `hermes kanban` subprocess writer

*Rewritten:*
- `AgentBoardCore/Stores/AgentsStore.swift` — kanban columns by status, full task lifecycle

*Removed:*
- `AgentTaskState`, `AgentTask`, `AgentTaskDraft`, `AgentTaskPatch` from `DomainModels.swift`
- `CachedTaskRecord` + `loadTasks()`/`replaceTasks()` from `AgentBoardCache.swift`
- Task CRUD routes from `CompanionServer.swift`
- Task CRUD methods from `CompanionSQLiteStore.swift` and `CompanionClient.swift`
- `CompanionEventKind.tasksChanged`
- `AgentTask` dependency from `CompanionLocalProbe.snapshot()`

*App icon:* Kanban-themed dark icon generated for all 10 macOS sizes in `SharedResources/Assets.xcassets/AppIcon.appiconset/`.

*Quality:* Build verified clean (macOS), SwiftLint 0 violations, SwiftFormat passing, pre-push build gate active.

### Architecture

```
Read  → KanbanDataService → SQLite (kanban.db)
Write → KanbanCLIWriter → hermes kanban CLI → Gateway Dispatcher
Sessions → CompanionServer → tmux/process scanning
Agents → CompanionServer → FSEvents + ps
```

---

## ADR-012: Companion-backed cross-device session and chat sync
**Date:** 2026-05-18
**Status:** Active
**Decision:** Treat the companion service as the cross-device source of truth for live sessions and chat history, while preserving local SwiftData as the offline cache.

**Context:** macOS and iOS can point at the same companion service over loopback, LAN, or Tailscale. Loading sessions or conversations from only device-local SwiftData makes each device show stale or incomplete state.

**Consequences:**
- `SessionsStore.bootstrap()` fetches companion sessions first and falls back to cache only when companion is unreachable.
- `ChatStore.bootstrap()` fetches companion conversations and messages first, then writes snapshots back to local cache.
- `CompanionSQLiteStore` owns companion conversation/message persistence, including message attachments.
- `CompanionServer` exposes conversation list, message list, sync, and delete routes, and publishes `conversationsChanged` events for cross-device refresh.
- `CompanionClient` is the shared app-side API for session and conversation sync.

---

## ADR-013: Native SwiftUI app shell controls
**Date:** 2026-05-23
**Status:** Active
**Decision:** Use platform-native SwiftUI shell controls for the macOS and iOS apps, and reserve bespoke styling for feature content rather than the app frame.

**Context:** The Hermes-first rebuild shipped with a heavily custom app shell: manual desktop sidebars, custom tab buttons, UIKit tab-bar appearance overrides, and hidden macOS title-bar behavior. That visual direction made the app feel less native on both macOS and iOS and made shell-level regression coverage hard to state.

**Consequences:**
- `AgentBoard` uses `NavigationSplitView`, a source-list `List`, SwiftUI toolbar actions, and an inspector-style chat panel.
- `AgentBoardMobile` uses tagged SwiftUI `TabView(selection:)` navigation and no UIKit tab-bar appearance override.
- macOS keeps standard window chrome instead of hiding the title bar.
- `NativeSwiftUIInterfaceTests` guards the shell-level native SwiftUI contracts.

---

## ADR-014: Hermes sessions as remote chat-history authority
**Date:** 2026-07-17
**Status:** Active
**Decision:** Hermes gateway sessions (`/api/sessions`, `X-Hermes-Session-Id` continuity) are the remote history source for chat; the Companion service remains the cross-device sync channel for conversation metadata and local snapshots; the old `loadConversationHistory` stub is removed.

**Context:** `HermesGatewayClient.loadConversationHistory` was a dead stub that always returned `[]`. The live Hermes gateway (v0.18.2) exposes a real sessions API: streaming `/v1/chat/completions` responses carry an `X-Hermes-Session-Id` response header identifying the server-side session, and `GET /api/sessions/{session_id}/messages` returns that session's persisted transcript — verified live on 2026-07-17.

**Consequences:**
- `ChatConversation` carries an optional `hermesSessionID`, set from the streaming response header and persisted with the conversation.
- `HermesGatewayClient.streamReply` accepts a `sessionID` to continue an existing Hermes session and yields a `.sessionID` event when the gateway reports one.
- `ChatStore` best-effort hydrates a conversation's messages from `fetchSessionMessages` when it has a `hermesSessionID` but no local messages loaded yet; local state always wins over hydration.
- `HermesGatewayClient.loadConversationHistory` is removed.

---

## ADR-015: Replace neumorphic chrome with native macOS/iOS UI
**Date:** 2026-07-19
**Status:** Active
**Decision:** Drop the custom neumorphic (skeuomorphic dual-shadow, gradient, extruded/recessed) design system in favour of standard macOS/iOS chrome. The change is implemented by reimplementing the shared theme primitives in `AgentBoardUI/Theme/NeumorphicTheme.swift` under their existing public names so all ~24 screens adopt the new look without per-screen edits.

**Context:** The Hermes-first rebuild shipped a heavily custom neumorphic theme. That made the app feel non-native and doubled down on hand-rolled shadows/gradients that the platform already provides for free. Because the whole design system is centralized (palette, background, `.neuExtruded`/`.neuRecessed`, `NeuButtonTarget`, `NeuTextField`/`NeuSecureField`), a single-file rewrite of the primitives propagates everywhere.

**Consequences:**
- `NeuPalette` surfaces/text now read platform-native colours (`NSColor.windowBackgroundColor`/`labelColor`/… on macOS, `UIColor.systemBackground`/`label`/… on iOS), so light and dark mode adapt automatically. Accent (brand teal) and status colours are preserved for the kanban pills.
- `NeuBackground()` is the plain window background (no gradient).
- `.neuExtruded()` → `.regularMaterial` rounded card + hairline border + single subtle shadow. `.neuRecessed()` → flat grouped-background inset.
- `NeuButtonTarget(isAccent:)` → native bordered / borderedProminent look with system pressed-state opacity.
- `NeuTextField`/`NeuSecureField` → `.textFieldStyle(.roundedBorder)`.
- The public API of the primitives is unchanged, so screens compile as-is; a per-screen idiomatic re-layout (macOS `Form` groupings, iOS inset-grouped `List`) is a possible follow-up.

---

## ADR-016: Native Apple / Liquid Glass design language (completes ADR-015)
**Date:** 2026-07-20
**Status:** Active
**Decision:** Complete the native-chrome direction ADR-015 started: adopt system semantic colors and materials as the actual visual language (not just platform-native surface *colours*), replacing the brand-teal accent with the system accent color, removing permanent card/bubble shadows, and adding real `glassEffect`/`Material` translucency on floating chrome. Supersedes ADR-015's "brand teal preserved" detail and ADR-010's visual direction; this is the concrete implementation of the redesign scoped in `docs/superpowers/specs/2026-07-19-native-ui-redesign-design.md`.

**Context:** ADR-015 (2026-07-19) moved surface/text/background colours onto `NSColor`/`UIColor` so light/dark adapted automatically, but kept a bespoke brand-teal `Color(red:green:blue:)` literal for the accent, kept a permanent drop shadow on `.neuExtruded()`, and had no glass/material treatment on floating chrome (compose bar, terminal header). A follow-up design pass (`2026-07-19-native-ui-redesign-design.md`, approved by Blake) specified a stricter, more literal native/Liquid-Glass treatment — system accent color, material-backed flat cards with no permanent elevation, and `glassEffect` on the two surfaces where it reads well. This ADR records that refinement; issue #183 tracked the implementation (PR P, `feat/native-ui-tokens`).

**Consequences:**
- `NeuPalette.accentCyan`/`accentCyanBright`/`accentForeground` now read `Color.accentColor` (the project's existing `AccentColor` asset) instead of a hardcoded teal RGB literal; `accentCoral` maps to system `.red`; `statusClosed` maps to `.secondary`. A new `NeuPalette.surfaceMaterial: Material` sibling accessor lets call sites opt into a real material without changing the existing `Color`-typed tokens.
- `NeuExtrudedModifier` (shared card chrome) drops its permanent drop shadow — cards are flat at rest; `.draggable()`'s own system lift/shadow covers the "elevated while dragging" case with no bespoke `isDragging` plumbing.
- `NeuChatBubble` differentiates by role: assistant on `.regularMaterial` with a hairline stroke, user on an accent-tinted fill with white text (justified: text on accent fill), system/info on a quiet `.tertiary` fill — replacing the old binary assistant/other split and its permanent shadow.
- `glassEffect(.regular)` lands on the chat compose bar. The session terminal header degrades to `.thinMaterial` per the design spec's explicit legibility fallback (dense status pills/buttons over a busy live-terminal backdrop); the terminal content itself stays fully opaque.
- `MarkdownText`/`MarkdownBlockView` no longer hardcodes `.white` prose, `.green` code text, or `Color.black` code/table backgrounds — prose inherits its caller's ambient foreground (so `NeuChatBubble`'s per-role text color actually takes effect), de-emphasized accents use `.secondary`/`.separator`, and code/table blocks sit on their own `inset` fill with explicit `.primary` text.
- Repo-wide sweep of every remaining `.white`/`Color.black` hit in `AgentBoardUI`/`AgentBoard`/`AgentBoardMobile`: `LaunchSessionSheet`/`QuickLaunchSheet`'s selected-row highlight (was invisible-to-wrong `Color.white.opacity(0.05)` against light backgrounds) is now a semantic `NeuPalette.accentCyan.opacity(0.12)` tint; the remaining hits (compose bar stop-button icon, accent foreground, chat bubble user text, the fullscreen media viewer's fixed black/white chrome, attachment thumbnail overlay badges) are justified in place as text/icon-on-fixed-fill.
- The Settings theme picker UI is removed (appearance now follows the system); the underlying `designTheme` store plumbing and `NeuTheme.preset`/`NeuPalette.apply` machinery are left in place for PR Q's mechanical `NeuPalette → AppTheme` rename and cleanup.
- `DesignSemanticsTests` is re-pinned as the regression fence: it asserts `NeumorphicTheme.swift`'s accent tokens resolve to `.accentColor` (not a brand-RGB literal), that `NeuExtrudedModifier` carries no permanent shadow, and that the shared chrome components (`MarkdownText`, `BoardChrome`, `ChatBubble`) don't hardcode `.white`/`Color.black` outside the one documented justified case.

---

## ADR-017: GitHub CLI fallback must preserve REST request semantics
**Date:** 2026-07-20
**Status:** Active
**Decision:** When the macOS Work service falls back from a rejected stored GitHub token to the authenticated `gh` CLI, invoke `gh api` with an explicit `--method GET` before adding query fields.

**Context:** `gh api -f state=all` defaults to POST unless the method is explicit. The previous fallback therefore posted to the issues collection, received HTTP 422 (`title` missing), and surfaced the result as “GitHub repository not found.” A stale Keychain token then left the entire Work board empty despite a valid `gh` login.

**Consequences:**
- A stale or under-scoped in-app token can still use the local authenticated `gh` session for Work reads.
- A regression test drives the full 401-to-CLI path with a fake executable that accepts only `--method GET`.
- Token-backed REST remains the primary cross-platform path; the CLI fallback remains macOS-only.

---

## ADR-018: Drain subprocess output while the process is running
**Date:** 2026-07-20
**Status:** Active
**Decision:** `Process.runAsync` must consume stdout and stderr concurrently from process launch through termination rather than waiting for the child to exit before reading either pipe.

**Context:** The GitHub Work fallback can return hundreds of kilobytes of issue JSON. The previous implementation read both pipes only inside `terminationHandler`; once stdout exceeded the system pipe capacity, `gh` blocked waiting for a reader while AgentBoard waited for `gh` to exit. Auto-refresh then accumulated additional blocked children and left the Work board empty.

**Consequences:**
- Shared subprocess execution drains both streams on background queues and joins the captured data after termination.
- Commands that emit large stdout or stderr payloads no longer deadlock.
- Launch failures close both write handles so collector reads can reach EOF.
- `ProcessAsyncTests` guards simultaneous one-megabyte stdout and stderr capture.

---

## ADR-019: Agent launches use canonical projects and isolated Git worktrees
**Date:** 2026-07-21
**Status:** Active
**Decision:** Resolve each launch's GitHub repository through the Hermes project registry before using the legacy `~/Projects/<repo>` fallback, and prepare a stable session-specific Git worktree under `~/.agentboard/worktrees/` before writing the PRD or launching tmux. Generated PRDs are repository-neutral and defer toolchain rules to repository-local agent instructions.

**Context:** AgentBoard previously derived every checkout as `~/Projects/<GitHub repo name>` and launched all sessions directly in that mutable checkout. LeadScout's canonical Hermes project is `/Users/blake/Projects/LeadFeed`, so issue #40, #51, and #54 sessions were instead launched in a second `/Users/blake/Projects/LeadScout` clone. Those sessions shared one branch and working tree, mixing unrelated issue commits and leaving issue #54 changes uncommitted. The generated PRDs also imposed AgentBoard-specific Swift 6, accessibility-identifier, and `xcodebuild` instructions on the TypeScript/Electron LeadScout repository.

**Consequences:**
- A matching `repo:` entry in `~/.hermes/projects.yaml` selects the canonical checkout; repositories absent from the registry retain the existing `~/Projects/<repo>` fallback.
- Each tmux session gets a stable `agentboard/<session-name>` branch and worktree under `~/.agentboard/worktrees/<canonical-directory>/<session-name>`; relaunching the same session reuses its worktree while different sessions cannot share one.
- PRDs are written inside the prepared worktree, so the agent sees its task file without dirtying the canonical checkout.
- Cross-repository presets describe implementation, tests, review, and repository-defined quality gates without assuming Swift, Xcode, or AgentBoard accessibility conventions.
- Worktrees are intentionally retained after a session exits so incomplete work remains recoverable; cleanup is an explicit lifecycle operation rather than an automatic destructive step.

---

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*
