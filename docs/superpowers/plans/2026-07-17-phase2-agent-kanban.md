# Phase 2 — Agent Task Kanban Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the agent task board (AgentsScreen) to parity with the Work board: drag-and-drop between columns, offline SwiftData cache, and real per-agent session counts (issues #143, #144).

**Architecture:** Two stacked PRs. Drag-and-drop mirrors WorkScreen's `Transferable` + `.draggable`/`.dropDestination` pattern, but Hermes is the write authority and its CLI exposes only **semantic transitions** — there is no generic "set status". Drops map through a legal-transition table; illegal drops (anything → running/triage, etc.) revert with an explanatory status message. The cache extends `AgentBoardCacheProtocol` (which ripples to `AgentBoardCache`, `NoopAgentBoardCache`, and test fakes). Session counts flow from `SessionsStore` into `AgentsStore` via `AgentBoardAppModel`, which already owns both.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, xcodegen, SwiftLint.

## Global Constraints

Same as Phase 1 (see `2026-07-17-phase1-chat-completion.md`): strict concurrency, TDD, Swift Testing style, accessibility identifiers on every interactive element, all three schemes build, SwiftLint strict, full AgentBoardTests suite green per PR, `xcodegen generate` after adding files, local test command uses `-derivedDataPath ./DerivedData`.

## Verified CLI ground truth (hermes kanban, 2026-07-17)

Available transition verbs: `promote <id> [reason]` (todo/blocked → ready), `block <ids> [reason]`, `unblock <ids> [--reason]` (blocked/scheduled → ready), `complete <ids>` (→ done), `archive <id>`, `assign`. `running` is entered ONLY by an agent claiming a task (`claim`) — never by the UI. `KanbanCLIWriter` already wraps: create/comment/complete/block/unblock/archive/assign.

---

## PR E — Drag-and-drop on the agent board (#143)

### Task E1: Legal-transition table (Core, pure + testable)

**Files:** Create `AgentBoardCore/Models/KanbanBoardMove.swift`; test `AgentBoardTests/KanbanBoardMoveTests.swift` (new).

**Interfaces:**
```swift
public enum KanbanBoardMove: Equatable, Sendable {
    case promote          // triage/todo/blocked → ready (blocked uses unblock)
    case block            // any non-terminal → blocked
    case unblock          // blocked → ready
    case complete         // any non-terminal → done

    /// nil when the drop is not a legal user-initiated transition.
    public static func forDrag(from: KanbanStatus, to: KanbanStatus) -> KanbanBoardMove?
    /// Human explanation for a rejected drop (e.g. dragging into Running).
    public static func rejectionMessage(from: KanbanStatus, to: KanbanStatus) -> String
}
```
Mapping: `→ .done` = complete (from triage/todo/ready/running/blocked); `→ .blocked` = block (from triage/todo/ready/running); `blocked → .ready` = unblock; `triage/todo → .ready` = promote; same-column = nil; `→ .running` = nil ("Tasks enter Running when an agent claims them."); `→ .triage`/`→ .todo`/`→ .archived` = nil; `done → anything` = nil. Tests enumerate the full matrix (use two nested loops over `KanbanStatus.boardColumns` plus targeted assertions for the named cases).

### Task E2: AgentsStore.moveTask + CLI wiring

**Files:** Modify `AgentBoardCore/Stores/AgentsStore.swift`, `AgentBoardCore/Services/KanbanCLIWriter.swift` (add `promote(taskID:)` wrapping `hermes kanban promote <id> --json` if `--json` is supported, else plain; mirror the existing wrapper style); test `AgentBoardTests/AgentsStoreMoveTests.swift` (new) using whatever fake/mock pattern AgentsStore tests already use (read `AgentsStoreCreateTaskTests.swift` first — reuse its writer fake).

**Interfaces:**
```swift
// AgentsStore
public func moveTask(id: String, to target: KanbanStatus) async
```
Behavior: look up the task; compute `KanbanBoardMove.forDrag`; if nil set `statusMessage` to the rejection message and return. Otherwise optimistically update the local task's status, call the matching writer method (`complete(taskID:summary:"Completed from board")`, `block(taskID:reason:"Blocked from board")`, `unblock(taskID:)`, `promote(taskID:)`), and on throw revert the optimistic change and set an error message. Tests: legal move updates status + calls writer; writer failure reverts; illegal move never calls writer and sets the rejection message.

### Task E3: Board DnD UI

**Files:** Modify `AgentBoardUI/Screens/AgentsScreen.swift`. Mirror `WorkScreen.swift` exactly: a `private struct KanbanTaskID: Codable, Hashable, Transferable` (see `WorkItemID` at WorkScreen.swift:461), `.draggable(KanbanTaskID(task.id))` on cards in the wide-layout column ForEach (~line 199) AND the compact stacked layout (~line 148), `.dropDestination(for: KanbanTaskID.self)` on each column container calling `appModel.agentsStore.moveTask(id:to:)` in a Task. Keep existing context menus/sheets untouched. No new interactive elements without accessibility identifiers (the drop target itself needs none; cards already have ids).

Gate: full suite, three schemes, SwiftLint. Branch `feat/issue-143-kanban-dnd`, commits `feat: legal-transition table for kanban board drags (#143)`, `feat: drag-and-drop between agent board columns (#143)` (E2+E3 may share the second commit if E3 is view-only).

---

## PR F — Kanban cache + real agent activity (#144), stacked on PR E

### Task F1: Kanban tasks in the SwiftData cache

**Files:** Modify `AgentBoardCore/Persistence/AgentBoardCacheProtocol.swift` (+2 requirements), `AgentBoardCore/Persistence/AgentBoardCache.swift` (new `CachedKanbanTaskRecord` @Model with ALL KanbanTask fields it round-trips — check `KanbanModels.swift` for the full field list and store complex sub-structures as JSON-encoded Data columns if needed; follow the existing record patterns), `AgentBoardCore/Persistence/NoopAgentBoardCache.swift`, plus every test fake that conforms to the protocol (grep `AgentBoardCacheProtocol` in AgentBoardTests). Test: extend `AgentBoardTests/AgentBoardCacheTests.swift` with a full-fidelity round-trip (every field asserted, including status/priority/assignee/timestamps — Phase 1 caught a silent field-drop here; don't repeat it).

**Interfaces:**
```swift
func loadKanbanTasks() throws -> [KanbanTask]
func replaceKanbanTasks(_ tasks: [KanbanTask]) throws
```

### Task F2: AgentsStore hydrates from cache

**Files:** Modify `AgentBoardCore/Stores/AgentsStore.swift` (init gains `cache: any AgentBoardCacheProtocol`), `AgentBoardCore/Stores/AgentBoardAppModel.swift` (`makeLiveAppModel` passes the shared cache; `AgentsStore(settingsStore:)` call site), all AgentsStore test constructions. Behavior: `bootstrap()` loads cached tasks first (instant render), then refreshes from `KanbanDataService`; a successful refresh calls `replaceKanbanTasks`; a failed refresh (kanban.db missing) keeps cached tasks and sets a "showing cached tasks" status message instead of clearing the board. Tests: bootstrap renders cache before refresh completes; refresh failure retains cached tasks; successful refresh persists.

### Task F3: Real activeSessionCount

**Files:** Modify `AgentBoardCore/Stores/AgentsStore.swift` (`buildAgentSummaries(from:)` gains `sessionCounts: [String: Int]` parameter — the hard-coded `activeSessionCount: 0` at ~line 238 uses `sessionCounts[assignee] ?? 0`; add `public func updateActiveSessionCounts(_ counts: [String: Int])` that stores counts and rebuilds summaries), `AgentBoardCore/Stores/AgentBoardAppModel.swift` (after `sessionsStore.refresh()` in `refreshAll`/the refresh loop/companion event handling, derive counts from `sessionsStore.sessions` — inspect `AgentSession` in DomainModels.swift for the agent-name field and what marks a session active — and call `updateActiveSessionCounts`). Tests: extend `AgentsStoreSummariesTests.swift` — summaries reflect injected counts; unknown assignees default 0; AppModel-level derivation tested if the existing AppModel test fixtures allow (check `AgentBoardAppModel` testability — if it can't be constructed in tests, test the pure derivation via a static helper `AgentBoardAppModel.activeSessionCounts(from: [AgentSession]) -> [String: Int]`).

Gate: full suite, three schemes, SwiftLint. Branch `feat/issue-144-kanban-cache-activity` (stacked on PR E), commits `feat: cache kanban tasks in SwiftData (#144)`, `feat: real per-agent session counts on the board rail (#144)`.

---

## Self-review notes
- The spec's "drag between columns" is deliberately narrowed to legal Hermes transitions — the CLI has no generic set-status, and `running` is agent-claimed by design. Rejections surface a message rather than silently snapping back.
- Protocol additions in F1 are the riskiest ripple (three conformers + fakes); the compiler enumerates them.
- `KanbanCLIWriter.promote` is the only new CLI wrapper; verify its flags with `hermes kanban promote --help` before writing it (done — positional id + optional reason; `--json` flag exists).
