# GitHub Issues Backend Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the JSONL/.beads file layer with a direct GitHub Issues API backend so AgentBoard reads issues live — no local file intermediary, no staleness.

**Architecture:** A new `GitHubIssuesService` actor handles all GitHub API calls (fetch, create, update, close) with pagination and URLProtocol-mockable URLSession. `ConfiguredProject` gains `githubOwner`/`githubRepo` optional fields persisted in `~/.agentboard/config.json`. `AppState` conditionally routes issue loading/mutation through `GitHubIssuesService` when those fields are set, falling back to the existing JSONL/CLI path if not. A new Settings section lets users configure the shared GitHub token and per-project owner/repo.

**Tech Stack:** Swift 6 + Swift Testing, URLSession, macOS 15+. No new package dependencies.

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `AgentBoard/Models/AppConfig.swift` | Add `githubOwner`/`githubRepo` to `ConfiguredProject`; add `githubToken` to `AppConfig` |
| Create | `AgentBoard/Services/GitHubIssuesService.swift` | Actor: fetch/create/update/close issues via GH REST API |
| Modify | `AgentBoard/App/AppState.swift` | Wire GH service; route bead load through it when configured; expose sync state |
| Modify | `AgentBoard/Views/Settings/SettingsView.swift` | Add GitHub section: shared token + per-project owner/repo + sync status |
| Create | `AgentBoardTests/GitHubIssuesServiceTests.swift` | URLProtocol-mock tests: JSON→Bead mapping, pagination, error cases, mutations |
| Modify | `AgentBoardTests/AppConfigStoreTests.swift` | Round-trip tests for new `githubOwner`/`githubRepo` fields |

---

## Task 1: Extend ConfiguredProject and AppConfig

**Files:**
- Modify: `AgentBoard/Models/AppConfig.swift`

- [ ] **Step 1: Add fields to ConfiguredProject and AppConfig**

Open `AgentBoard/Models/AppConfig.swift`. Replace the entire file with:

```swift
import Foundation

struct AppConfig: Codable, Sendable {
    var projects: [ConfiguredProject]
    var selectedProjectPath: String?
    var openClawGatewayURL: String?
    var openClawToken: String?
    /// "auto" = re-read from openclaw.json every launch; "manual" = user-entered, don't overwrite
    var gatewayConfigSource: String?
    /// Root directory for auto-discovering projects with .beads/ folders. Defaults to ~/Projects.
    var projectsDirectory: String?
    /// Show detailed tool/subagent output in chat. Default: false (suppressed)
    var showToolOutputInChat: Bool?
    /// Shared GitHub API token for loading issues from GitHub Issues API.
    /// Stored in JSON (same pattern as openClawToken). Optional — JSONL fallback used if nil.
    var githubToken: String?

    var isGatewayManual: Bool {
        gatewayConfigSource == "manual"
    }

    var resolvedProjectsDirectory: URL {
        if let dir = projectsDirectory, !dir.isEmpty {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Projects", isDirectory: true)
    }

    static let empty = AppConfig(
        projects: [],
        selectedProjectPath: nil,
        openClawGatewayURL: nil,
        openClawToken: nil,
        gatewayConfigSource: "auto",
        projectsDirectory: nil,
        showToolOutputInChat: nil,
        githubToken: nil
    )
}

struct ConfiguredProject: Codable, Hashable, Identifiable, Sendable {
    let path: String
    var icon: String
    /// GitHub owner (user or org) for GitHub Issues integration.
    var githubOwner: String?
    /// GitHub repository name for GitHub Issues integration.
    var githubRepo: String?

    var id: String { path }
}
```

- [ ] **Step 2: Verify build compiles cleanly**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Add round-trip tests for new fields**

In `AgentBoardTests/AppConfigStoreTests.swift`, append at the end of the `AppConfigStoreLifecycleTests` struct (inside its closing `}`):

```swift
@Test("ConfiguredProject githubOwner/githubRepo round-trips through JSON")
func configuredProjectGitHubFieldsRoundTrip() throws {
    let (store, dir, _) = try makeTempStore()
    defer { try? fm.removeItem(at: dir) }

    var project = ConfiguredProject(path: "/tmp/gh-proj", icon: "📁")
    project.githubOwner = "acme"
    project.githubRepo = "widget"

    let config = AppConfig(
        projects: [project],
        selectedProjectPath: "/tmp/gh-proj",
        openClawGatewayURL: nil,
        openClawToken: nil,
        gatewayConfigSource: "manual",
        projectsDirectory: nil,
        showToolOutputInChat: nil,
        githubToken: nil
    )
    try store.save(config)

    let loaded = try AppConfigStore(directory: dir).loadOrCreate()
    let loadedProject = try #require(loaded.projects.first)
    #expect(loadedProject.githubOwner == "acme")
    #expect(loadedProject.githubRepo == "widget")
}

@Test("AppConfig githubToken round-trips through JSON")
func appConfigGitHubTokenRoundTrip() throws {
    let (store, dir, _) = try makeTempStore()
    defer { try? fm.removeItem(at: dir) }

    let config = AppConfig(
        projects: [],
        selectedProjectPath: nil,
        openClawGatewayURL: nil,
        openClawToken: nil,
        gatewayConfigSource: "manual",
        projectsDirectory: nil,
        showToolOutputInChat: nil,
        githubToken: "ghp_test_token_xyz"
    )
    try store.save(config)

    let loaded = try AppConfigStore(directory: dir).loadOrCreate()
    #expect(loaded.githubToken == "ghp_test_token_xyz")
}
```

- [ ] **Step 4: Run new tests to confirm green**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:AgentBoardTests/AppConfigStoreTests 2>&1 | grep -E '(PASS|FAIL|error:|Executed)'"
```

Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
cd ~/Projects/AgentBoard && git add AgentBoard/Models/AppConfig.swift AgentBoardTests/AppConfigStoreTests.swift
git commit -m "feat: add githubOwner/githubRepo to ConfiguredProject and githubToken to AppConfig"
```

---

## Task 2: Create GitHubIssuesService

**Files:**
- Create: `AgentBoard/Services/GitHubIssuesService.swift`

- [ ] **Step 1: Create the file**

Create `AgentBoard/Services/GitHubIssuesService.swift`:

```swift
import Foundation

// MARK: - Error Types

enum GitHubError: LocalizedError, Sendable {
    case unauthorized           // 401
    case notFound               // 404
    case rateLimited            // 403
    case serverError(Int)       // 5xx
    case invalidResponse
    case missingConfig

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "GitHub token is invalid or missing."
        case .notFound: return "GitHub repository not found."
        case .rateLimited: return "GitHub API rate limit exceeded. Try again later."
        case .serverError(let code): return "GitHub server error (\(code))."
        case .invalidResponse: return "Unexpected response from GitHub API."
        case .missingConfig: return "GitHub owner/repo not configured for this project."
        }
    }
}

// MARK: - Raw GitHub Issue (Decodable from API)

private struct GitHubIssue: Decodable, Sendable {
    let number: Int
    let title: String
    let body: String?
    let state: String   // "open" | "closed"
    let labels: [GitHubLabel]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case number, title, body, state, labels
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct GitHubLabel: Decodable, Sendable {
    let name: String
}

// MARK: - GitHubIssuesService

/// Fetches and mutates GitHub Issues for a project, mapping them to the Bead model.
/// Inject a custom URLSession in tests via URLProtocol mock.
actor GitHubIssuesService {

    private let session: URLSession
    private let baseURL = "https://api.github.com"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Fetch All Issues

    /// Fetches all open and closed issues with pagination.
    func fetchIssues(owner: String, repo: String, token: String) async throws -> [Bead] {
        var allIssues: [GitHubIssue] = []
        var page = 1

        while true {
            let url = try buildURL(owner: owner, repo: repo, endpoint: "issues",
                                   queryItems: [
                                       URLQueryItem(name: "state", value: "all"),
                                       URLQueryItem(name: "per_page", value: "100"),
                                       URLQueryItem(name: "page", value: "\(page)")
                                   ])
            let (data, response) = try await session.data(for: authorizedRequest(url: url, token: token))
            try validateResponse(response, data: data)

            let issues = try JSONDecoder().decode([GitHubIssue].self, from: data)
            if issues.isEmpty { break }
            allIssues.append(contentsOf: issues)
            if issues.count < 100 { break }
            page += 1
        }

        return allIssues.map { mapToBead($0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Create Issue

    func createIssue(owner: String, repo: String, token: String,
                     title: String, body: String?, labels: [String]) async throws -> Bead {
        let url = try buildURL(owner: owner, repo: repo, endpoint: "issues")
        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = ["title": title]
        if let body { payload["body"] = body }
        if !labels.isEmpty { payload["labels"] = labels }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return mapToBead(try JSONDecoder().decode(GitHubIssue.self, from: data))
    }

    // MARK: - Update Issue

    func updateIssue(owner: String, repo: String, token: String,
                     number: Int, title: String?, body: String?, state: String?) async throws -> Bead {
        let url = try buildURL(owner: owner, repo: repo, endpoint: "issues/\(number)")
        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]
        if let title { payload["title"] = title }
        if let body { payload["body"] = body }
        if let state { payload["state"] = state }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return mapToBead(try JSONDecoder().decode(GitHubIssue.self, from: data))
    }

    // MARK: - Close Issue

    func closeIssue(owner: String, repo: String, token: String, number: Int) async throws {
        _ = try await updateIssue(owner: owner, repo: repo, token: token,
                                  number: number, title: nil, body: nil, state: "closed")
    }

    // MARK: - Helpers

    private func buildURL(owner: String, repo: String, endpoint: String,
                          queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents(string: "\(baseURL)/repos/\(owner)/\(repo)/\(endpoint)")!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw GitHubError.invalidResponse }
        return url
    }

    private func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        switch http.statusCode {
        case 200...299: return
        case 401: throw GitHubError.unauthorized
        case 403: throw GitHubError.rateLimited
        case 404: throw GitHubError.notFound
        case 500...599: throw GitHubError.serverError(http.statusCode)
        default: throw GitHubError.serverError(http.statusCode)
        }
    }

    // MARK: - GH Issue → Bead Mapping

    private func mapToBead(_ issue: GitHubIssue) -> Bead {
        let labelNames = issue.labels.map(\.name)

        let kind: BeadKind = {
            for label in labelNames {
                switch label.lowercased() {
                case "bug": return .bug
                case "feature", "enhancement": return .feature
                case "epic": return .epic
                case "chore": return .chore
                default: continue
                }
            }
            return .task
        }()

        let priority: Int = {
            for label in labelNames {
                let lower = label.lowercased()
                if lower == "priority:critical" || lower == "p0" { return 0 }
                if lower == "priority:high"     || lower == "p1" { return 1 }
                if lower == "priority:medium"   || lower == "p2" { return 2 }
                if lower == "priority:low"      || lower == "p3" { return 3 }
                if lower == "priority:backlog"  || lower == "p4" { return 4 }
            }
            return 2
        }()

        let status: BeadStatus = issue.state == "closed" ? .done : .open

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        func parseDate(_ raw: String) -> Date {
            withFractional.date(from: raw) ?? withoutFractional.date(from: raw) ?? .distantPast
        }

        return Bead(
            id: "GH-\(issue.number)",
            title: issue.title,
            body: issue.body,
            status: status,
            kind: kind,
            priority: priority,
            epicId: nil,
            labels: labelNames,
            assignee: nil,
            createdAt: parseDate(issue.createdAt),
            updatedAt: parseDate(issue.updatedAt),
            dependencies: [],
            gitBranch: nil,
            lastCommit: nil
        )
    }

    /// Parse "GH-123" → 123. Returns nil if not a GH issue ID.
    static func issueNumber(from beadID: String) -> Int? {
        guard beadID.hasPrefix("GH-"),
              let number = Int(beadID.dropFirst(3)) else { return nil }
        return number
    }
}
```

- [ ] **Step 2: Verify build**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd ~/Projects/AgentBoard && git add AgentBoard/Services/GitHubIssuesService.swift
git commit -m "feat: add GitHubIssuesService actor with pagination, GH→Bead mapping, and typed errors"
```

---

## Task 3: Tests for GitHubIssuesService

**Files:**
- Create: `AgentBoardTests/GitHubIssuesServiceTests.swift`

We use `URLProtocol` to intercept URLSession requests without making real network calls.

**Note on `@unchecked Sendable`:** `MockURLProtocol` uses a static `requestHandler` property that is set per-test from the main thread. Each test is run serially by Swift Testing's default executor. This is the same pattern used by `GatewayClient.swift`'s `JSONPayload` and `GatewayEvent` (which also carry `@unchecked Sendable` per ADR-008). The `@unchecked Sendable` here is intentional and safe because tests are serially isolated.

- [ ] **Step 1: Create test file**

Create `AgentBoardTests/GitHubIssuesServiceTests.swift`:

```swift
import Foundation
import Testing
@testable import AgentBoard

// MARK: - URLProtocol Mock
// @unchecked Sendable is intentional: requestHandler is set from the same thread that
// drives each test, and Swift Testing runs @Test functions serially by default.
// This follows the same pattern as JSONPayload/GatewayEvent in GatewayClient.swift.

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError:
                NSError(domain: "MockURLProtocol", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No handler set"]))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helpers

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func mockResponse(statusCode: Int, url: URL) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

private let sampleOpenIssueJSON = """
[
  {
    "number": 42,
    "title": "Fix the widget",
    "body": "The widget is broken.",
    "state": "open",
    "labels": [{"name": "bug"}, {"name": "priority:high"}],
    "created_at": "2026-01-01T10:00:00Z",
    "updated_at": "2026-01-02T12:00:00Z"
  }
]
"""

private let sampleClosedIssueJSON = """
[
  {
    "number": 99,
    "title": "Add dark mode",
    "body": null,
    "state": "closed",
    "labels": [{"name": "feature"}],
    "created_at": "2025-12-01T00:00:00Z",
    "updated_at": "2025-12-15T00:00:00Z"
  }
]
"""

private func singleIssueJSON(number: Int, title: String, state: String = "open",
                              labelName: String) -> String {
    """
    [{"number":\(number),"title":"\(title)","body":null,"state":"\(state)",
      "labels":[{"name":"\(labelName)"}],
      "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]
    """
}

// MARK: - Tests

@Suite("GitHubIssuesService Tests")
struct GitHubIssuesServiceTests {

    // MARK: - JSON→Bead Mapping

    @Test("fetchIssues maps open GH issue to Bead with correct fields")
    func fetchIssuesMapsOpenIssue() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            if url.query?.contains("page=1") == true {
                return (mockResponse(statusCode: 200, url: url),
                        sampleOpenIssueJSON.data(using: .utf8)!)
            }
            return (mockResponse(statusCode: 200, url: url), "[]".data(using: .utf8)!)
        }

        let beads = try await service.fetchIssues(owner: "acme", repo: "widget", token: "tok")

        #expect(beads.count == 1)
        let bead = try #require(beads.first)
        #expect(bead.id == "GH-42")
        #expect(bead.title == "Fix the widget")
        #expect(bead.body == "The widget is broken.")
        #expect(bead.status == .open)
        #expect(bead.kind == .bug)
        #expect(bead.priority == 1)  // priority:high → 1
        #expect(bead.labels.contains("bug"))
        #expect(bead.labels.contains("priority:high"))
    }

    @Test("fetchIssues maps closed GH issue to done status")
    func fetchIssuesMapsClosedIssueToDone() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            if url.query?.contains("page=1") == true {
                return (mockResponse(statusCode: 200, url: url),
                        sampleClosedIssueJSON.data(using: .utf8)!)
            }
            return (mockResponse(statusCode: 200, url: url), "[]".data(using: .utf8)!)
        }

        let beads = try await service.fetchIssues(owner: "acme", repo: "widget", token: "tok")

        #expect(beads.count == 1)
        let bead = try #require(beads.first)
        #expect(bead.id == "GH-99")
        #expect(bead.status == .done)
        #expect(bead.kind == .feature)
        #expect(bead.priority == 2)  // no priority label → default medium
        #expect(bead.body == nil)
    }

    @Test("fetchIssues maps priority labels correctly")
    func fetchIssuesMapesPriorityLabels() async throws {
        let cases: [(String, Int)] = [
            ("priority:critical", 0), ("p0", 0),
            ("priority:high", 1), ("p1", 1),
            ("priority:medium", 2), ("p2", 2),
            ("priority:low", 3), ("p3", 3),
            ("priority:backlog", 4), ("p4", 4)
        ]
        for (labelName, expectedPriority) in cases {
            let json = singleIssueJSON(number: 1, title: "T", labelName: labelName)
            let session = makeMockSession()
            let service = GitHubIssuesService(session: session)
            MockURLProtocol.requestHandler = { req in
                let url = req.url!
                if url.query?.contains("page=1") == true {
                    return (mockResponse(statusCode: 200, url: url), json.data(using: .utf8)!)
                }
                return (mockResponse(statusCode: 200, url: url), "[]".data(using: .utf8)!)
            }
            let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
            let bead = try #require(beads.first)
            #expect(bead.priority == expectedPriority,
                    "Label '\(labelName)' should map to priority \(expectedPriority), got \(bead.priority)")
        }
    }

    // MARK: - Pagination

    @Test("fetchIssues fetches multiple pages when first page is full (100 items)")
    func fetchIssuesPaginates() async throws {
        func makeIssues(start: Int, count: Int) -> String {
            let items = (start..<(start + count)).map { n in
                """
                {"number":\(n),"title":"Issue \(n)","body":null,"state":"open",
                 "labels":[],"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
                """
            }.joined(separator: ",")
            return "[\(items)]"
        }

        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)
        nonisolated(unsafe) var callCount = 0

        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            callCount += 1
            if url.query?.contains("page=1") == true {
                return (mockResponse(statusCode: 200, url: url),
                        makeIssues(start: 1, count: 100).data(using: .utf8)!)
            } else if url.query?.contains("page=2") == true {
                return (mockResponse(statusCode: 200, url: url),
                        makeIssues(start: 101, count: 1).data(using: .utf8)!)
            }
            return (mockResponse(statusCode: 200, url: url), "[]".data(using: .utf8)!)
        }

        let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
        #expect(beads.count == 101)
        #expect(callCount == 3)  // page1=100 items, page2=1 item, page3=empty → stop
    }

    // MARK: - Error Cases

    @Test("fetchIssues throws unauthorized on 401")
    func fetchIssuesThrowsOn401() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)
        MockURLProtocol.requestHandler = { req in
            (mockResponse(statusCode: 401, url: req.url!), Data())
        }
        await #expect(throws: GitHubError.self) {
            _ = try await service.fetchIssues(owner: "o", repo: "r", token: "bad")
        }
    }

    @Test("fetchIssues throws notFound on 404")
    func fetchIssuesThrowsOn404() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)
        MockURLProtocol.requestHandler = { req in
            (mockResponse(statusCode: 404, url: req.url!), Data())
        }
        await #expect(throws: GitHubError.self) {
            _ = try await service.fetchIssues(owner: "missing", repo: "repo", token: "t")
        }
    }

    @Test("fetchIssues throws rateLimited on 403")
    func fetchIssuesThrowsOn403() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)
        MockURLProtocol.requestHandler = { req in
            (mockResponse(statusCode: 403, url: req.url!), Data())
        }
        await #expect(throws: GitHubError.self) {
            _ = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
        }
    }

    // MARK: - createIssue

    @Test("createIssue sends POST and returns mapped Bead")
    func createIssueSendsPOSTAndReturnsBead() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let createdIssueJSON = """
        {"number":77,"title":"New issue","body":"Description here","state":"open",
         "labels":[{"name":"feature"}],
         "created_at":"2026-03-01T00:00:00Z","updated_at":"2026-03-01T00:00:00Z"}
        """

        nonisolated(unsafe) var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            return (mockResponse(statusCode: 201, url: req.url!),
                    createdIssueJSON.data(using: .utf8)!)
        }

        let bead = try await service.createIssue(
            owner: "o", repo: "r", token: "t",
            title: "New issue", body: "Description here", labels: ["feature"]
        )

        #expect(capturedMethod == "POST")
        #expect(bead.id == "GH-77")
        #expect(bead.title == "New issue")
        #expect(bead.kind == .feature)
        #expect(bead.status == .open)
    }

    // MARK: - updateIssue

    @Test("updateIssue sends PATCH and returns mapped Bead")
    func updateIssueSendsPATCHAndReturnsBead() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let updatedIssueJSON = """
        {"number":42,"title":"Updated title","body":"Updated body","state":"closed",
         "labels":[{"name":"bug"}],
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-03-17T00:00:00Z"}
        """

        nonisolated(unsafe) var capturedMethod: String?
        MockURLProtocol.requestHandler = { req in
            capturedMethod = req.httpMethod
            return (mockResponse(statusCode: 200, url: req.url!),
                    updatedIssueJSON.data(using: .utf8)!)
        }

        let bead = try await service.updateIssue(
            owner: "o", repo: "r", token: "t",
            number: 42, title: "Updated title", body: "Updated body", state: "closed"
        )

        #expect(capturedMethod == "PATCH")
        #expect(bead.id == "GH-42")
        #expect(bead.status == .done)
        #expect(bead.title == "Updated title")
    }

    // MARK: - issueNumber helper

    @Test("issueNumber parses GH-N correctly")
    func issueNumberParses() {
        #expect(GitHubIssuesService.issueNumber(from: "GH-42") == 42)
        #expect(GitHubIssuesService.issueNumber(from: "GH-1") == 1)
        #expect(GitHubIssuesService.issueNumber(from: "AB-42") == nil)
        #expect(GitHubIssuesService.issueNumber(from: "GH-abc") == nil)
        #expect(GitHubIssuesService.issueNumber(from: "") == nil)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:AgentBoardTests/GitHubIssuesServiceTests 2>&1 | grep -E '(PASS|FAIL|error:|Executed)'"
```

Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
cd ~/Projects/AgentBoard && git add AgentBoardTests/GitHubIssuesServiceTests.swift
git commit -m "test: add GitHubIssuesService tests — mapping, pagination, errors, create/update"
```

---

## Task 4: Wire AppState to Use GitHubIssuesService

**Files:**
- Modify: `AgentBoard/App/AppState.swift`

When the selected project has `githubOwner` + `githubRepo` in its `ConfiguredProject` AND `appConfig.githubToken` is set, use `GitHubIssuesService`. Otherwise fall back to existing JSONL/CLI path.

- [ ] **Step 1: Add GitHubIssuesService instance and observable sync state to AppState**

In `AppState.swift`, find the line:
```swift
private let gitService = GitService()
```
Add after it:
```swift
private let gitHubService = GitHubIssuesService()
private var githubPollingTask: Task<Void, Never>?
```

In the published state section (near `var beadsFileMissing = false`), add:
```swift
var lastGitHubSyncDate: Date?
var githubIssueCount: Int = 0
```

- [ ] **Step 2: Add githubConfig computed property**

After the `var activeSession: CodingSession?` computed property, add:

```swift
/// Returns (owner, repo, token) if the selected project has GitHub configured.
private var githubConfig: (owner: String, repo: String, token: String)? {
    guard let project = selectedProject,
          let configured = appConfig.projects.first(where: { $0.path == project.path.path }),
          let owner = configured.githubOwner, !owner.isEmpty,
          let repo = configured.githubRepo, !repo.isEmpty,
          let token = appConfig.githubToken, !token.isEmpty
    else { return nil }
    return (owner, repo, token)
}
```

- [ ] **Step 3: Add loadBeadsFromGitHub method**

Add after the `loadBeads(for:)` method:

```swift
private func loadBeadsFromGitHub(owner: String, repo: String, token: String) async {
    guard !isLoadingBeads else { return }
    isLoadingBeads = true
    defer { isLoadingBeads = false }

    do {
        let fetched = try await gitHubService.fetchIssues(owner: owner, repo: repo, token: token)
        beads = fetched
        beadsFileMissing = false
        githubIssueCount = fetched.count
        lastGitHubSyncDate = Date()
        selectedBeadID = selectedBeadID.flatMap { existingID in
            beads.contains(where: { $0.id == existingID }) ? existingID : nil
        }
        refreshProjectCounts()
        rebuildHistoryEvents()
    } catch {
        setError("GitHub sync failed: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 4: Add GitHub polling methods**

Match the pattern of the existing `startAutoRefresh`:

```swift
private func startGitHubPolling() {
    stopGitHubPolling()
    githubPollingTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard let self, !Task.isCancelled else { break }
            guard let (owner, repo, token) = await self.githubConfig else { break }
            await self.loadBeadsFromGitHub(owner: owner, repo: repo, token: token)
        }
    }
}

private func stopGitHubPolling() {
    githubPollingTask?.cancel()
    githubPollingTask = nil
}
```

- [ ] **Step 5: Update reloadSelectedProjectAndWatch to branch on GH config**

Replace the body of `private func reloadSelectedProjectAndWatch()` with:

```swift
private func reloadSelectedProjectAndWatch() {
    guard let selectedProject else {
        beads = []
        beadsFileMissing = false
        beadGitSummaries = [:]
        recentGitCommits = []
        currentGitBranch = nil
        historyEvents = []
        watcher.stop()
        watchedFilePath = nil
        stopGitHubPolling()
        return
    }

    let project = selectedProject

    if let (owner, repo, token) = githubConfig {
        // GitHub backend: fetch live, then start 60s polling
        stopGitHubPolling()
        Task { @MainActor in
            await loadBeadsFromGitHub(owner: owner, repo: repo, token: token)
            await refreshGitContext(for: project)
        }
        startGitHubPolling()
    } else {
        // JSONL/CLI backend (existing path)
        stopGitHubPolling()
        loadBeads(for: project)
        watch(project: project)
        Task { @MainActor in
            await refreshBeadsFromCLI(for: project)
            await refreshGitContext(for: project)
        }
        // Attempt to auto-detect GH config from bd — will re-trigger reload if found
        Task { @MainActor in
            await autoDetectGitHubConfig(for: project)
        }
    }
}
```

- [ ] **Step 6: Override refreshBeads() to route to GH when applicable**

Find `func refreshBeads()` and replace its body:

```swift
func refreshBeads() async {
    if let (owner, repo, token) = githubConfig {
        await loadBeadsFromGitHub(owner: owner, repo: repo, token: token)
    } else {
        guard let project = selectedProject else { return }
        await refreshBeadsFromCLI(for: project)
    }
}
```

- [ ] **Step 7: Add updateGitHubConfig method (called from Settings UI)**

```swift
func updateGitHubConfig(owner: String?, repo: String?, token: String?) {
    guard let project = selectedProject else { return }

    if let index = appConfig.projects.firstIndex(where: { $0.path == project.path.path }) {
        let trimmedOwner = owner?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRepo = repo?.trimmingCharacters(in: .whitespacesAndNewlines)
        appConfig.projects[index].githubOwner = trimmedOwner?.isEmpty == true ? nil : trimmedOwner
        appConfig.projects[index].githubRepo = trimmedRepo?.isEmpty == true ? nil : trimmedRepo
    }

    let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
    appConfig.githubToken = trimmedToken?.isEmpty == true ? nil : trimmedToken

    persistConfig()
    statusMessage = "GitHub config saved."
    reloadSelectedProjectAndWatch()
}
```

- [ ] **Step 8: Add autoDetectGitHubConfig method**

```swift
/// Reads github.owner and github.repo from bd config if not already set for this project.
/// Only auto-detects once — if owner or repo is already set, this is a no-op.
private func autoDetectGitHubConfig(for project: Project) async {
    guard let index = appConfig.projects.firstIndex(where: { $0.path == project.path.path }) else { return }
    let configured = appConfig.projects[index]

    // Skip if already configured
    guard configured.githubOwner == nil || configured.githubRepo == nil else { return }
    guard project.isBeadsInitialized else { return }

    let ownerResult = try? await runBD(arguments: ["bd", "config", "get", "github.owner"], in: project)
    let repoResult = try? await runBD(arguments: ["bd", "config", "get", "github.repo"], in: project)

    let owner = ownerResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    let repo = repoResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let owner, !owner.isEmpty, let repo, !repo.isEmpty else { return }

    // Persist detected values and reload (only if token is also available)
    appConfig.projects[index].githubOwner = owner
    appConfig.projects[index].githubRepo = repo
    persistConfig()
    statusMessage = "Detected GitHub config: \(owner)/\(repo)"

    // Reload only if we now have a full config (token was already set)
    if appConfig.githubToken != nil {
        reloadSelectedProjectAndWatch()
    }
}
```

- [ ] **Step 9: Build verify**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 10: Run full test suite**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E '(PASS|FAIL|error:|Executed)'"
```

Expected: All existing tests pass

- [ ] **Step 11: Commit**

```bash
cd ~/Projects/AgentBoard && git add AgentBoard/App/AppState.swift
git commit -m "feat: wire AppState to route issues through GitHubIssuesService when GH config is present"
```

---

## Task 5: Settings UI — GitHub Section

**Files:**
- Modify: `AgentBoard/Views/Settings/SettingsView.swift`

Add a "GitHub Issues" section after the "Chat" section. Shows: shared API token, per-project owner + repo fields, sync status (last synced + issue count), and a "Sync Now" button.

- [ ] **Step 1: Add @State vars for GitHub fields**

In `SettingsView`, after `@State private var showToolOutput = false`, add:

```swift
@State private var githubToken = ""
@State private var githubOwner = ""
@State private var githubRepo = ""
```

- [ ] **Step 2: Add GitHub section to body**

In the `VStack` inside `ScrollView`, add after the Chat `Toggle`:

```swift
sectionTitle("GitHub Issues")

VStack(alignment: .leading, spacing: 12) {
    Text("Connect a GitHub repository to load issues live from GitHub instead of the local .beads/issues.jsonl file.")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)

    VStack(alignment: .leading, spacing: 4) {
        Text("GitHub Token")
            .font(.system(size: 12, weight: .medium))
        SecureField("ghp_…", text: $githubToken)
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("settings_textfield_github_token")
    }

    if appState.selectedProject != nil {
        Divider()

        Text("Project: \(appState.selectedProject?.name ?? "")")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)

        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Owner")
                    .font(.system(size: 11, weight: .medium))
                TextField("github-user-or-org", text: $githubOwner)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings_textfield_github_owner")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Repository")
                    .font(.system(size: 11, weight: .medium))
                TextField("repo-name", text: $githubRepo)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings_textfield_github_repo")
            }
        }

        HStack(spacing: 8) {
            if let syncDate = appState.lastGitHubSyncDate {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last synced: \(syncDate.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(appState.githubIssueCount) issues")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Not yet synced")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Sync Now") {
                Task { await appState.refreshBeads() }
            }
            .disabled(appState.isLoadingBeads)
            .accessibilityIdentifier("settings_button_github_sync")
        }
    }

    Button("Save GitHub Settings") {
        saveGitHubSettings()
    }
    .accessibilityIdentifier("settings_button_github_save")
}
```

- [ ] **Step 3: Add saveGitHubSettings helper**

In the `// MARK: - Helpers` section:

```swift
private func saveGitHubSettings() {
    appState.updateGitHubConfig(
        owner: githubOwner.isEmpty ? nil : githubOwner,
        repo: githubRepo.isEmpty ? nil : githubRepo,
        token: githubToken.isEmpty ? nil : githubToken
    )
}
```

- [ ] **Step 4: Populate GitHub fields in onAppear and on project change**

In `.onAppear { }`, add after existing assignments:

```swift
githubToken = appState.appConfig.githubToken ?? ""
refreshGitHubFields()
```

Add private helper in `SettingsView`:

```swift
private func refreshGitHubFields() {
    if let project = appState.selectedProject,
       let configured = appState.appConfig.projects.first(where: { $0.path == project.path.path }) {
        githubOwner = configured.githubOwner ?? ""
        githubRepo = configured.githubRepo ?? ""
    } else {
        githubOwner = ""
        githubRepo = ""
    }
}
```

After the `.onAppear` modifier, add:

```swift
.onChange(of: appState.selectedProjectID) { _, _ in
    refreshGitHubFields()
}
```

- [ ] **Step 5: Build verify**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Run full test suite**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E '(PASS|FAIL|error:|Executed)'"
```

Expected: All tests pass

- [ ] **Step 7: Commit and push**

```bash
cd ~/Projects/AgentBoard && git add AgentBoard/Views/Settings/SettingsView.swift
git commit -m "feat: add GitHub Issues settings section with token, per-project owner/repo, sync status"
git push
git status  # Must show: "Your branch is up to date with 'origin/main'"
```

---

## Task 6: Close Bead and Session Close Protocol

- [ ] **Step 1: Close the tracking bead**

```bash
cd ~/Projects/AgentBoard && bd close AB-8hl --reason "Native GH Issues backend built — GitHubIssuesService actor, ConfiguredProject GH fields, AppState routing, Settings UI, auto-detect from bd config"
```

- [ ] **Step 2: Final build and test verification**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10"
```

Expected: All tests pass

- [ ] **Step 3: Send completion event**

```bash
openclaw system event --text "Done: AgentBoard native GitHub Issues backend built" --mode now
```
