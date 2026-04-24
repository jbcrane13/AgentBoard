# AgentBoard UI Test Validation Plan

## Problem Statement

Current UI tests verify **element existence** and **sheet presentation/dismissal**, but do NOT validate that user interactions actually **succeed in changing state** or **produce the expected outcome**.

## Critical Gaps (Interactions Without Outcome Validation)

### 1. Create Bead Flow
**Current Test:** Verifies sheet opens, has fields, can be cancelled
**Missing:** Does Save actually create a bead? Does it appear in the board?

### 2. New Session Launch
**Current Test:** Verifies sheet opens and can be cancelled
**Missing:** Does Launch actually create a tmux session? Is it in the sessions list?

### 3. Settings Save
**Current Test:** Verifies fields exist and accept input
**Missing:** Does Save actually persist settings? Are they there on relaunch?

### 4. Chat Message Send
**Current Test:** Verifies send button exists
**Missing:** Does sending actually add message to history? Does response arrive?

### 5. Session Switch
**Current Test:** Not tested
**Missing:** Does switching sessions actually load different chat history?

### 6. Thinking Level Change
**Current Test:** Not tested (AB-2cs bug)
**Missing:** Does changing thinking level actually affect LLM responses?

### 7. Project Selection
**Current Test:** Not tested
**Missing:** Does selecting a project actually load its beads?

### 8. Mark Bead Complete
**Current Test:** Not tested
**Missing:** Does marking complete actually move bead to Done column?

## Proposed Solution: Outcome-Validating UI Tests

### Strategy
1. **Query actual state** after interaction (not just UI elements)
2. **Use XCTest expectations** for async operations
3. **Verify backend/service calls** where possible
4. **Test failure paths** as well as success paths

### Implementation Approach

For each critical interaction, add tests that:
1. Perform the action (tap button, type text, etc.)
2. Wait for async completion
3. Verify the ACTUAL outcome (not just UI state)

Example pattern:
```swift
func testCreateBeadActuallyCreatesBead() throws {
    // Given: Initial bead count
    let initialBeads = countBeadsOnBoard()
    
    // When: Create a bead with unique title
    let uniqueTitle = "Test Bead \(UUID().uuidString.prefix(8))"
    createBead(title: uniqueTitle)
    
    // Then: Bead count increased
    XCTAssertEqual(countBeadsOnBoard(), initialBeads + 1)
    
    // And: Bead with our title exists
    XCTAssertTrue(beadExists(title: uniqueTitle))
}
```

## Detailed Test Specifications

### Area 1: Bead Creation (Critical)
- [ ] testCreateBeadIncreasesBoardCount
- [ ] testCreateBeadAppearsInCorrectColumn
- [ ] testCreateBeadPersistsAfterRestart
- [ ] testCreateBeadValidationShowsErrorOnEmptyTitle

### Area 2: Session Launch (Critical)
- [ ] testLaunchSessionCreatesTmuxSession
- [ ] testLaunchSessionAppearsInSidebar
- [ ] testLaunchSessionWithPromptInjectsPrompt
- [ ] testLaunchSessionFailureShowsError

### Area 3: Settings Persistence (High)
- [ ] testSaveSettingsPersistsGatewayURL
- [ ] testSaveSettingsPersistsToken
- [ ] testSettingsLoadOnAppLaunch

### Area 4: Chat Interactions (High)
- [ ] testSendMessageAppearsInHistory
- [ ] testSendMessageTriggersGatewayCall
- [ ] testReceiveResponseAppendsToChat
- [ ] testSwitchSessionLoadsDifferentHistory

### Area 5: Project Management (Medium)
- [ ] testSelectProjectLoadsItsBeads
- [ ] testAddProjectAppearsInList
- [ ] testRemoveProjectDisappearsFromList

### Area 6: Bead State Changes (Medium)
- [ ] testMarkBeadDoneMovesToDoneColumn
- [ ] testMarkBeadInProgressMovesToInProgressColumn
- [ ] testBeadStatePersists

### Area 7: Error Handling (High)
- [ ] testGatewayConnectionFailureShowsError
- [ ] testInvalidSettingsShowsValidationError
- [ ] testSessionLaunchFailureShowsError

## Testing Infrastructure Needed

1. **State Query Helpers**
   - Query actual beads from board (not just UI)
   - Query actual sessions from SessionMonitor
   - Query actual settings from AppConfigStore

2. **Async Test Helpers**
   - Wait for gateway response
   - Wait for tmux session creation
   - Wait for settings persistence

3. **Mock/Spy Infrastructure**
   - Spy on OpenClawService calls
   - Spy on SessionMonitor calls
   - Mock gateway responses for offline testing

4. **Test Data Cleanup**
   - Clean up created beads after tests
   - Clean up tmux sessions after tests
   - Reset settings after tests

## Implementation Phases

### Phase 1: Infrastructure (Priority 0)
- Create test helpers for state queries
- Create async expectation helpers
- Set up test data cleanup

### Phase 2: Critical Flows (Priority 1)
- Bead creation with outcome validation
- Session launch with outcome validation
- Settings persistence

### Phase 3: Chat & Gateway (Priority 1)
- Chat send/receive
- Session switching
- Thinking level changes

### Phase 4: Complete Coverage (Priority 2)
- All remaining interactions
- Error handling
- Edge cases

## Success Criteria

Every user interaction test must verify:
1. ✅ The action completed successfully (not just that button was tapped)
2. ✅ The expected state change occurred
3. ✅ The change persists (where applicable)
4. ✅ Errors are displayed when operations fail

## Notes for Implementation

- Use `XCTAssertEqual` for state comparisons, not just `XCTAssertTrue`
- Use `XCTAssertThrowsError` for failure cases
- Use `XCTAssertNotNil` for returned objects
- Use expectations for async operations
- Clean up test data in `tearDown`
- Run tests in isolated environment when possible
