# Test Coverage Plan

## Project: AgentBoard
## Date: 2026-02-20
## Focus: Comprehensive

---

## Current State

**Total tests: 43** (36 functional, 7 shallow, 0 disabled)

| Layer | Tested | Untested | Coverage |
|-------|--------|----------|----------|
| AppState public methods | 16 | 54 | 23% |
| Models | 11 | 8 | 58% |
| Services | 1 (JSONLParser) | 10 | 9% |
| Utilities | 7 | 1 | 88% |
| **TOTAL** | **35** | **73** | **32%** |

**Interactive UI elements: ~121 across 19 view files**
**Elements with functional UI test coverage: ~35 (~29%)**

### Key gaps:
- AppState has 54 untested public/internal methods — canvas directive parsing, layout
  toggles, project management, git summary building, bead creation argument logic
- Every service except JSONLParser has zero test coverage
- 7 of 10 UI tests are shallow (existence checks only) — no behavioral assertions for
  board, chat, settings, new session, or epics flows

---

## Coverage Areas

### Area 1: AppState Layout Toggles (Priority: P0)
**Files to create:** `AgentBoardTests/AppStateLayoutTests.swift`
**Tests to write:**
1. `isFocusMode` returns true only when both sidebar and board are hidden
2. `toggleSidebar` flips `sidebarVisible` and persists to UserDefaults key `AB_sidebarCollapsed`
3. `toggleBoard` flips `boardVisible` and persists to UserDefaults key `AB_boardCollapsed`
4. `toggleFocusMode` from normal → sets both to false
5. `toggleFocusMode` from focus → sets both to true
6. `persistLayoutState` writes correct inverted values to UserDefaults
7. `sidebarVisible` initializes from UserDefaults at construction
**Estimated test count: 7**

### Area 2: AppState Miscellaneous Public Logic (Priority: P0)
**Files to create:** `AgentBoardTests/AppStateMiscTests.swift`
**Tests to write:**
1. `sendChatMessage` with empty/whitespace-only string → no message appended
2. `sendChatMessage` with valid text → user message and placeholder assistant message appended
3. `updateOpenClaw` writes gateway URL/token to appConfig and sets statusMessage
4. `dismissConnectionErrorToast` sets showConnectionErrorToast to false
5. `clearUnreadChatCount` resets to 0
6. `gitSummary(for:)` returns summary when present, nil when absent
**Estimated test count: 6**

### Area 3: AppState Project Management (Priority: P0)
**Files to create:** `AgentBoardTests/AppStateProjectTests.swift`
**Tests to write:**
1. `addProject` with duplicate path sets statusMessage "Project already exists." and does not append
2. `addProject` with new path appends ConfiguredProject to appConfig.projects
3. `removeProject` removes matching path from appConfig.projects
4. `removeProject` selected project → selectedProjectPath falls back to next project
5. `rescanProjectsDirectory` with empty discoveries → statusMessage "No new projects found."
6. `selectProject` sets selectedProjectID, clears activeSessionID, sets sidebar to board
**Estimated test count: 6**

### Area 4: GitService Parsing Logic (Priority: P0)
**Files to create:** `AgentBoardTests/GitServiceTests.swift`
**Tests to write (use real AgentBoard repo or temp git repo):**
1. `fetchCurrentBranch` on AgentBoard repo returns non-empty string
2. `fetchCommits` on AgentBoard repo returns sorted commits with non-nil SHAs
3. Bead ID extraction from commit subjects: "AB-123: fix" → ["AB-123"]
4. Bead ID extraction handles multiple IDs and deduplication
5. Branch parsing from refs: "HEAD -> main, origin/main" → "main"
6. Branch parsing: empty refs → nil branch
**Estimated test count: 6**

### Area 5: AppConfigStore Discovery Logic (Priority: P0)
**Files to create:** `AgentBoardTests/AppConfigStoreTests.swift`
**Tests to write:**
1. `discoverProjects(in:)` with temp dir containing `.beads` subdir → returns that project
2. `discoverProjects(in:)` with temp dir without `.beads` → returns empty
3. `discoverProjects(in:)` with non-existent dir → returns empty
4. `discoverProjects` sorts results alphabetically by folder name
5. `discoverOpenClawConfig` with temp openclaw.json → parses gateway URL and token
6. `discoverOpenClawConfig` with missing file → returns nil
**Estimated test count: 6**

### Area 6: KeychainService Round-Trip (Priority: P0)
**Files to create:** `AgentBoardTests/KeychainServiceTests.swift`
**Tests to write:**
1. `saveToken` then `loadToken` → returns same token string
2. `saveToken` twice (update path) → `loadToken` returns the newer value
3. `deleteToken` then `loadToken` → returns nil
4. `loadToken` with no prior save → returns nil
5. `KeychainError.errorDescription` returns non-empty string for any OSStatus
**Estimated test count: 5**

### Area 7: UI — Board Create Bead and Task Detail (Priority: P1)
**Files to modify:** `AgentBoardUITests/AgentBoardUITests.swift`
**Tests to write:**
1. Clicking "Create Bead" opens sheet with Title field, Kind picker, Status picker, Cancel and Save buttons
2. "Cancel" in Create Bead sheet dismisses the sheet (title field disappears)
3. Entering a title and tapping Save: sheet dismisses → "Create Bead" button visible again
4. In board view, if a bead exists, tapping it opens a detail sheet with Close and Save buttons
5. Cancel on detail sheet dismisses it
**Estimated test count: 5**

### Area 8: UI — Settings and New Session Behavioral Upgrades (Priority: P1)
**Files to modify:** `AgentBoardUITests/AgentBoardUITests.swift`
**Tests to write:**
1. Settings: switching to Manual mode then typing a URL persists in field after returning (functional upgrade of testSettingsViewFields)
2. Settings: clicking "Auto-Discover" picker resets back to auto mode
3. New Session: filling prompt field and cancelling — sheet dismissed with no visible error
4. History view filter: clicking "Commits" filter updates event type display (no crash)
**Estimated test count: 4**

### Area 9: UI — Epics, Agents, Canvas Controls (Priority: P1)
**Files to modify:** `AgentBoardUITests/AgentBoardUITests.swift`
**Tests to write:**
1. Cmd+3 navigates to Agents view — "Sessions Today" text AND a table/list container visible
2. Epics view: "Create Epic" button opens creation form (with title field visible)
3. History view: "All Events" filter is selected by default and event list container present
4. Canvas mode: zoom-in then reset-zoom button restores default label (100%)
**Estimated test count: 4**

---

## Execution Strategy

- **Worker count:** 4 (1 per 2 areas)
- **Worker assignments:**
  - Worker A: Areas 1 + 2 (AppState layout + misc unit tests)
  - Worker B: Areas 3 + 4 (AppState project mgmt + GitService)
  - Worker C: Areas 5 + 6 (AppConfigStore + KeychainService)
  - Worker D: Areas 7 + 8 + 9 (all UI tests)
- **No dependencies between workers** — each creates or modifies distinct files

## Verification Criteria
- [ ] All tests build successfully
- [ ] No existing tests broken or removed
- [ ] Every coverage area implemented
- [ ] All beads closed with reasons
- [ ] Changes committed and pushed
- [ ] `bd sync` completed

## Key Implementation Notes

1. **Swift 6 / @MainActor**: AppState is `@MainActor final class`. Tests in `AppStateCoverageTests`
   use `@MainActor struct` with `@Test`. Follow this same pattern for all new AppState tests.

2. **Swift Testing vs XCTest**: Unit tests use Swift Testing (`@Suite`, `@Test`, `#expect`).
   UI tests use XCTest (`XCTestCase`, `XCTAssert*`). Match the framework for each file.

3. **GitService is an actor**: Call its methods with `await` in `async` test contexts.

4. **AppState uses UserDefaults**: Clean up keys after tests, or use separate keys to avoid
   polluting real settings. Use `defer` to remove test keys.

5. **KeychainService uses real Keychain**: Use a unique test account name, or delete after each
   test. The existing service/account constants are fine for round-trip tests since we delete after.

6. **AppConfigStore.discoverProjects**: Safe to test with temp directories — takes URL parameter.
   Skip testing `loadOrCreate`/`save` directly (writes to real `~/.agentboard/config.json`).

7. **UI tests add to existing file**: All new UI tests go into `AgentBoardUITests.swift` as
   additional `func test*()` methods using the existing helper infrastructure.

8. **Be environment-tolerant**: Network tests (`testConnection`) and tmux-dependent tests
   (terminal output) should accept graceful failure as valid outcome.
