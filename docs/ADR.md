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
**Status:** Superseded by ADR-008  
**Decision:** Connect to OpenClaw gateway for chat and session management. WS for health/streaming, REST for chat completions.  
**Context:** AgentBoard is a frontend for OpenClaw workflows — needs to send messages and receive streaming responses.  
**Consequences:**
- `OpenClawService` actor handles gateway config, session fetch, chat streaming, WS lifecycle
- WS endpoint: `/ws` for connection health + ping
- Chat endpoint: `POST /v1/chat/completions` (SSE streaming with non-stream fallback)
- Config discovery reads `~/.openclaw/openclaw.json` for gateway URL and auth token
- Connection state model: connected/connecting/reconnecting/disconnected
- **Problem discovered:** REST endpoint was stateless — every message created a throwaway session instead of talking to the real main session. The `/api/sessions` REST endpoint didn't exist (returned SPA HTML). See ADR-008.

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
- Phase 2 (beads) ✅ — Kanban board with real beads data, FSEvents watcher
- Phase 3 (chat) ✅ — OpenClaw integration with markdown rendering (rewritten in ADR-008)
- Phase 4 (session monitor) ✅ — tmux inspection and status display
- Phase 5 (canvas) ✅ — WKWebView rendering, canvas protocol, split mode
- Phase 6 (polish) ✅ — Dark mode, keyboard shortcuts, git integration, agents/history views
- Detailed plan in `IMPLEMENTATION-PLAN.md`

---

## ADR-008: Gateway WebSocket RPC protocol for chat
**Date:** 2026-02-16  
**Status:** Active  
**Decision:** Replace the stateless REST `/v1/chat/completions` approach with the gateway's native WebSocket JSON-RPC protocol for chat, sessions, and agent identity.  
**Context:** The Phase 3 implementation used `POST /v1/chat/completions` which created throwaway sessions per request — the chat never actually talked to the main OpenClaw session. The `/api/sessions` REST endpoint didn't exist. Investigation of the gateway source revealed it uses a WebSocket JSON-RPC protocol with methods like `chat.send`, `chat.history`, `sessions.list`, `sessions.patch`, and streaming via `chat` events.  
**Consequences:**
- New `GatewayClient` actor implements the WebSocket JSON-RPC protocol (request/response with UUIDs, event stream, connect handshake with token auth, protocol version 3)
- `OpenClawService` simplified to a thin wrapper around `GatewayClient`
- Chat now connects to the real main session and shows actual conversation history
- Gateway events stream chat responses (delta messages contain full accumulated text, not incremental)
- Session switching: users can pick which session to chat with via `sessions.list`
- Thinking level control via `sessions.patch` (Default/Low/Medium/High)
- Agent identity loaded via `agent.identity.get` — shows real agent name instead of hardcoded "AgentBoard"
- Abort button for stopping generation via `chat.abort`
- Gateway session list refreshes every 15 seconds
- `JSONPayload` wrapper for `[String: Any]` to satisfy Swift 6 strict concurrency (`@unchecked Sendable`)
- Spec documented in `docs/CHAT-REWRITE-SPEC.md`

---

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences.*

---

## ADR-009: Always-fresh gateway config discovery
**Date:** 2026-02-18  
**Status:** Active  
**Decision:** Always re-read gateway URL and auth token from `~/.openclaw/openclaw.json` on launch (in "auto" mode), and allow users to manually configure gateway connection settings.  
**Context:** After a gateway reinstall, the auth token changed but AgentBoard had cached the old token in `~/.agentboard/config.json`. The `hydrateOpenClawIfNeeded` method only filled nil values, so the stale token was never refreshed — causing silent connection failures. Additionally, `discoverOpenClawConfig` looked for `gateway.url` which doesn't exist in openclaw.json (the URL must be constructed from `gateway.port` + `gateway.bind`). For users running non-standard gateway configurations (remote hosts, custom ports), there was no way to manually enter the connection details.  
**Consequences:**
- `AppConfig` gains `gatewayConfigSource` field: `"auto"` (default) syncs from openclaw.json every launch; `"manual"` preserves user-entered values
- `discoverOpenClawConfig` now constructs URL from `gateway.port` (default 18789) and `gateway.bind` (default loopback → 127.0.0.1)
- In auto mode, gateway URL and token are always refreshed from openclaw.json — never stale
- Settings UI now has Auto/Manual picker, read-only display with Refresh button (auto mode), editable fields (manual mode), and a Test Connection button
- `discoverOpenClawConfig` made `func` (not `private`) so SettingsView can call it for refresh
- Breaking change: none (new field defaults to nil which is treated as "auto")

