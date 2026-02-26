# Test Coverage Plan

## Project: AgentBoard
## Date: 2026-02-26
## Focus: Comprehensive — remaining gaps after prior coverage audit

---

## Current State

- **Total tests:** ~254 (164 functional, 36 integration, 4 contract, 39 shallow, 11 mock-only)
- **Interactive elements:** 122+ across 20 views
- **Prior sessions added:** CoordinationService, WorkspaceNotesService, DeviceIdentity, GatewayClient message parsing, GitService, AppState chat/layout/project/session tests

### Well-Tested (do NOT re-test)
- DeviceIdentity — all crypto methods
- CoordinationService — JSONL entity parsing
- WorkspaceNotesService — date navigation + ontology
- GitService — real integration + parser
- ChatSendThinkingTests — switchSession (5 tests), thinking level (4 tests)
- ConnectionErrorTests — all error classification
- AppStateLayoutTests — toggles, focus mode, UserDefaults persistence
- AppStateProjectTests — addProject, removeProject, selectProject
- BeadsWatcherTests — file watch, stop
- JSONLParser (beads) — via UtilityCoverageTests

### Genuine Gaps Remaining

**P0 — Tests pass but real behavior untested**
- GatewayClient WebSocket connect/request flow: all production chat paths mocked
- AppState bead operations silently return nil when no project selected (9 operations) — no feedback to user, no test documenting this

**P1 — Real code paths with zero test coverage**
- AppConfigStore.loadOrCreate() / save() — config lifecycle never tested
- AppConfigStore.hydrateOpenClawIfNeeded() — gateway config merging logic untested
- CanvasRenderer HTML generation — `escapeHTML` and `htmlDocument(for:)` are private and untested (XSS risk)
- JSONLEntityParser — the shared entity parser utility has no direct unit tests
- AppState.loadAgentIdentity() — never tested; agentName/agentAvatar could be broken silently

**P2 — Pure logic with no tests**
- TerminalLauncher string escaping: `shellSingleQuoted()`, `generateITerm2Script()`, `generateTerminalScript()`
- AppState.openIssueFromChat() — trivial but zero coverage

---

## Coverage Areas

### Area 1: AppConfigStore Config Lifecycle Tests (Priority: P1)
**Files to create/modify:** `AgentBoardTests/AppConfigStoreTests.swift` (extend)
**Tests to write:**
1. `loadOrCreateCreatesDefaultConfigWhenFileMissing` — writes file, returns default AppConfig
2. `loadOrCreateLoadsExistingConfigFromDisk` — saves config to temp dir, loads it back
3. `loadOrCreateRoundTrip` — save then loadOrCreate returns same values
4. `saveWritesJSONToDisk` — verifiable via Data read after save
5. `hydrateOpenClawFillsMissingGatewayURL` — discovery result fills blank config
6. `hydrateOpenClawDoesNotOverwriteManualGatewayURL` — existing URL preserved
7. `hydrateOpenClawFillsMissingToken` — token propagated from discovery
8. `hydrateOpenClawIgnoresDiscoveryWhenBothFieldsSet` — both set = no change
9. `discoverOpenClawConfigReturnsNilForMalformedJSON` — malformed JSON → nil
10. `discoverOpenClawConfigReturnsNilForMissingFile` — missing file → nil (not crash)

**Test types:** Integration (real temp file I/O, no mocks)
**Dependencies:** None
**Estimated test count:** 10

---

### Area 2: CanvasRenderer HTML Generation Tests (Priority: P1)
**Files to create/modify:**
- `AgentBoard/Services/CanvasRenderer.swift` — change `private func escapeHTML` and `private func htmlDocument` to `internal` (remove `private` keyword)
- `AgentBoardTests/CanvasRendererHTMLTests.swift` (new)

**Tests to write:**
1. `escapeHTMLHandlesAmpersand` — `&` → `&amp;`
2. `escapeHTMLHandlesLessThan` — `<` → `&lt;`
3. `escapeHTMLHandlesGreaterThan` — `>` → `&gt;`
4. `escapeHTMLHandlesDoubleQuote` — `"` → `&quot;`
5. `escapeHTMLHandlesSingleQuote` — `'` → `&#39;`
6. `escapeHTMLHandlesEmptyString` — empty → empty
7. `escapeHTMLHandlesCombinedXSSPayload` — `<script>alert('xss')&</script>` fully escaped
8. `htmlDocumentMarkdownContainsArticleBody` — contains `<article class="markdown-body">`
9. `htmlDocumentHTMLContainsHtmlBody` — contains `<article class="html-body">`
10. `htmlDocumentDiffEscapesFilenameAndCode` — filename and code are HTML-escaped in output
11. `htmlDocumentDiagramContainsMermaidDiv` — contains `<div class="mermaid">`
12. `htmlDocumentTerminalEscapesOutput` — terminal output is escaped in `<code>` block
13. `htmlDocumentImageEscapesURL` — URL special chars escaped in img src

**Test types:** Unit (no mocks, no WKWebView — tests HTML string output directly)
**Dependencies:** CanvasRenderer `private` → `internal` visibility change
**Estimated test count:** 13

---

### Area 3: JSONLEntityParser Direct Unit Tests (Priority: P1)
**Files to create/modify:** `AgentBoardTests/JSONLEntityParserTests.swift` (new)
**Tests to write:**
1. `parseTextCreateOpBuildsEntity` — single create op → entity with type and properties
2. `parseTextUpdateMergesProperties` — create then update → merged properties
3. `parseTextUpdatePreservesUnchangedProperties` — non-updated props survive update
4. `parseTextDeleteRemovesEntity` — create then delete → empty dict
5. `parseTextUpdateOnMissingIDIsNoOp` — update for unknown ID → empty dict
6. `parseTextDeleteOnMissingIDIsNoOp` — delete for unknown ID → empty dict
7. `parseTextUnknownOpIsIgnored` — `op: "patch"` → entity NOT created
8. `parseTextMalformedJSONLineIsSkipped` — invalid JSON → still parses valid lines
9. `parseTextEmptyStringReturnsEmptyDict` — `""` → `[:]`
10. `parseTextMultipleEntities` — 3 creates → 3 entities in dict
11. `parseFileMissingFileReturnsEmptyDict` — non-existent path → `[:]`
12. `parseFileReadsAndParsesRealFile` — write JSONL to temp file, parse it

**Test types:** Unit (no mocks, pure string/file logic)
**Dependencies:** None
**Estimated test count:** 12

---

### Area 4: TerminalLauncher Pure Function Tests (Priority: P2)
**Files to create/modify:**
- `AgentBoard/Utilities/TerminalLauncher.swift` — change `private static` to `static` on `shellSingleQuoted`, `generateITerm2Script`, `generateTerminalScript`
- `AgentBoardTests/TerminalLauncherTests.swift` (new)

**Tests to write:**
1. `shellSingleQuotedWrapsInSingleQuotes` — `"hello"` → `"'hello'"`
2. `shellSingleQuotedEscapesEmbeddedSingleQuote` — `"it's"` → `"'it'\\''s'"`
3. `shellSingleQuotedHandlesEmptyString` — `""` → `"''"`
4. `shellSingleQuotedHandlesBackslash` — `"foo\\bar"` → `"'foo\\bar'"` (no change, literal)
5. `shellSingleQuotedHandlesSpaces` — `"hello world"` → `"'hello world'"`
6. `generateITerm2ScriptContainsCommand` — output contains the command string
7. `generateITerm2ScriptContainsProjectPath` — output contains the project path
8. `generateTerminalScriptContainsCommand` — output contains the command
9. `generateTerminalScriptContainsDoScript` — output contains `do script` AppleScript keyword

**Test types:** Unit (pure string functions, no OS interaction)
**Dependencies:** TerminalLauncher `private static` → `static` visibility change
**Estimated test count:** 9

---

### Area 5: SessionMonitor Integration Tests (Priority: P0)
**Files to create/modify:** `AgentBoardTests/SessionMonitorIntegrationTests.swift` (new)

tmux IS installed on the dev machine, so we can run real tmux integration tests.

**Tests to write:**
1. `listSessionsDoesNotThrowWhenTmuxAvailable` — real tmux call, returns array (may be empty)
2. `listSessionsReturnsCodingSessionArray` — result type is `[CodingSession]`
3. `listSessionsHandlesNoRunningSessionsGracefully` — empty array is valid, no throw
4. `launchSessionThrowsForNonExistentProjectPath` — invalid path → `SessionMonitorError.launchFailed`
5. `launchSessionThrowsForEmptyProjectSlug` — path that produces empty slug throws meaningful error
6. `capturePane_ThrowsForNonExistentSession` — non-existent session name → throws (tests error propagation)

**Integration test tag:** `.tags(.integration)` — allows CI to skip with `swift test --skip-tags integration`

**Test types:** Integration (uses real tmux, no mocks)
**Dependencies:** tmux must be installed (already confirmed)
**Estimated test count:** 6

---

## Execution Strategy

- **Workers:** 3 workers
- **Worker 1:** Area 1 (AppConfigStore) + Area 3 (JSONLEntityParser)
- **Worker 2:** Area 2 (CanvasRenderer) + Area 4 (TerminalLauncher)
- **Worker 3:** Area 5 (SessionMonitor Integration)
- **Dependencies between areas:** None — all are independent

## Verification Criteria
- [ ] All new tests build successfully (`xcodebuild build`)
- [ ] All new tests pass (`xcodebuild test`)
- [ ] No existing tests broken or removed
- [ ] CanvasRenderer escapeHTML fully covers all 5 HTML special chars
- [ ] JSONLEntityParser covers create/update/delete/malformed/missing-file
- [ ] AppConfigStore covers loadOrCreate + save round-trip + hydrate logic
- [ ] TerminalLauncher covers single-quote escaping edge cases
- [ ] All beads closed
- [ ] Changes committed and pushed
