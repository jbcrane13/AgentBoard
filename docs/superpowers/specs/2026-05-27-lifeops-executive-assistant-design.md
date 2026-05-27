# LifeOps Executive Assistant Design

**Date:** 2026-05-27
**Related PRD:** `docs/PRD-lifeops-executive-assistant.md`
**Product:** AgentBoard macOS + AgentBoardMobile iOS

## Design thesis

LifeOps turns AgentBoard from a coding-agent command center into a broader executive-function command center, while preserving the existing developer workflow. The LifeOps module should be clearly separated from Work/Sessions/Agents so personal/family/job-search tasks do not pollute coding workflows.

The first implementation should prioritize structure and visibility over full automation. Build the task models, stores, dashboard screens, and agent handoff seams first. Email/calendar/iMessage integrations can then plug into the same model without forcing UI rewrites.

## Architecture overview

```text
Authorized sources
  ├─ Email
  ├─ Calendar
  ├─ iMessage / Telegram / Discord
  ├─ Manual quick capture
  └─ Daneel chat
        ↓
LifeOps ingestion protocols
        ↓
LifeOpsStore
        ↓
Shared models in AgentBoardCore
        ↓
macOS LifeOps dashboard + iOS LifeOps companion
        ↓
Daneel action / approval queue
```

## Module boundaries

### AgentBoardCore

Owns shared models, store logic, protocols, and fake/local service implementations.

Proposed files:

- `AgentBoardCore/Models/LifeOpsModels.swift`
- `AgentBoardCore/Stores/LifeOpsStore.swift`
- `AgentBoardCore/Services/LifeOpsIngestionService.swift`
- `AgentBoardCore/Services/LifeOpsActionService.swift`
- `AgentBoardCore/Services/LifeOpsFixtures.swift`

### AgentBoardUI

Owns shared SwiftUI components/screens used by both macOS and iOS.

Proposed files:

- `AgentBoardUI/Screens/LifeOpsScreen.swift`
- `AgentBoardUI/Screens/LifeOpsTodayView.swift`
- `AgentBoardUI/Screens/LifeOpsInboxView.swift`
- `AgentBoardUI/Screens/LifeOpsApprovalsView.swift`
- `AgentBoardUI/Screens/LifeOpsJobSearchView.swift`
- `AgentBoardUI/Screens/LifeOpsFamilyView.swift`
- `AgentBoardUI/Components/LifeOpsTaskRow.swift`
- `AgentBoardUI/Components/LifeOpsPriorityBadge.swift`
- `AgentBoardUI/Components/LifeOpsQuickCaptureView.swift`

### AgentBoard macOS

Adds a LifeOps destination to the native sidebar.

### AgentBoardMobile iOS

Adds a LifeOps tab or destination to the mobile shell. The mobile version should default to Today and Quick Capture.

## Data model

### LifeTask

Represents a task, obligation, reminder, or next action.

Key design choice: LifeTask should not reuse `KanbanTask` directly. KanbanTask is optimized for agent/development work. LifeOps tasks need richer personal metadata: source link, due date, snooze, owner, assignee, confidence, urgency, family/job-search categories, and approval state.

Fields:

```swift
public struct LifeTask: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var summary: String
    public var category: LifeTaskCategory
    public var status: LifeTaskStatus
    public var priority: LifePriority
    public var urgencyScore: Int
    public var importanceScore: Int
    public var dueAt: Date?
    public var snoozedUntil: Date?
    public var estimatedMinutes: Int?
    public var nextAction: String
    public var owner: LifeActor
    public var assignee: LifeActor
    public var source: LifeTaskSource?
    public var confidence: Double
    public var createdAt: Date
    public var updatedAt: Date
}
```

### ApprovalAction

Represents something Daneel prepared but needs permission to execute.

Examples:

- Send email reply
- Send iMessage
- Create calendar event
- Apply to job
- Archive email

Fields:

```swift
public struct ApprovalAction: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var taskID: UUID?
    public var title: String
    public var summary: String
    public var actionType: ApprovalActionType
    public var proposedPayloadPreview: String
    public var riskLevel: ApprovalRiskLevel
    public var status: ApprovalStatus
    public var createdAt: Date
    public var updatedAt: Date
}
```

### JobOpportunity

Represents one job-search opportunity and its follow-up state.

Fields:

```swift
public struct JobOpportunity: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var company: String
    public var role: String
    public var url: URL?
    public var contactName: String?
    public var contactChannel: String?
    public var stage: JobOpportunityStage
    public var lastTouchAt: Date?
    public var nextFollowUpAt: Date?
    public var notes: String
    public var associatedTaskIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date
}
```

### FamilyRequest

Represents a request from Sarah or another approved family channel.

Fields:

```swift
public struct FamilyRequest: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var requester: LifeActor
    public var source: LifeTaskSource
    public var rawText: String
    public var interpretedAction: FamilyRequestAction
    public var linkedTaskID: UUID?
    public var linkedApprovalID: UUID?
    public var status: FamilyRequestStatus
    public var createdAt: Date
    public var updatedAt: Date
}
```

## Store design

`LifeOpsStore` should be `@Observable` and `@MainActor`, following the existing AgentBoard store pattern.

Responsibilities:

- Hold task collections
- Compute Now/Today/Inbox/Waiting/Family/Approvals views
- Create quick-capture tasks
- Mark done
- Snooze
- Assign to Daneel
- Update job opportunity stage
- Expose seeded fixtures for v1

It should not directly read email/calendar/iMessage. Those come through protocols.

Proposed protocols:

```swift
public protocol LifeOpsIngestionService: Sendable {
    func fetchNewInboxItems() async throws -> [LifeTask]
    func fetchCalendarPrepItems() async throws -> [LifeTask]
    func fetchFamilyRequests() async throws -> [FamilyRequest]
}

public protocol LifeOpsActionService: Sendable {
    func submitQuickCapture(_ text: String) async throws -> LifeTask
    func approveAction(_ action: ApprovalAction) async throws
    func rejectAction(_ action: ApprovalAction) async throws
    func askDaneel(task: LifeTask, message: String) async throws -> ApprovalAction?
}
```

V1 can implement fixture/local versions. Real integrations can be added behind these protocols.

## UI design

### macOS LifeOpsScreen

Use a native SwiftUI layout consistent with ADR-013.

Structure:

- Header: "LifeOps" + last refresh + quick capture field
- Left/main content: Now and Today
- Secondary sections: Inbox, Approvals, Waiting On
- Right/detail pane or lower sections: Job Search and Family

Must avoid overwhelming the user. The top of the screen should never show more than three Now items.

### iOS LifeOps screen

Use mobile-first sections:

1. Now
2. Today
3. Quick Capture
4. Approvals
5. Family
6. Job Search follow-ups

Do not attempt to show every dashboard column on iPhone.

## Family collaboration design

Sarah interacts primarily through iMessage. The app stores the results as FamilyRequests and LifeTasks.

Rules:

- Sarah can request family tasks and shared calendar events.
- Sarah-originated items should be visibly labeled.
- Shared family tasks appear in Blake's LifeOps Family section and daily briefing.
- Calendar writes from Sarah should go to the configured shared family calendar once integration exists.
- Anything that sends a message as Blake still requires Blake approval.

V1 UI should include Sarah/family fixture examples even before live iMessage integration exists, so the interaction model is testable.

## Agent chat integration

LifeOps should reuse existing Hermes chat transport rather than inventing a second chat system.

Add contextual prompts/buttons later:

- "Ask Daneel what to do next"
- "Ask Daneel to draft reply"
- "Assign to Daneel"
- "Summarize this source"

V1 can deep-link or prefill existing chat context if full contextual chat wiring is too large.

## Persistence decision

Do not prematurely commit to final persistence in the first UI scaffold.

Recommended order:

1. In-memory fixture store for first UI implementation.
2. Local JSON or SwiftData-backed store once interactions settle.
3. Evaluate whether canonical LifeOps state belongs in a new Hermes LifeOps SQLite DB, `kanban.db`, or app SwiftData synced through companion/CloudKit.

Rationale: LifeOps has more privacy and sync implications than coding tasks. The first implementation should prove data shape and UX before locking the backend.

## Accessibility and ADHD design constraints

- Keep Now list to 1-3 items.
- Use clear P0/P1/P2/P3 labels.
- Show next action on every task row.
- Support snooze without guilt language.
- Avoid red-heavy UI except true P0.
- Always show source/origin when available.
- Make family-originated items obvious.
- Make approval actions visually distinct from normal tasks.

## Error handling

- Failed ingestion should not clear existing tasks.
- Failed Daneel action should create a visible blocked/error state.
- Failed calendar/message integration should produce an approval/action error rather than silently disappearing.
- Low-confidence task extraction should go to Inbox, not Today.

## Testing strategy

### Model tests

- Codable round trips for LifeTask, ApprovalAction, JobOpportunity, FamilyRequest.
- Priority/status/category display metadata.

### Store tests

- Now limits to top 3 unsnoozed P0/P1 items.
- Today excludes snoozed/done/cancelled tasks.
- Family section includes Sarah-originated family tasks.
- Approvals filters pending approval actions.
- Job follow-ups due today surface in Today.

### UI/semantics tests

- macOS LifeOps destination exists.
- iOS LifeOps tab/section exists.
- Quick capture field/button exists.
- Now/Today/Approvals/Family sections expose accessibility identifiers.

## Codex implementation guidance

First Codex task should build the LifeOps scaffold only:

- Models
- Fixture store
- Shared UI screens/components
- macOS sidebar destination
- iOS tab/section
- Tests

Do not implement real email/calendar/iMessage automation in the first pass. Real integrations should follow after the UI/data model is visible and Blake can react to it.
