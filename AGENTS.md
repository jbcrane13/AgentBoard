# Agent Instructions

This project uses **GitHub Issues** (`gh` CLI) for issue tracking. Repo: `jbcrane13/AgentBoard`.

## Agent Readiness

**Read `docs/agent-readiness/README.md` before starting any work session.**

It contains the current agent readiness score, conventions, key file locations, and quality gate commands. Treat it as the source of truth for active tooling rules.

Quick orientation:
- **Lint:** `swiftlint lint --strict`
- **Build macOS:** `xcodebuild -scheme AgentBoard -destination 'platform=macOS' build`
- **Build iOS:** `xcodebuild -scheme AgentBoardMobile -destination 'generic/platform=iOS Simulator' build`
- **Build companion:** `xcodebuild -scheme AgentBoardCompanion -destination 'platform=macOS' build`
- **Test:** `xcodebuild test -scheme AgentBoard -destination 'platform=macOS'`
- **Regenerate xcodeproj after `project.yml` edits:** `xcodegen generate`

## Quick Reference

```bash
gh issue list --repo jbcrane13/AgentBoard --label "status:ready" --state open --json number,title,labels
gh issue edit <number> --repo jbcrane13/AgentBoard --add-label "status:in-progress" --remove-label "status:ready"
gh issue close <number> --repo jbcrane13/AgentBoard --comment "Done: <summary>"
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

1. **File issues for remaining work** if follow-up is needed
2. **Run quality gates** for any code changes
3. **Update issue status** when working against tracked issues
4. **Push to remote**
   ```bash
   git pull --rebase
   git push
   git status
   ```
5. **Clean up** stashes or temporary branches if you created them
6. **Verify** the branch is up to date with origin
7. **Hand off** any relevant context for the next session
8. **Update AGENTS.md and ADR.md** for meaningful project changes

Critical rules:
- Work is not complete until `git push` succeeds
- Never leave implementation changes stranded locally
- Never say "ready to push when you are"
- Update this file and docs/ADR.md for architectural changes

## Active App Architecture

The active product is the Hermes-first SwiftUI rebuild.

### Targets

- `AgentBoard` — macOS app shell
- `AgentBoardMobile` — iOS app shell
- `AgentBoardUI` — shared SwiftUI views/components
- `AgentBoardCore` — shared stores, services, models, persistence
- `AgentBoardCompanionKit` — companion server/store implementation
- `AgentBoardCompanion` — companion executable
- `AgentBoardTests` — Swift Testing coverage for the shared stack

### Source of truth split

- **Hermes gateway** powers chat (WebSocket JSON-RPC protocol)
- **`~/.hermes/kanban.db`** is the task/work-tracking backend — all Kanban data lives here
- **AgentBoard companion** monitors live tmux sessions and agent health (process discovery + tmux pane capture)
- **GitHub Issues** are the external work-tracking source, consumed by Hermes agents

### Key new files (2026-05-01 Kanban migration)

| File | Role |
|------|------|
| `AgentBoardCore/Models/KanbanModels.swift` | `KanbanTask`, `KanbanComment`, `KanbanRun`, `KanbanCreateDraft` |
| `AgentBoardCore/Services/KanbanDataService.swift` | Read-only SQLite access to `~/.hermes/kanban.db` |
| `AgentBoardCore/Services/KanbanCLIWriter.swift` | Write access via `hermes kanban` CLI subprocess |
| `AgentBoardCore/Stores/AgentsStore.swift` | Full kanban backend: columns by status, task CRUD |

### Task architecture (post-2026-05-01)

```
Read  → KanbanDataService (SQLite3 open/read/close)
Write → KanbanCLIWriter (Process.run → hermes kanban create/complete/block/comment/etc.)
```

- No SQLite contention — the gateway dispatcher owns all writes; the CLI routes through the same path
- No REST API dependency — CLI subprocess is the native path
- `KanbanTask` is self-contained — no GitHub work item anchoring

### What was removed (2026-05-01)

- `AgentTask`, `AgentTaskDraft`, `AgentTaskPatch`, `AgentTaskState` — removed from `DomainModels.swift`
- `CachedTaskRecord` + `loadTasks()`/`replaceTasks()` — removed from `AgentBoardCache.swift`
- Task CRUD routes (`POST/PATCH/DELETE /v1/tasks`, `GET /v1/tasks`) — removed from `CompanionServer.swift`
- `store.createTask`/`updateTask`/`deleteTask`/`listTasks` — removed from `CompanionSQLiteStore.swift`
- `CompanionEventKind.tasksChanged` — removed; companions no longer track tasks
- `AgentTask` CRUD methods — removed from `CompanionClient.swift`
- `CompanionLocalProbe.snapshot()` simplified — no longer takes `[AgentTask]`

### Networking requirement

Both app targets intentionally allow insecure development networking in their Info.plists because Hermes and the companion service may run on loopback or plain-HTTP LAN/Tailscale addresses during development.

### Project management

- `project.yml` is the source of truth
- Never edit `AgentBoard.xcodeproj/project.pbxproj` directly
- Run `xcodegen generate` after target, scheme, resource, or build-setting edits

### App icon

Located in `SharedResources/Assets.xcassets/AppIcon.appiconset/`. All 10 macOS sizes (16 through 512, 1x and 2x) are a dark kanban-themed design with colored card columns (cyan/amber/green). Generated 2026-05-01.

## Design decisions

See `docs/ADR.md` for the full architecture decision record. Key recent ADRs:
- **ADR-011** (2026-05-01): Kanban.db as task backend
- **ADR-010** (2026-04-23): Hermes-first shared SwiftUI rebuild

## Historical Notes

The older OpenClaw/beads/macOS-only prototype has been removed from the active source tree. Historical documents such as `CLAUDE.md`, `DESIGN.md`, and `IMPLEMENTATION-PLAN.md` are archival context only. beads (bd) is **decommissioned** across all projects.

## Activity

### 2026-05-01
- 9cf07f9 **Kanban backend migration** — switch AgentsStore to `~/.hermes/kanban.db` via KanbanDataService (read) + KanbanCLIWriter (write). Kanban columns with create/comment/status change. Gut all AgentTask types and companion task CRUD. Add proper dark kanban-themed app icon.
- 512d7cd Replace app icon with dark geometric design
- 48e6e35 Add Hermes agent signatures
- 70b4389 Potential fix for pull request finding
- ce1e150 ci: add jscpd duplicate code detection for Swift

### 2026-04-23
- Multiple commits: Hermes-first shared SwiftUI rebuild (ADR-010)

## Activity — 2026-05-02
- d7be5af Refactor CompanionLocalProbe; macOS Kanban guard
- abb45c0 docs: update AGENTS.md and ADR.md for kanban migration
