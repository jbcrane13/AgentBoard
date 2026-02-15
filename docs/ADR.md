# Architecture Decision Records — AgentBoard

A running log of significant architecture and design decisions. Both Daneel (OpenClaw) and Claude Code sessions should consult this before making structural changes, and append new entries when decisions are made.

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
**Status:** Active  
**Decision:** Use `beads` (`bd` CLI) as the backing store for the Kanban board, watched via FSEvents.  
**Context:** Beads already tracks issues in-repo for all projects. AgentBoard should read from the same source rather than creating a separate task system.  
**Consequences:**
- `BeadsWatcher` service watches `.beads/` directory via FSEvents
- Board columns map to beads statuses: Open → In Progress → Blocked → Done
- No separate database for tasks
- CLI and AgentBoard UI are interchangeable views of the same data

---

## ADR-004: OpenClaw integration via WebSocket + REST
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Connect to OpenClaw gateway for chat and session management. WS for health/streaming, REST for chat completions.  
**Context:** AgentBoard is a frontend for OpenClaw workflows — needs to send messages and receive streaming responses.  
**Consequences:**
- `OpenClawService` actor handles gateway config, session fetch, chat streaming, WS lifecycle
- WS endpoint: `/ws` for connection health + ping
- Chat endpoint: `POST /v1/chat/completions` (SSE streaming with non-stream fallback)
- Config discovery reads `~/.openclaw/openclaw.json` for gateway URL and auth token
- Connection state model: connected/connecting/reconnecting/disconnected

---

## ADR-005: tmux-based session monitoring
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Monitor coding agent sessions via tmux socket inspection + process table scanning.  
**Context:** Claude Code, Codex CLI, and other agents run in tmux sessions. AgentBoard needs to show what's running and capture output.  
**Consequences:**
- `SessionMonitor` actor uses tmux socket `/tmp/openclaw-tmux-sockets/openclaw.sock`
- Discovery: `tmux list-sessions` + `tmux list-panes` + `ps -axo pid,ppid,pcpu,command`
- Agent detection by command name (`claude`, `codex`, `opencode`)
- Session status derived from process detection and CPU activity
- Terminal pane capture for output preview

---

## ADR-006: SwiftTerm for terminal rendering
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** Use SwiftTerm library for rendering terminal output in the session monitor view.  
**Context:** Need to display live terminal output from tmux panes. SwiftTerm handles ANSI escape codes, colors, and cursor positioning natively.  
**Consequences:**
- SwiftTerm dependency in Package.swift
- Terminal view embeds SwiftTerm for pane output rendering

---

## ADR-007: Phased implementation plan
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** Six phases: 1-Skeleton → 2-Beads → 3-Chat → 4-Session Monitor → 5-Canvas → 6-Polish.  
**Context:** Incremental delivery, each phase buildable and testable.  
**Consequences:**
- Phase 1 (skeleton) ✅ — three-panel layout with placeholders
- Phase 3 (chat) ✅ — OpenClaw integration with markdown rendering
- Phase 4 (session monitor) ✅ — tmux inspection and status display
- Phase 2 (beads), 5 (canvas), 6 (polish) remaining
- Detailed plan in `IMPLEMENTATION-PLAN.md`

---

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*
