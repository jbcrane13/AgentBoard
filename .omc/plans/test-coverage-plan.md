# AgentBoard Test Coverage Plan

## Project: AgentBoard
## Date: 2026-03-06 (updated from 2026-02-26)
## Focus: Current gaps after comprehensive 4-agent audit

---

## Status: Prior Plan Items (2026-02-26) — ALL COMPLETED

The February plan covered AppConfigStore, CanvasRenderer, JSONLEntityParser, TerminalLauncher, SessionMonitor.
All those test files now exist in AgentBoardTests/. Build was broken by a @MainActor issue in HistoryDashboardOutcomeTests — **fixed 2026-03-06**.

---

## Current Baseline (2026-03-06 Audit)

| Metric | Value |
|--------|-------|
| Unit test files | 30 |
| Unit test methods | ~289 |
| UI test files | 8 |
| UI test methods | ~46 |
| Functional tests | 89% |
| Shallow tests | 7% (24 tests in AgentBoardUITests.swift) |
| Mock-only tests | 4% |
| Pre-existing flaky tests | 2 (AppConfigStoreLifecycleTests — shared ~/.openclaw/openclaw.json race) |
| Disabled UI test suites | 2 (BeadOutcomeTests, NewSessionOutcomeTests) |

---

## Fixed Issues

- [x] **2026-03-06:** `HistoryDashboardOutcomeTests.swift` — added `@MainActor` to class declaration (was blocking all test runs)

---

## Current Gap Analysis

### P0 — Silent Failures in Production Code

| # | File | Issue |
|---|------|-------|
| 1 | `GatewayClient.swift` | `receiveLoop()` swallows all errors — malformed frames never surface to UI |
| 2 | `AppState.swift` | Non-retryable chat connection errors don't show toast on non-chat views |
| 3 | `AppState.swift` | Session monitor errors silently clear session list — user sees empty sidebar, no reason |
| 4 | `AppState.swift` | `loadChatHistory()` swallows errors even when connected |
| 5 | `AppState.swift` | `loadAgentIdentity()` failure is completely silent — no log, no UI |
| 6 | `GatewayClient.swift` | Request timeout uses `try?` — timeout may silently not trigger |
| 7 | `AppState.swift` | Bead JSON serialization fallback silently corrupts `issues.jsonl` |
| 8 | `KeychainService.swift` | `deleteToken()` ignores `SecItemDelete` status — token may persist after logout |
| 9 | `AppState.swift` | `bd update` status call is fire-and-forget with `try?` |

### P1 — Test Coverage Gaps

**Untested async loops:**
- `AppState.startChatConnectionLoop()` — retry backoff, non-retryable error handling
- `AppState.startSessionMonitorLoop()` — periodic polling, git refresh on tick 10
- `AppState.startGatewaySessionRefreshLoop()` — 15s interval, error state clearing

**Shallow UI tests (24 tests — existence only, no outcome verification):**
All 24 tests in `AgentBoardUITests.swift` use `XCTAssertTrue(element.exists)` instead of verifying state changes.

**Mock-only tests (no real gateway):**
- `ChatSendThinkingTests` — uses HappyPathOpenClawService mock
- `KeychainServiceTests` — uses InMemoryTokenStorage mock (not real Keychain)

### P2 — Known Open Beads

| Bead | Description |
|------|-------------|
| AB-36j | `updateBead` bd-close path not covered |
| AB-0mn | Duplicate of AB-36j |

---

## Execution Plan (Current Sprint)

### Phase A: Fix Test Infrastructure (Do First)
- [x] Fix `HistoryDashboardOutcomeTests.swift` @MainActor build error
- [ ] Fix `AppConfigStoreLifecycleTests` flaky tests — serialize tests that share `~/.openclaw/openclaw.json`

### Phase B: P0 Bug Documentation Tests
1. `AppStateMiscTests.swift` — add `updateBead` bd-close test (closes AB-36j, AB-0mn)
2. `AppStateOpenClawErrorTests.swift` — add `loadChatHistory` connected-but-failed test
3. `KeychainServiceTests.swift` — add real Keychain delete/round-trip tests

### Phase C: AppState Async Loop Tests (New file)
- `AppStateConnectionLoopTests.swift` — retry backoff, non-retryable exit, error toast
- `AppStateSessionMonitorLoopTests.swift` — polling behavior, git refresh tick

### Phase D: Upgrade Shallow UI Tests
Convert `AgentBoardUITests.swift` tests to verify actual state changes post-action.

---

## Quality Gates

```bash
# Build (must be clean):
xcodebuild build -scheme AgentBoard -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Unit tests (must pass):
xcodebuild test -scheme AgentBoard -destination 'platform=macOS' \
  -only-testing:AgentBoardTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Lint:
swiftlint lint --strict
```

---

## Technical Constraints

- Swift 6 + `SWIFT_STRICT_CONCURRENCY = complete` — new tests must handle `@MainActor`, `Sendable`, actor isolation
- New unit tests: Swift Testing (`@Test`, `#expect`, `@Suite`)
- UI tests: XCTest (`XCTestCase`) — Swift Testing cannot drive `XCUIApplication`
- `project.yml` is source of truth — run `xcodegen generate` after adding test files
- All tests must pass with `CODE_SIGN_IDENTITY=""` (headless CI)
