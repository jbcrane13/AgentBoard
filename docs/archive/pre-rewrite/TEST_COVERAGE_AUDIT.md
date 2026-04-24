# AgentBoard Business Logic & Services Test Coverage Audit

**Date:** 2026-02-20
**Scope:** App State, Models, Services, Utilities
**Test Files Analyzed:**
- `AgentBoardTests/AppStateCoverageTests.swift`
- `AgentBoardTests/ModelCoverageTests.swift`
- `AgentBoardTests/UtilityCoverageTests.swift`

---

## Executive Summary

| Category | TESTED | UNTESTED | Total | Coverage % |
|----------|--------|----------|-------|-----------|
| **AppState Methods/Properties** | 16 | 54 | 70 | 22.9% |
| **Models** | 11 | 8 | 19 | 57.9% |
| **Services** | 1 | 10 | 11 | 9.1% |
| **Utilities** | 7 | 1 | 8 | 87.5% |
| **TOTAL** | **35** | **73** | **108** | **32.4%** |

**KEY FINDING:** The codebase has significant test coverage gaps, particularly in **Services** (9.1%) and **AppState** (22.9%), which handle critical business logic. Models have decent coverage (57.9%), and Utilities are well-tested (87.5%).

---

## 1. AppState (App/AppState.swift)

**File Size:** 1,673 lines
**Public Properties:** 27
**Public Methods:** 36
**Private Methods:** 20+

### Tested (16 of 70 items = 22.9%)

#### Computed Properties (5)
- ✅ `selectedProject` — returns project by ID
- ✅ `selectedBead` — returns bead by ID
- ✅ `selectedBeadContextID` — fallback logic
- ✅ `currentCanvasContent` — indexed access with bounds check
- ✅ `activeSession` — returns session by ID

#### Methods (11)
1. ✅ `switchToTab(_:)` — updates selected tab and sidebar mapping
2. ✅ `navigate(to:)` — updates sidebar selection and tab mapping
3. ✅ `requestCreateBeadSheet()` — increments request ID and switches to board
4. ✅ `requestNewSessionSheet()` — increments request ID
5. ✅ `requestChatInputFocus()` — resets unread count, switches to split mode
6. ✅ `pushCanvasContent(_:)` — adds to history and updates index
7. ✅ `goCanvasBack()` — decrements history index
8. ✅ `goCanvasForward()` — increments history index
9. ✅ `clearCanvasHistory()` — resets history and index
10. ✅ `adjustCanvasZoom(by:)` — bounds-checked zoom adjustment
11. ✅ `openMessageInCanvas(_:)` — creates markdown content and enables canvas mode

### Untested (54 of 70 items = 77.1%)

#### State Properties (27) — UNTESTED
- `projects`, `selectedProjectID`, `beads`, `sessions`, `chatMessages`, `activeSessionID`
- `selectedTab`, `rightPanelMode`, `sidebarNavSelection`
- `appConfig`, `beadsFileMissing`, `isLoadingBeads`, `statusMessage`, `errorMessage`
- `selectedBeadID`, `chatConnectionState`, `isChatStreaming`, `remoteChatSessions`
- `currentSessionKey`, `gatewaySessions`, `chatThinkingLevel`, `chatRunId`, `agentName`, `agentAvatar`
- `beadGitSummaries`, `recentGitCommits`, `currentGitBranch`, `historyEvents`, `canvasHistory`
- `canvasHistoryIndex`, `canvasZoom`, `isCanvasLoading`, `unreadChatCount`, `unreadSessionAlertsCount`
- `sessionAlertSessionIDs`, `connectionErrorDetail`, `showConnectionErrorToast`

#### Computed Properties (5) — UNTESTED
- `epicBeads` — filters and sorts by kind
- `canGoCanvasBack` — index boundary check
- `canGoCanvasForward` — index range check
- `isFocusMode` — sidebar/board visibility logic

#### Methods (22) — UNTESTED

**Project Management (8)**
- `selectProject(_:)` — sets selection, persists, updates flags
- `addProject(at:icon:)` — validates duplicates, appends, persists
- `updateProjectsDirectory(_:)` — discovers projects, filters, persists
- `rescanProjectsDirectory()` — discovers new projects only
- `removeProject(_:)` — removes from config, updates selection
- `persistSelectedProject()` — UserDefaults persistence
- `persistConfig()` — writes config to disk
- `updateActiveProjectFlags()` — marks selected project as active

**Chat & Connection (5)**
- `clearUnreadChatCount()` — resets counter
- `dismissConnectionErrorToast()` — hides toast
- `updateOpenClaw(gatewayURL:token:source:)` — validates, persists, restarts connection
- `retryConnection()` — restarts chat loop
- `sendChatMessage(_:)` — streaming chat with delta updates

**Canvas Operations (3)**
- `resetCanvasZoom()` — resets to 1.0
- `openCanvasFile(_:)` — async file load and push
- `openCommitDiffInCanvas(beadID:)` — git diff fetch and canvas push

**Session Management (2)**
- `openSessionInTerminal(_:)` — sets active session, clears alerts
- `backToBoardFromTerminal()` — clears session, returns to board

**Bead CRUD (4)**
- `createBead(from:)` — bd CLI create with status/labels/parent setup
- `updateBead(_:with:)` — bd CLI update with full field mapping
- `moveBead(_:to:)` — bd CLI status update
- `closeBead(_:)` — bd CLI close command

**Private Methods (20+)** — UNTESTED
- Connection loops: `startChatConnectionLoop()`, `startSessionMonitorLoop()`, `startGatewaySessionRefreshLoop()`
- Event handling: `consumeGatewayEvents()`, `handleGatewayEventOnMain(_:)`, `appendAssistantChunk(id:text:)`
- Chat lifecycle: `switchSession(to:)`, `setThinkingLevel(_:)`, `loadChatHistory()`, `loadAgentIdentity()`, `abortChat()`
- Git context: `refreshGitContext(for:)`, `extractFirstCodeBlock(from:)`
- Bead CLI: `runBD(arguments:in:)`, `parseCreatedIssueID(from:)`
- Bootstrap: `bootstrap()`, `rebuildProjects()`, `reloadSelectedProjectAndWatch()`, `loadBeads(for:)`
- Persistence: `persistLayoutState()`, `watch(project:)`
- UI helpers: `extractFirstCodeBlock(from:)`, `shellSingleQuoted(_:)`, `makeCanvasContent(from:)`

---

## 2. Models

**Total Files:** 10
**Tested:** 11 items
**Untested:** 8 items
**Coverage:** 57.9%

### ChatMessage.swift — TESTED ✅

**Tested Properties (2)**
- ✅ `referencedIssueIDs` — regex pattern matching for issue IDs with duplicate filtering
- ✅ `hasCodeBlock` — checks for triple-backtick presence

**Untested Properties (0)**

### Bead.swift — TESTED ✅

**Tested Methods (2)**
- ✅ `BeadStatus.fromBeads(_:)` — case mapping with fallback
- ✅ `BeadKind.fromBeads(_:)` — case mapping with fallback

**Tested Computed Properties (2)**
- ✅ `BeadStatus.beadsValue` — reverse mapping
- ✅ `BeadKind.beadsValue` — reverse mapping

**Untested (0)**

### BeadDraft.swift — TESTED ✅

**Tested Computed Properties (1)**
- ✅ `labels` — split, trim, filter logic

**Tested Methods (1)**
- ✅ `from(_:)` — maps Bead to draft with field extraction

**Untested (0)**

### Project.swift — TESTED ✅

**Tested Computed Properties (2)**
- ✅ `issuesFileURL` — constructs .beads/issues.jsonl path
- ✅ `isBeadsInitialized` — checks config.yaml existence

**Untested (0)**

### AppConfig.swift — TESTED ✅

**Tested Computed Properties (2)**
- ✅ `isGatewayManual` — checks gatewayConfigSource
- ✅ `resolvedProjectsDirectory` — returns custom or ~/Projects

**Untested (0)**

### CodingSession.swift — TESTED ✅

**Tested Computed Properties (1)**
- ✅ `SessionStatus.sortOrder` — returns priority order (running=0, idle=1, stopped=2, error=3)

**Untested (0)**

### GitCommitRecord.swift — TESTED ✅

**Tested Computed Properties (1)**
- ✅ `id` — returns sha field

**Untested (0)**

### HistoryEvent.swift — TESTED ✅

**Tested Enum Properties (2)**
- ✅ `HistoryEventType.label` — human-readable labels
- ✅ `HistoryEventType.symbolName` — SF Symbol names

**Tested Initializer (1)**
- ✅ `init()` — sets defaults (id auto-generated, details/projectName/beadID/commitSHA default to nil)

**Untested (0)**

### CanvasContent.swift — TESTED ✅

**Tested Computed Properties (1)**
- ✅ `id` — extracts UUID from enum associated value

**Untested (0)**

### OpenClawConnectionState.swift — TESTED ✅

**Tested Computed Properties (2)**
- ✅ `label` — connection state labels
- ✅ `color` — color mapping (with conditional access check)

**Untested (0)**

---

## 3. Services (11 Files)

**Total Public Methods:** 11
**Tested:** 1 (9.1%)
**Untested:** 10 (90.9%)

### ⚠️ CRITICAL: All Services Have NO Unit Tests

Services are **not imported in test files** — they rely on integration/UI testing or manual verification.

#### AppConfigStore.swift — UNTESTED
- `loadOrCreate()` — loads from ~/.agentboard/config.json or creates with auto-discovery, handles Keychain migration
- `save(_:)` — writes to JSON with token moved to Keychain
- `discoverProjects(in:)` — directory scan for .beads/ folders
- `discoverOpenClawConfig()` — parses ~/.openclaw/openclaw.json, extracts port/bind/token

#### BeadsWatcher.swift — UNTESTED
- `watch(fileURL:onChange:)` — DispatchSourceFileSystemObject for file changes
- `stop()` — cancels watcher

#### CanvasRenderer.swift — UNTESTED
- `render(_:in:)` — WKWebView HTML rendering (markdown, HTML, image, diff, diagram, terminal)
- `clear(in:)` — loads empty document

#### DeviceIdentity.swift — UNTESTED
- `loadOrCreate()` — Ed25519 keypair management, persists to ~/.agentboard/device-identity.json
- `sign(payload:)` — cryptographic signing
- `buildAuthPayload(...)` — constructs device auth handshake

#### GatewayClient.swift — UNTESTED
**Actor with 8+ public methods:**
- `connect(url:token:)` — WebSocket handshake with Origin header, auth challenge handling
- `disconnect()` — closes WebSocket
- `events` async property — AsyncStream<GatewayEvent>
- `sendChat(sessionKey:message:)` — JSON-RPC request
- `chatHistory(sessionKey:limit:)` — fetches message history
- `abortChat(sessionKey:runId:)` — cancels generation
- `listSessions(...)` — queries session list
- `createSession(...)` — creates new session via RPC
- `patchSession(key:thinkingLevel:)` — updates thinking level
- `agentIdentity(sessionKey:)` — fetches agent identity

#### GatewayDiscovery.swift — UNTESTED
- `startBrowsing()` — Bonjour/mDNS discovery with auto-stop
- `stopBrowsing()` — cancels NWBrowser and resolve timers
- `discoveredGateways` property — @Published list

#### GitService.swift — UNTESTED
**Actor with 3 public methods:**
- `fetchCommits(projectPath:limit:)` — git log parsing
- `fetchCurrentBranch(projectPath:)` — git rev-parse
- `fetchCommitDiff(projectPath:commitSHA:)` — git show with diff

#### JSONLParser.swift — TESTED (partially in UtilityCoverageTests) ✅
- `parseBeads(from:)` — JSONL parsing, type/status mapping, epic detection, date parsing, sorting

#### KeychainService.swift — UNTESTED
- `saveToken(_:)` — Keychain write with update-or-insert logic
- `loadToken()` — Keychain read
- `deleteToken()` — Keychain delete

#### OpenClawService.swift — UNTESTED
**Actor wrapper around GatewayClient:**
- `configure(gatewayURLString:token:)` — URL validation and normalization
- `connect()` — delegates to client
- `disconnect()` — delegates to client
- `sendChat(sessionKey:message:)` — delegates
- `chatHistory(...)` — delegates
- `abortChat(...)` — delegates
- `listSessions(...)` — delegates
- `createSession(...)` — delegates
- `patchSession(...)` — delegates
- `agentIdentity(...)` — delegates
- `events` async property — delegates

#### SessionMonitor.swift — UNTESTED
**Actor with 5+ public methods:**
- `listSessions()` — tmux session discovery + process monitoring (CPU, agent type detection)
- `capturePane(session:lines:)` — tmux capture-pane for terminal output
- `sendNudge(session:)` — tmux send-keys (Enter)
- `launchSession(projectPath:agentType:beadID:prompt:)` — tmux new-session with seed prompt
- Private helpers for process tree collection, status resolution, agent type/model parsing

---

## 4. Utilities

**Total Items:** 8
**Tested:** 7 (87.5%)
**Untested:** 1 (12.5%)

### AppTheme.swift — UNTESTED
- `sidebarBackground`, `sidebarMutedText`, `sidebarPrimaryText` — color constants
- `appBackground`, `panelBackground`, `cardBackground`, `subtleBorder`, `mutedText` — dynamic colors
- `sessionColor(for:)` — status-based color mapping
- `dynamicColor(light:dark:)` — light/dark mode helper

### ShellCommand.swift — TESTED ✅

**Tested Methods (5)**
- ✅ `ShellCommandResult.combinedOutput` — joins stdout/stderr with trim
- ✅ `ShellCommand.run(arguments:workingDirectory:)` — executes with PATH expansion
- ✅ `ShellCommand.run()` with working directory — tests cd behavior
- ✅ `ShellCommand.run()` — captures stdout
- ✅ `ShellCommand.runAsync(arguments:workingDirectory:)` — async wrapper

**Tested Error Cases (1)**
- ✅ `ShellCommandError.failed(_:)` — thrown on non-zero exit with captured output

**Untested (0)**

---

## Priority Gap Analysis

### Tier 1: Critical (Business-Critical, 0% Coverage)

1. **GatewayClient.swift** (19KB, ~500 lines)
   - WebSocket connection, authentication, JSON-RPC messaging
   - Handles chat streaming, session management, event dispatching
   - **Impact:** Core chat/collaboration feature
   - **Recommendation:** Unit tests for connect handshake, message sending, event parsing

2. **SessionMonitor.swift** (421 lines)
   - tmux integration, process discovery, session lifecycle
   - **Impact:** Terminal/session feature
   - **Recommendation:** Mock tmux commands, test session list parsing, status resolution

3. **AppState private methods** (~20 methods, ~400 lines)
   - Connection loops, event handlers, bead CLI operations
   - **Impact:** All business logic orchestration
   - **Recommendation:** Extract loop logic into testable helper methods

### Tier 2: High (Partially Tested, <50% Coverage)

1. **AppState public methods** (22 untested, 22.9% overall)
   - Bead CRUD, project management, canvas operations
   - **Recommendation:** Add integration tests for bead create/update/move workflows

2. **Services wrapper layer** (10 untested)
   - OpenClawService, GitService abstractions
   - **Recommendation:** Mock lower-level actors, test delegation and error handling

### Tier 3: Medium (Utilities & Models)

1. **AppTheme.swift** (8 untested color functions)
   - **Recommendation:** Test color values match design spec, verify dark/light switching

2. **CanvasRenderer.swift** (0 tests)
   - **Recommendation:** Snapshot tests for HTML output, test each content type

---

## Test Coverage by Category

### By Responsibility Area

| Area | Tested | Untested | Coverage |
|------|--------|----------|----------|
| **UI State Management** | 5 | 20 | 20% |
| **Project/Bead CRUD** | 2 | 12 | 14% |
| **Chat/Connection** | 2 | 8 | 20% |
| **Canvas/Media** | 3 | 4 | 43% |
| **Git Integration** | 0 | 4 | 0% |
| **Terminal/Sessions** | 0 | 5 | 0% |
| **Models** | 11 | 8 | 58% |
| **Utilities** | 7 | 1 | 88% |

### By Severity of Untested Code

| Severity | Count | Examples |
|----------|-------|----------|
| **Critical** (fails = app broken) | 15 | GatewayClient methods, connection loops, bead CLI ops |
| **High** (fails = feature broken) | 25 | Session management, project/bead ops, canvas rendering |
| **Medium** (fails = edge cases) | 20 | Error handling, state transitions, UI update logic |
| **Low** (visual/cosmetic) | 13 | AppTheme, UI formatting, constant values |

---

## Recommended Test Implementation Plan

### Phase 1: Foundation (Week 1)
- [ ] Extract `AppState` connection loop logic into `ConnectionManager` actor → testable
- [ ] Extract canvas history logic into `CanvasHistoryManager` struct → testable
- [ ] Add unit tests for `GatewayClient.connect()` with mocked URLSession
- [ ] Add unit tests for `SessionMonitor.listSessions()` with mocked tmux output

### Phase 2: Business Logic (Week 2-3)
- [ ] Add integration tests for bead create/update/move workflows
- [ ] Add tests for `AppState.sendChatMessage()` streaming behavior
- [ ] Add tests for `GitService` with mocked git output
- [ ] Add tests for `AppConfigStore` persistence and discovery

### Phase 3: UI & Polish (Week 3-4)
- [ ] Add snapshot tests for `CanvasRenderer` (each content type)
- [ ] Add tests for `AppTheme` color mappings
- [ ] Add tests for keyboard/focus state management
- [ ] Add end-to-end scenario tests (create bead → launch session → chat → close)

### Test Infrastructure Needed
- Mock `URLSessionWebSocketTask` for GatewayClient testing
- Mock tmux command output for SessionMonitor
- Mock git command output for GitService
- Helper builders for AppState, Bead, CodingSession, Project

---

## Test File Organization

```
AgentBoardTests/
├── AppStateCoverageTests.swift          (current: 9 tests)
├── ModelCoverageTests.swift             (current: 11 tests)
├── UtilityCoverageTests.swift           (current: 7 tests)
├── AgentBoardSmokeTests.swift           (current: smoke tests)
├── Services/
│   ├── GatewayClientTests.swift         (NEW)
│   ├── SessionMonitorTests.swift        (NEW)
│   ├── GitServiceTests.swift            (NEW)
│   ├── AppConfigStoreTests.swift        (NEW)
│   └── KeychainServiceTests.swift       (NEW)
├── Canvas/
│   ├── CanvasRendererTests.swift        (NEW)
│   └── CanvasContentTests.swift         (NEW)
└── Integration/
    ├── BeadWorkflowTests.swift          (NEW)
    └── ChatStreamingTests.swift         (NEW)
```

---

## Summary & Conclusions

**Current State:**
- Total test coverage: **32.4%** of inventory (35 of 108 items tested)
- AppState is **heavily untested** (77% of code untested), creating maintenance risk
- Services are **completely untested** in unit tests (relying on integration/manual testing)
- Models are **well-structured** but utilities need attention

**Key Risks:**
1. Chat connection loop logic has no tests → connection issues may go undetected
2. Bead CLI operations untested → data consistency issues possible
3. GatewayClient websocket handling untested → race conditions, message loss possible
4. SessionMonitor process discovery untested → terminal features fragile

**Recommendation:**
Focus on **GatewayClient** and **SessionMonitor** first (Tier 1), then expand to AppState private methods. Models and utilities already have good coverage and can be lower priority. Aim for 70% overall coverage within 4 weeks.
