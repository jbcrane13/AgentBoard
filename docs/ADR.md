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

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*
