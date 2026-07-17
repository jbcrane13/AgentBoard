# Phase 4 — Dashboard Home Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new Dashboard home screen — first destination on both platforms — summarizing app state from existing stores, with every tile navigating to its screen (issue #146).

**Architecture:** One PR. New `.dashboard` case in `AppDestination` (first tab on iOS, first sidebar entry on macOS). A `DashboardScreen` (AgentBoardUI) reads directly from `AgentBoardAppModel`'s existing stores — no new services, no new stores. A small pure `DashboardSnapshot` model in Core aggregates the numbers so the tile math is unit-testable. Visual design follows the app's existing neumorphic system (`NeuPalette` / `NeumorphicTheme`, `BoardChrome` patterns) — consistency with the app IS the design direction; no new visual language.

**Tech Stack / Global Constraints:** identical to Phase 2/3 plans. Every interactive element gets `dashboard_*` accessibility identifiers.

## Verified navigation facts
- `AppDestination` (AgentBoardCore/Models/AppDestination.swift): 5 cases with `title`/`systemImage`; `desktopTabs = [.work, .agents, .sessions, .settings]` (chat is a trailing inspector on desktop, first tab on mobile).
- `DesktopRootView.swift`: sidebar drives `appModel.selectedDestination`; detail `switch` at ~line 104 maps destinations to screens; `.chat` currently falls through to `WorkScreen()`.
- `MobileRootView.swift`: `TabView(selection:)` with `Tab(value:)` per destination, chat first.

## Task H1: DashboardSnapshot (Core, pure + testable)

**Files:** Create `AgentBoardCore/Models/DashboardSnapshot.swift`; test `AgentBoardTests/DashboardSnapshotTests.swift` (new).

```swift
public struct DashboardSnapshot: Equatable, Sendable {
    public struct KanbanSummary: Equatable, Sendable { public let running: Int; public let ready: Int; public let blocked: Int; public let done: Int; public let total: Int }
    public struct WorkSummary: Equatable, Sendable { public let todo: Int; public let inProgress: Int; public let resolved: Int }   // uses WorkBoardColumn.column(for:)
    public struct SessionsSummary: Equatable, Sendable { public let active: Int; public let total: Int; public let syncStatus: SessionsSyncStatus }
    public let kanban: KanbanSummary
    public let work: WorkSummary
    public let sessions: SessionsSummary
    public let runningTaskTitles: [String]          // up to 3, KanbanStatus.running
    public let recentConversations: [ChatConversation]  // up to 3 by updatedAt desc
    public let chatConnection: ChatConnectionState

    public static func build(
        kanbanTasks: [KanbanTask],
        workItems: [WorkItem],
        sessions: [AgentSession],
        conversations: [ChatConversation],
        chatConnection: ChatConnectionState
    ) -> DashboardSnapshot
}
```
Inspect `AgentSession` for the correct "active" predicate (reuse whatever SessionsScreen/AgentBoardAppModel.activeSessionCounts treats as active). Tests: counts per bucket from fixture arrays; running titles capped at 3; recent conversations sorted/capped; empty inputs → all zeros.

## Task H2: `.dashboard` destination + routing

**Files:** Modify `AgentBoardCore/Models/AppDestination.swift` (new first case `dashboard`, title "Dashboard", systemImage "gauge.with.dots.needle.50percent" or similar SF Symbol that exists on macOS 26/iOS 26; `desktopTabs` becomes `[.dashboard, .work, .agents, .sessions, .settings]`), `AgentBoard/DesktopRootView.swift` (detail switch gains `.dashboard: DashboardScreen()`; check `desktopDestination(for:)` fallback logic and the default `selectedDestination`), `AgentBoardMobile/MobileRootView.swift` (Dashboard tab FIRST, before chat), `AgentBoardCore/Stores/AgentBoardAppModel.swift` (`selectedDestination` default becomes `.dashboard`). Check `AppDestinationTests.swift` and any pinned source-text tests for tab lists and update them deliberately.

## Task H3: DashboardScreen

**Files:** Create `AgentBoardUI/Screens/DashboardScreen.swift`; extend `AgentBoardTests/AccessibilityIdentifierTests.swift` if it pins per-screen coverage (follow its pattern).

- Layout: scrollable grid of tiles (adaptive columns — 2-up compact, 3-up regular) using the existing neumorphic card styling (mirror how `AgentsScreen`/`WorkScreen` build cards with NeuPalette; reuse `BoardChrome` components where they fit). Screen root gets `.accessibilityIdentifier("screen_dashboard")`.
- Tiles (each a `Button` navigating via `appModel.selectedDestination = ...`, accessibility id `dashboard_tile_<name>`):
  1. **Agent tasks** → `.agents`: running/ready/blocked counts + up to 3 running task titles.
  2. **Work items** → `.work`: To Do / In Progress / Resolved counts (via `WorkBoardColumn`).
  3. **Sessions** → `.sessions`: active/total + sync status line.
  4. **Chat** → `.chat` (on desktop: opens the chat inspector — check how the inspector is toggled in DesktopRootView and do the equivalent; on mobile selects the chat tab): connection state + up to 3 recent conversation titles.
- Data: compute `DashboardSnapshot.build(...)` from `appModel`'s stores in the view body (stores are @Observable — recomputation is automatic). A refresh toolbar button calls `appModel.refreshAll()` (id `dashboard_button_refresh`).
- Empty states: tiles render zeros gracefully (no blank tiles).
- Design: match the app's existing visual system exactly — typography, palette, corner radii, and shadows from NeumorphicTheme. No new colors or fonts.

Gate: full suite green, three schemes build, SwiftLint strict clean, `xcodegen generate` for new files. Branch `feat/issue-146-dashboard`. Commits: `feat: DashboardSnapshot aggregation model (#146)`, `feat: dashboard destination and routing (#146)`, `feat: dashboard home screen (#146)`.

## Self-review notes
- Desktop default destination changes from `.chat` (which renders WorkScreen anyway) to `.dashboard` — strictly an improvement; verify no test pins the old default.
- The chat tile's desktop behavior depends on how the inspector toggle works — the implementer must read DesktopRootView first and match the existing mechanism rather than invent one.
