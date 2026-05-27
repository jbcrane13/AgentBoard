# LifeOps MVP Implementation Plan

> **For Hermes:** Use Codex or subagent-driven-development to implement this plan task-by-task. Keep real external integrations out of the first pass.

**Goal:** Add a LifeOps executive-function dashboard to AgentBoard macOS and AgentBoardMobile iOS, backed by shared models, fixture data, and store logic.

**Architecture:** Add LifeOps as a separate module inside AgentBoardCore/AgentBoardUI. Use in-memory fixture services for v1. Integrate a LifeOps destination into the existing native macOS sidebar and iOS shell without disrupting coding-agent workflows.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, XcodeGen project.yml.

---

## Guardrails

- Do not implement live email/calendar/iMessage automation in this pass.
- Do not send any real messages or create real calendar events.
- Do not edit `AgentBoard.xcodeproj/project.pbxproj` directly; edit `project.yml` and run `xcodegen generate` if needed.
- Preserve existing Work/Sessions/Agents/Chat behavior.
- Keep UI native SwiftUI per ADR-013.
- Run quality gates before handoff:
  - `swiftlint lint --strict`
  - `xcodebuild test -scheme AgentBoard -destination 'platform=macOS'`
  - `xcodebuild -scheme AgentBoardMobile -destination 'generic/platform=iOS Simulator' build`

## Task 1: Add LifeOps models

**Objective:** Create shared Codable/Sendable data structures for LifeOps.

**Files:**
- Create: `AgentBoardCore/Models/LifeOpsModels.swift`
- Test: `AgentBoardTests/LifeOpsModelsTests.swift`
- Modify if needed: `project.yml`

**Implementation details:**

Add enums:

- `LifePriority: String, Codable, CaseIterable, Sendable` with `p0`, `p1`, `p2`, `p3`
- `LifeTaskCategory`
- `LifeTaskStatus`
- `LifeActor`
- `LifeSourceType`
- `ApprovalActionType`
- `ApprovalRiskLevel`
- `ApprovalStatus`
- `JobOpportunityStage`
- `FamilyRequestAction`
- `FamilyRequestStatus`

Add structs:

- `LifeTask`
- `LifeTaskSource`
- `ApprovalAction`
- `JobOpportunity`
- `FamilyRequest`

**Tests:**

- Codable round trip for each primary struct.
- `LifePriority` display ordering maps P0 before P1 before P2 before P3.
- Defaults/fixtures can construct valid values.

**Verify:**

```bash
xcodebuild test -scheme AgentBoard -destination 'platform=macOS' -only-testing:AgentBoardTests/LifeOpsModelsTests
```

## Task 2: Add LifeOps fixtures

**Objective:** Provide realistic local data for UI and store testing.

**Files:**
- Create: `AgentBoardCore/Services/LifeOpsFixtures.swift`
- Test: update `AgentBoardTests/LifeOpsModelsTests.swift` or create `LifeOpsFixturesTests.swift`

**Fixture requirements:**

Include examples for:

- P1 email reply task
- Calendar prep task
- Job-search follow-up
- Sarah/family iMessage-originated task
- Pending approval action
- Waiting-on item
- Snoozed P2 task

**Verify:**

- Fixture arrays are non-empty.
- Fixture IDs referenced by associated objects exist.

## Task 3: Add LifeOpsStore

**Objective:** Implement observable store logic for dashboard sections.

**Files:**
- Create: `AgentBoardCore/Stores/LifeOpsStore.swift`
- Test: `AgentBoardTests/LifeOpsStoreTests.swift`

**Store responsibilities:**

- Load fixture data initially.
- `nowTasks`: unsnoozed/non-done P0/P1 tasks, max 3, sorted by priority/due/urgency.
- `todayTasks`: due today or P1, excluding done/cancelled/snoozed.
- `inboxTasks`: status `inbox`.
- `waitingTasks`: status `waitingOnExternal`.
- `familyTasks`: owner/category family or Sarah-originated source.
- `pendingApprovals`: pending approval actions.
- `jobFollowUpsDue`: opportunities with `nextFollowUpAt <= now/end of today`.
- `createQuickTask(title:)`.
- `markDone(id:)`.
- `snooze(id:until:)`.
- `assignToDaneel(id:)`.

**Tests:**

- Now returns at most 3 tasks.
- Done/snoozed tasks disappear from Today.
- Sarah/family tasks appear in Family.
- Pending approvals filter correctly.
- Quick capture creates an Inbox task.

## Task 4: Add shared LifeOps UI components

**Objective:** Build reusable row/badge/capture components.

**Files:**
- Create: `AgentBoardUI/Components/LifeOpsPriorityBadge.swift`
- Create: `AgentBoardUI/Components/LifeOpsTaskRow.swift`
- Create: `AgentBoardUI/Components/LifeOpsQuickCaptureView.swift`

**UI requirements:**

- `LifeOpsPriorityBadge` shows P0/P1/P2/P3 text and visually distinct severity.
- `LifeOpsTaskRow` shows title, next action, source/category, due date if present, assignee/owner if relevant.
- `LifeOpsQuickCaptureView` accepts text and calls a closure.
- Add accessibility identifiers:
  - `lifeops.priority.badge`
  - `lifeops.task.row`
  - `lifeops.quickCapture.field`
  - `lifeops.quickCapture.submit`

## Task 5: Add LifeOpsScreen

**Objective:** Create shared dashboard sections for macOS/iOS reuse.

**Files:**
- Create: `AgentBoardUI/Screens/LifeOpsScreen.swift`
- Optionally create section subviews if the file grows too large:
  - `LifeOpsTodayView.swift`
  - `LifeOpsApprovalsView.swift`
  - `LifeOpsJobSearchView.swift`
  - `LifeOpsFamilyView.swift`

**UI sections:**

- Now
- Today
- Inbox
- Needs Approval
- Waiting On
- Job Search
- Family

**Requirements:**

- Top Now section never renders more than 3 tasks.
- Family section clearly labels Sarah-originated tasks.
- Approval section uses a distinct visual treatment.
- Quick capture is visible near the top.
- Empty states are friendly and short.

## Task 6: Add macOS navigation entry

**Objective:** Add LifeOps to the AgentBoard macOS sidebar.

**Files:**
- Modify likely files after inspection:
  - `AgentBoard/DesktopRootView.swift`
  - `AgentBoardCore/Models/AppDestination.swift`
  - any sidebar enum/list helpers

**Requirements:**

- Add a `lifeOps` destination.
- Sidebar label: `LifeOps`.
- Icon suggestion: `checklist` or `brain.head.profile` if available.
- Selecting it shows `LifeOpsScreen(store: appModel.lifeOpsStore)` or equivalent.
- Preserve existing destinations.

## Task 7: Add iOS/mobile navigation entry

**Objective:** Expose LifeOps in AgentBoardMobile.

**Files:**
- Modify likely files after inspection:
  - `AgentBoardMobile/MobileRootView.swift`
  - `AgentBoardCore/Models/AppDestination.swift`
  - app model if needed

**Requirements:**

- Add LifeOps tab/section.
- Mobile defaults to Now/Today and Quick Capture.
- Do not overcrowd the tab bar if current structure has limited tabs; use an existing More/NavigationStack pattern if present.

## Task 8: Wire LifeOpsStore into app model

**Objective:** Make the store available to both app shells.

**Files:**
- Modify: `AgentBoardCore/Stores/AgentBoardAppModel.swift`

**Requirements:**

- Add `public let lifeOpsStore: LifeOpsStore` or equivalent.
- Initialize with fixtures/local service.
- Do not trigger external network calls on startup.

## Task 9: Add UI/semantics tests

**Objective:** Guard the new navigation and accessibility contracts.

**Files:**
- Create: `AgentBoardTests/LifeOpsInterfaceTests.swift`
- Or extend existing native interface tests if appropriate.

**Tests:**

- `AppDestination` includes LifeOps.
- LifeOps screen exposes accessibility IDs for Now, Today, Approvals, Family, Quick Capture.
- Store-backed screen can render fixture data.

## Task 10: Documentation and ADR

**Objective:** Keep architecture docs current.

**Files:**
- Modify: `docs/ADR.md`
- Modify: `AGENTS.md` if the implementation changes active architecture.

**ADR content:**

- Add ADR-014: LifeOps module inside AgentBoard.
- Record decision to start with fixtures/protocol seams and defer real integrations.
- Record family/Sarah iMessage intake as explicit design requirement.

## Final verification

Run:

```bash
swiftlint lint --strict
xcodebuild test -scheme AgentBoard -destination 'platform=macOS'
xcodebuild -scheme AgentBoardMobile -destination 'generic/platform=iOS Simulator' build
git status --short
git log --oneline -5
```

Expected:

- SwiftLint passes.
- macOS tests pass.
- iOS build passes.
- Changes are committed on a feature branch.

## Suggested branch and PR

Branch:

```text
feat/lifeops-mvp-scaffold
```

PR title:

```text
feat: add LifeOps executive assistant scaffold
```

PR body summary:

- Adds LifeOps models/store/fixtures.
- Adds macOS and iOS LifeOps dashboard surfaces.
- Adds fixture-backed family/job-search/approval sections.
- Adds tests for models/store/UI contracts.
- Defers real email/calendar/iMessage integrations to follow-up PRs.
