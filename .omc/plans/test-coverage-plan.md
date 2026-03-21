# AgentBoard Test Coverage Plan

## Project: AgentBoard
## Date: 2026-03-20 (updated from 2026-03-06)
## Focus: Coverage for GitHub Issues #12, #13, #14 and board fixes

---

## Status: Prior Plan Items — ALL COMPLETED

The February/March plan covered AppConfigStore, CanvasRenderer, JSONLEntityParser, TerminalLauncher, SessionMonitor, HistoryDashboardOutcomeTests @MainActor fix.

---

## Current Baseline (2026-03-20 Audit)

| Metric | Value |
|--------|-------|
| Unit test files | 32 |
| Unit test methods | ~365 |
| UI test files | 8 |
| UI test methods | ~43 |
| **Blocker** | GitHubIssuesServiceTests.swift has 3 compile errors blocking test target |

### Compile Errors (AB-9f3)
1. `MockURLProtocol` redeclared in `GatewayClientContractTests.swift` and `GitHubIssuesServiceTests.swift`
2. `updateIssue` call missing `labels:` param (signature changed)
3. JSON fixtures missing `assignees` and `milestone` fields (added today in #12/#13)

---

## Coverage Areas

### Area 1: Fix Test Compile Errors (P0 — bug)
- **Problem**: Test target won't compile. Blocks ALL unit test runs.
- **Fix**:
  - Extract shared `MockURLProtocol` to `TestHelpers/MockURLProtocol.swift`
  - Remove inline MockURLProtocol from both test files
  - Update all JSON fixtures to include `"assignees":[],"milestone":null`
  - Fix `updateIssue` call to include `labels:` param
- **Files**: `GitHubIssuesServiceTests.swift`, `GatewayClientContractTests.swift`, new `TestHelpers/MockURLProtocol.swift`
- **Test count**: 0 new (fixes 11 existing tests)

### Area 2: Assignee Mapping Tests (P1 — #12)
- **Tests**:
  1. `githubAssignees("daneel")` returns `["jbcrane13"]`
  2. `githubAssignees("")` returns nil
  3. `githubAssignees("unknown")` returns nil
  4. `githubAssignees("quentin")` returns nil (no GitHub username mapped)
  5. `createIssue` includes assignees in POST payload when provided
  6. `updateIssue` includes assignees in PATCH payload when provided
  7. `mapToBead` extracts assignee from `assignees[0].login`
- **Files**: new `AgentDefinitionTests.swift`, modify `GitHubIssuesServiceTests.swift`
- **Test count**: 7

### Area 3: Milestone Integration Tests (P1 — #13)
- **Tests**:
  1. `BeadDraft.from` preserves `milestoneNumber`
  2. `BeadDraft` default `milestoneNumber` is nil
  3. `createIssue` includes milestone in POST payload
  4. `updateIssue` includes milestone in PATCH payload
  5. `fetchMilestones` parses response correctly
  6. `mapToBead` extracts `milestoneNumber` and `milestoneTitle`
  7. Bead Codable round-trip with milestone fields
- **Files**: modify `GitHubIssuesServiceTests.swift`, modify `ModelCoverageTests.swift`
- **Test count**: 7

### Area 4: Backlog Filter Logic Tests (P1 — Fix 2)
- **Tests**:
  1. Filter hides open issues with no active status labels
  2. Filter shows issues with `status:ready` label
  3. Filter shows issues with `status:in-progress` label
  4. Filter shows issues with `status:blocked` label
  5. Filter shows issues with `status:review` label
  6. Filter passes through Done issues regardless
  7. Filter shows untriaged issues (empty labels)
  8. Filter disabled shows all issues
- **Files**: new `BacklogFilterTests.swift`
- **Test count**: 8

### Area 5: fetchIssues State=All Contract Test (P2 — Fix 1)
- **Tests**:
  1. `fetchIssues` URL contains `state=all`
  2. Both open and closed issues returned in results
- **Files**: modify `GitHubIssuesServiceTests.swift`
- **Test count**: 2

### Area 6: Bead Model New Fields (P2 — #12/#13)
- **Tests**:
  1. Bead init defaults milestoneNumber/milestoneTitle to nil
  2. Bead with explicit milestone values
  3. CrossRepoIssue.assignedAgent fallback to bead.assignee
- **Files**: modify `ModelCoverageTests.swift`
- **Test count**: 3

## Execution Strategy
- **Worker 1**: Areas 1 + 2 (fix compile errors first, then assignee tests)
- **Worker 2**: Areas 3 + 5 (milestone tests + fetchIssues contract)
- **Worker 3**: Areas 4 + 6 (backlog filter + model tests)
- Dependency: Area 1 must complete first (unblocks test target)

## Total new tests: ~27

## Verification Criteria
- [ ] Test target compiles (no errors)
- [ ] All new + existing tests pass
- [ ] MockURLProtocol deduplicated
- [ ] JSON fixtures updated for new fields
- [ ] Every feature from #12, #13, #14 has unit tests
- [ ] Backlog filter logic verified
- [ ] Changes committed and pushed
