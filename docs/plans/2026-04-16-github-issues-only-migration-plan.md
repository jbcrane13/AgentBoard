# AgentBoard GitHub-Issues-Only Migration Plan

> For Hermes: this is the planning pass only. Create/align GitHub issues first, then execute in issue order.

## Goal

Make AgentBoard a GitHub-issues-only tool. No more Beads as a tasking system, no mixed Bead/GitHub abstractions, and no PRD/session workflows built on stale Bead-only models.

## Why this is needed

Codex review found the current branch is still split between:
- the real GitHub-backed workflow (`GitHubIssuesService`, GitHub issue labels, repo config)
- legacy or parallel Bead/Epic/BeadIssue paths
- duplicate session/task/review flows that do not match the actual AppState and session-launch APIs

Result: the project is not shippable, build stability is degraded, and the planning / tasking story is inconsistent.

## Principles

1. GitHub Issues is the only durable task tracker.
2. Daily planning board may remain local, but it links outward to GitHub issue numbers.
3. Session launching, PRD generation, and review flows must start from GitHub issues, not Beads.
4. No duplicate model trees for the same concept.
5. Fix compile/build blockers before feature polish.

## Scope

### In scope
- Remove or isolate Bead-only task workflows
- Normalize issue detail / PRD / session launch around GitHub issues
- Reconstruct epic/task hierarchy from GitHub issue metadata
- Keep local daily goals board, but make it issue-linked and explicitly non-Beads
- Preserve existing layout and session-monitoring strengths

### Out of scope
- Full redesign of AgentBoard UI shell
- Replacing SessionMonitor / tmux / ralphy stack
- Large new feature work unrelated to GitHub migration

## Workstreams

### Workstream 1 — Restore build + remove broken mixed abstractions
Priority: P0

Problems:
- Epic/TaskCard/TaskDetail/SessionLauncher currently depend on stale or invalid types
- Priority typing is inconsistent
- Some files reference models that either should not exist or are not integrated correctly

Target state:
- Project builds cleanly
- One canonical shared model path for issue/task priority
- No compile-time references to stale BeadIssue/AgentTask.Priority coupling

### Workstream 2 — GitHub issue canonical domain model
Priority: P1

Problems:
- GitHub issue UI exists, but PRD/session launch still drifts toward alternate models
- Some GitHubIssue-backed views are not aligned with public app APIs

Target state:
- All issue-centric flows use GitHub-backed models/services
- If an adapter is needed, it is clearly named and one-way (GitHubIssue -> UI model), not a second source of truth

### Workstream 3 — Epic > Task hierarchy using GitHub metadata
Priority: P1

Problems:
- Parent/child relationships are not reliably reconstructed on fetch
- Epic progress and issue grouping can be wrong or incomplete

Target state:
- One canonical parent-child encoding scheme
- Fetch reconstructs hierarchy reliably
- Boards and PRD generation use that same hierarchy source

### Workstream 4 — GitHub UX parity for day-to-day use
Priority: P1/P2

Problems:
- Attachments/screenshots requested by Blake are not finished
- Assignee/type editing is incomplete
- Session-driven coding workflow should operate directly from GitHub issue cards/details

Target state:
- Attachments, screenshots, assignee editing, task-type editing all work on GitHub issues
- Launch coding sessions from GitHub issue detail/cards

### Workstream 5 — Coding-agent-loops integration on top of GitHub
Priority: P1

Problems:
- PRD/session work must originate from GitHub issues
- Completion/review loop should update issue state and comments

Target state:
- GitHub issue -> PRD.md -> ralphy session -> completion comment/status -> optional cross-review
- Session cards and progress reflect GitHub issue context

### Workstream 6 — Local daily goals board as GitHub-linked planning layer
Priority: P2

Problems:
- Daily goals feature is valuable, but must not become a second tracker

Target state:
- Daily goals are local planning items
- Each goal can link to a GitHub issue number
- Completion can reflect or prompt GitHub issue updates
- Explicitly not Beads-backed

## Existing Issues to Reuse

- #25 Ability to add attachments to AgentBoard messages
- #27 cannot set assignee on tickets or change from task to bug

These should be folded into the migration epic rather than duplicated.

## Recommended Execution Order

1. Fix build blockers and broken mixed models
2. Normalize canonical GitHub issue domain flow
3. Reconstruct epic/task hierarchy from GitHub
4. Finish attachments + assignee/type editing
5. Finish coding-agent-loops integration on GitHub issues
6. Rewire daily goals board as local GitHub-linked planner
7. Remove/archive remaining Beads-only task paths and docs

## Definition of Done

- AgentBoard builds and previews cleanly
- GitHub issues are the only task-tracking backend
- No new work starts from Bead-only flows
- PRD/session/review flows begin from GitHub issue detail/cards
- Epic > task hierarchy works from GitHub issue metadata
- Attachments and assignee/type edits work on GitHub issues
- Daily goals board is local-only and GitHub-linked, not a second tracker
- Beads references are removed or clearly marked historical/non-operational

## Notes for Implementation

- Prefer adapters over broad rewrites where possible
- Remove duplicate models only after replacing all live call sites
- Keep issue numbers visible everywhere sessions/PRDs/reviews appear
- Add migration-focused tests for:
  - issue hierarchy reconstruction
  - PRD generation from GitHub issue bodies
  - session launch with GitHub issue context
  - issue update flows (status/labels/assignee/type)
