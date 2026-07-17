# Phase 3 — Three-Column Issues Board Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the GitHub issues Work board from four columns (Ready / In Progress / Review / Done) to three (To Do / In Progress / Resolved) as a presentation-side remap — `status:*` labels are never renamed or removed, so CLI/agent workflows keep working (issue #145).

**Architecture:** One PR. `WorkState` (label-derived, five cases) stays untouched as the domain truth. A new presentation enum `WorkBoardColumn` groups states into three columns and defines drop transitions. `WorkScreen` renders columns from the new enum; drops map a column to a target `WorkState` and reuse the existing `WorkStore.updateStatus` (which already swaps labels and opens/closes issues).

**Tech Stack / Global Constraints:** identical to Phase 2 plan (`2026-07-17-phase2-agent-kanban.md`).

## Column mapping (spec, decided 2026-07-16)

| Column | Contains (WorkState) | Notes |
|---|---|---|
| To Do | `.ready` | open issues with `status:ready` or no status label (existing derivation already maps unlabeled-open → ready) |
| In Progress | `.inProgress`, `.review`, `.blocked` | blocked cards get a visible "Blocked" badge |
| Resolved | `.done` | closed issues |

Drop transitions: To Do → `updateStatus(.ready)`; In Progress → `updateStatus(.inProgress)` (review/blocked states are reachable only via labels/detail sheet, not drops); Resolved → `updateStatus(.done)` (closes the issue). Dragging out of Resolved reopens + sets the target label (updateStatus already handles reopen — verify in `WorkStore.swift:218` region and `GitHubWorkService` PATCH logic).

## Task G1: WorkBoardColumn (Core, pure)

**Files:** Create `AgentBoardCore/Models/WorkBoardColumn.swift`; test `AgentBoardTests/WorkBoardColumnTests.swift` (new).

```swift
public enum WorkBoardColumn: String, CaseIterable, Identifiable, Sendable {
    case todo, inProgress, resolved
    public var id: String { rawValue }
    public var title: String            // "To Do", "In Progress", "Resolved"
    public static func column(for state: WorkState) -> WorkBoardColumn
    public var dropTargetState: WorkState   // .ready / .inProgress / .done
}
```
Tests: every `WorkState` maps to exactly one column per the table; drop targets are `.ready`/`.inProgress`/`.done`; titles.

## Task G2: WorkScreen renders three columns

**Files:** Modify `AgentBoardUI/Screens/WorkScreen.swift`; extend `AgentBoardTests` only where source-text tests pin identifiers (check `AccessibilityIdentifierTests` / `NativeSwiftUIInterfaceTests` for pinned WorkScreen strings that need updating).

- Board layout iterates `WorkBoardColumn.allCases` instead of the current four-state array (~WorkScreen.swift:111-116); each column's items = `filteredItems.filter { WorkBoardColumn.column(for: $0.status) == column }`, preserving current in-column sort.
- `.dropDestination` per column calls `WorkStore.updateStatus(for:to: column.dropTargetState)` — skip the call when the item is already in that column (same-column drop no-op; updateStatus already early-returns on same state, but same-COLUMN with different state, e.g. review → In Progress drop, SHOULD call updateStatus(.inProgress) — implement that nuance: only skip when `column(for: item.status) == targetColumn && item.status == column.dropTargetState`).
- Blocked badge: cards whose `status == .blocked` show a small "Blocked" capsule (existing palette; `.accessibilityIdentifier("work_badge_blocked_\(item.id)")`). Review-state cards may keep their existing status pill if one exists — inspect the card view first and keep changes minimal.
- List layout (non-board) untouched. Column headers get/keep accessibility identifiers per existing convention.

## Task G3: Store/service verification pass

**Files:** `AgentBoardCore/Stores/WorkStore.swift`, `AgentBoardTests/WorkStoreTests.swift` / `WorkStoreCRUDTests.swift` (extend).

- Verify (and add tests for) the two board-critical flows: drop → Resolved closes the issue (state PATCH closed + `status:done` label swap per existing behavior), and drag out of Resolved reopens (PATCH open + target label). These flows exist — the deliverable is TESTS proving them under the new 3-column mapping, plus any small fix if reopen doesn't actually happen (read `updateStatus` and `GitHubWorkService.update` carefully first).

Gate: full suite green (baseline 471), three schemes build, SwiftLint strict clean, `xcodegen generate` for new files. Branch `feat/issue-145-three-column-board`. Commits: `feat: three-column work board mapping (#145)` (G1), `feat: render To Do / In Progress / Resolved on the work board (#145)` (G2+G3).

## Self-review notes
- Same-column-different-state drops (review → In Progress) intentionally normalize the label to `status:in-progress`; that's the simplification's point, and labels remain the source of truth.
- No changes to `WorkState`, `derivedStatus`, label schema, or the list layout — presentation + transition only.
