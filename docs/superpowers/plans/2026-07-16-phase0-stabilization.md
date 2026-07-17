# Phase 0 — Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove AgentBoard's known instability — Apple-silicon-broken `gh` fallback, bootstrap crash path, and stale transport docs — before feature work begins.

**Architecture:** Three surgical fixes with no new subsystems: an executable-path probe for the `gh` CLI (mirroring the existing `resolveHermes()` pattern in `KanbanCLIWriter`), a no-op `AgentBoardCacheProtocol` conformance that replaces the bootstrap `fatalError`, and doc corrections. Spec: `docs/superpowers/specs/2026-07-16-feature-complete-stability-design.md` (Phase 0).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest/Swift Testing, xcodegen, SwiftLint.

## Global Constraints

- Swift 6 strict concurrency; all stores are `@MainActor @Observable`.
- No `ObservableObject`/`@Published`/`CoreData`/`@StateObject`/`DispatchQueue` (repo standard).
- TDD: write the failing test before the implementation.
- Every PR must build all three schemes (AgentBoard, AgentBoardMobile, AgentBoardCompanion) and pass SwiftLint strict.
- Unit tests run on the mac-mini node: `ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild test -scheme AgentBoard -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:AgentBoardTests"` (pull the branch on mac-mini first).
- New files must be picked up by xcodegen: run `xcodegen generate` after adding files.

---

### Task 1: `gh` executable resolution in GitHubWorkService

The CLI fallback hard-codes `/usr/local/bin/gh` (`GitHubWorkService.swift:302`), which does not exist on Apple-silicon Homebrew installs (`/opt/homebrew/bin/gh`).

**Files:**
- Modify: `AgentBoardCore/Services/GitHubWorkService.swift` (around line 295–320, `fetchIssuesViaCLI`)
- Test: `AgentBoardTests/GitHubWorkServiceTests.swift` (existing file — append)

**Interfaces:**
- Produces: `static func GitHubWorkService.resolvedGHPath(isExecutable: (String) -> Bool) -> String` — probes `/opt/homebrew/bin/gh` then `/usr/local/bin/gh`, returns `"gh"` if neither exists (matches `KanbanCLIWriter.resolveHermes()` fallback convention).

- [ ] **Step 1: Write the failing tests**

Append to `AgentBoardTests/GitHubWorkServiceTests.swift` (match the file's existing XCTest or Swift Testing style — shown here as XCTest; convert to `@Test` if the file uses Swift Testing):

```swift
func testResolvedGHPathPrefersHomebrewARM() {
    let path = GitHubWorkService.resolvedGHPath { $0 == "/opt/homebrew/bin/gh" }
    XCTAssertEqual(path, "/opt/homebrew/bin/gh")
}

func testResolvedGHPathFallsBackToIntelHomebrew() {
    let path = GitHubWorkService.resolvedGHPath { $0 == "/usr/local/bin/gh" }
    XCTAssertEqual(path, "/usr/local/bin/gh")
}

func testResolvedGHPathFallsBackToBareNameWhenAbsent() {
    let path = GitHubWorkService.resolvedGHPath { _ in false }
    XCTAssertEqual(path, "gh")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (on mac-mini or locally as fallback): the Global Constraints test command with `-only-testing:AgentBoardTests/GitHubWorkServiceTests`.
Expected: FAIL — `type 'GitHubWorkService' has no member 'resolvedGHPath'` (compile error counts as the failing state).

- [ ] **Step 3: Implement the resolver and use it**

In `AgentBoardCore/Services/GitHubWorkService.swift`, inside the `#if os(macOS)` block (near `fetchIssuesViaCLI`) add:

```swift
/// Probe known Homebrew locations for `gh`; mirror KanbanCLIWriter.resolveHermes().
static func resolvedGHPath(
    isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
) -> String {
    let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
    return candidates.first(where: isExecutable) ?? "gh"
}
```

Then in `fetchIssuesViaCLI`, replace:

```swift
result = try await Process.runAsync(
    executablePath: "/usr/local/bin/gh",
```

with:

```swift
result = try await Process.runAsync(
    executablePath: Self.resolvedGHPath(),
```

(If other call sites in the file use the hard-coded path — check with `grep -n '/usr/local/bin/gh' AgentBoardCore/Services/GitHubWorkService.swift` — replace them the same way.)

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: PASS (3 new tests green, no regressions in the class).

- [ ] **Step 5: Commit**

```bash
git add AgentBoardCore/Services/GitHubWorkService.swift AgentBoardTests/GitHubWorkServiceTests.swift
git commit -m "fix: resolve gh CLI path for Apple-silicon Homebrew"
```

---

### Task 2: Replace bootstrap `fatalError` with a no-op cache

`AgentBoardBootstrap.makeLiveAppModel()` crashes if both on-disk and in-memory SwiftData containers fail (`AgentBoardAppModel.swift:175`). Degrade to cache-less mode instead.

**Files:**
- Create: `AgentBoardCore/Persistence/NoopAgentBoardCache.swift`
- Modify: `AgentBoardCore/Stores/AgentBoardAppModel.swift` (the `AgentBoardBootstrap.makeLiveAppModel()` `do/catch`, ~lines 166–178)
- Test: `AgentBoardTests/NoopAgentBoardCacheTests.swift` (new)

**Interfaces:**
- Consumes: `AgentBoardCacheProtocol` (`AgentBoardCore/Persistence/AgentBoardCacheProtocol.swift:8`) — all four stores already accept this protocol.
- Produces: `@MainActor final class NoopAgentBoardCache: AgentBoardCacheProtocol` — every `load*` returns `[]`, every write is a silent no-op, nothing throws.

- [ ] **Step 1: Write the failing test**

Create `AgentBoardTests/NoopAgentBoardCacheTests.swift`:

```swift
import XCTest
@testable import AgentBoardCore

@MainActor
final class NoopAgentBoardCacheTests: XCTestCase {
    func testAllReadsReturnEmptyAndWritesDoNotThrow() throws {
        let cache = NoopAgentBoardCache()

        XCTAssertTrue(try cache.loadConversations().isEmpty)
        XCTAssertTrue(try cache.loadMessages(conversationID: UUID()).isEmpty)
        XCTAssertTrue(try cache.loadWorkItems().isEmpty)
        XCTAssertTrue(try cache.loadSessions().isEmpty)
        XCTAssertTrue(try cache.loadAgentSummaries().isEmpty)

        XCTAssertNoThrow(try cache.replaceWorkItems([]))
        XCTAssertNoThrow(try cache.replaceSessions([]))
        XCTAssertNoThrow(try cache.replaceAgentSummaries([]))
        XCTAssertNoThrow(try cache.deleteConversation(id: UUID()))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Global Constraints test command with `-only-testing:AgentBoardTests/NoopAgentBoardCacheTests`.
Expected: FAIL — `cannot find 'NoopAgentBoardCache' in scope`.

- [ ] **Step 3: Implement NoopAgentBoardCache**

Create `AgentBoardCore/Persistence/NoopAgentBoardCache.swift`:

```swift
import Foundation

/// Cache-less fallback used when SwiftData container creation fails even
/// in-memory. Reads return nothing; writes are dropped. Keeps the app
/// launchable instead of crashing in AgentBoardBootstrap.
@MainActor
public final class NoopAgentBoardCache: AgentBoardCacheProtocol {
    public init() {}

    public func loadConversations() throws -> [ChatConversation] { [] }
    public func loadMessages(conversationID: UUID) throws -> [ConversationMessage] { [] }
    public func saveConversationSnapshot(
        conversation: ChatConversation,
        messages: [ConversationMessage]
    ) throws {}
    public func deleteConversation(id: UUID) throws {}

    public func loadWorkItems() throws -> [WorkItem] { [] }
    public func replaceWorkItems(_ items: [WorkItem]) throws {}

    public func loadSessions() throws -> [AgentSession] { [] }
    public func replaceSessions(_ sessions: [AgentSession]) throws {}
    public func loadAgentSummaries() throws -> [AgentSummary] { [] }
    public func replaceAgentSummaries(_ agents: [AgentSummary]) throws {}
}
```

Run `xcodegen generate` so the new file joins the targets.

- [ ] **Step 4: Wire it into the bootstrap**

In `AgentBoardCore/Stores/AgentBoardAppModel.swift`, `AgentBoardBootstrap.makeLiveAppModel()`, replace:

```swift
let cache: AgentBoardCache

do {
    cache = try AgentBoardCache()
} catch {
    do {
        cache = try AgentBoardCache(inMemory: true)
    } catch {
        fatalError("Unable to create AgentBoard cache: \(error.localizedDescription)")
    }
}
```

with:

```swift
let cache: AgentBoardCacheProtocol

do {
    cache = try AgentBoardCache()
} catch {
    do {
        cache = try AgentBoardCache(inMemory: true)
    } catch {
        Logger(subsystem: "com.agentboard", category: "bootstrap")
            .fault("Cache unavailable, running cache-less: \(error.localizedDescription)")
        cache = NoopAgentBoardCache()
    }
}
```

Add `import OSLog` at the top of the file if not present. If any downstream `makeLiveAppModel` code requires the concrete `AgentBoardCache` type, the compiler will flag it — those sites should accept the protocol (they already do per the issue #108 DI cleanup).

- [ ] **Step 5: Run tests to verify they pass**

Global Constraints test command (full `AgentBoardTests`). Expected: PASS, including the new NoopAgentBoardCacheTests and no regressions.

- [ ] **Step 6: Commit**

```bash
git add AgentBoardCore/Persistence/NoopAgentBoardCache.swift AgentBoardCore/Stores/AgentBoardAppModel.swift AgentBoardTests/NoopAgentBoardCacheTests.swift AgentBoard.xcodeproj/project.pbxproj
git commit -m "fix: degrade to cache-less mode instead of fatalError in bootstrap"
```

---

### Task 3: Fix transport doc drift

Docs claim chat uses "WebSocket JSON-RPC"; the client is HTTP POST `/v1/chat/completions` + SSE streaming (`HermesGatewayClient.swift`).

**Files:**
- Modify: `README.md:16` and `README.md:109`
- Modify: `AGENTS.md:67`

**Interfaces:** none (docs only).

- [ ] **Step 1: Edit the three lines**

`README.md:16` — replace:
> **Hermes gateway** powers chat (WebSocket JSON-RPC) and is the write authority for kanban tasks via the `hermes kanban` CLI.

with:
> **Hermes gateway** powers chat (HTTP + SSE streaming via an OpenAI-compatible `/v1/chat/completions` endpoint) and is the write authority for kanban tasks via the `hermes kanban` CLI.

`README.md:109` — replace `Core -->|chat WebSocket| Hermes` with `Core -->|chat HTTP/SSE| Hermes`.

`AGENTS.md:67` — replace `- **Hermes gateway** powers chat (WebSocket JSON-RPC protocol)` with `- **Hermes gateway** powers chat (HTTP + SSE, OpenAI-compatible /v1/chat/completions)`.

- [ ] **Step 2: Verify no stale references remain**

Run: `grep -rn "WebSocket\|JSON-RPC" README.md AGENTS.md docs/architecture.md`
Expected: no chat-transport hits (Companion event-stream mentions, if any, are fine — only Hermes chat claims must change).

- [ ] **Step 3: Commit**

```bash
git add README.md AGENTS.md
git commit -m "docs: correct Hermes chat transport to HTTP + SSE"
```

---

### Task 4: Verification gate + PR

**Files:** none new.

- [ ] **Step 1: Build all three schemes**

```bash
xcodebuild build -scheme AgentBoard -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -scheme AgentBoardMobile -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild build -scheme AgentBoardCompanion -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```
Expected: `** BUILD SUCCEEDED **` × 3.

- [ ] **Step 2: SwiftLint strict**

Run: `swiftlint --strict`
Expected: no output (zero violations).

- [ ] **Step 3: Full unit suite on mac-mini**

Push the branch, then run the Global Constraints test command on mac-mini after `git pull` there. Expected: all ~390 tests pass.

- [ ] **Step 4: Open PR**

```bash
git push -u origin HEAD
gh pr create --repo jbcrane13/AgentBoard --title "fix: Phase 0 stabilization (gh path, crash-free bootstrap, doc drift)" --body "Implements Phase 0 of docs/superpowers/specs/2026-07-16-feature-complete-stability-design.md. Closes the Phase 0 tracking issue."
```

---

## Later Phases

Phases 1–4 (chat completion, agent-kanban parity, 3-column issues board, dashboard) are specced in `docs/superpowers/specs/2026-07-16-feature-complete-stability-design.md` and tracked as GitHub issues. Each gets its own plan document in `docs/superpowers/plans/` when picked up — Phase 1 must start with the two gateway spikes (capability parameters, history endpoint) because their outcomes shape the plan's tasks.
