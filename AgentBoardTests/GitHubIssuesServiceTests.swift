@testable import AgentBoard
import Foundation
import Testing

// MARK: - URLProtocol Mock

// @unchecked Sendable is intentional: requestHandler is set from the same thread that
// drives each test, and Swift Testing runs @Test functions serially by default.
// This follows the same pattern as JSONPayload/GatewayEvent in GatewayClient.swift.

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError:
                NSError(
                    domain: "MockURLProtocol",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No handler set"]
                )
            )
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

private func singleIssueJSON(
    number: Int,
    title: String,
    state: String = "open",
    labelName: String
) -> String {
    """
    [{"number":\(number),"title":"\(title)","body":null,"state":"\(state)",
      "labels":[{"name":"\(labelName)"}],
      "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]
    """
}

// MARK: - Tests

struct GitHubIssuesServiceTests {
    // MARK: - JSON→Bead Mapping

    @Test("fetchIssues maps open GH issue to Bead with correct fields")
    func fetchIssuesMapsOpenIssue() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            if url.query?.contains("page=1") == true {
                return (
                    mockResponse(statusCode: 200, url: url),
                    Data(sampleOpenIssueJSON.utf8)
                )
            }
            return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
        }

        let beads = try await service.fetchIssues(owner: "acme", repo: "widget", token: "tok")

        #expect(beads.count == 1)
        let bead = try #require(beads.first)
        #expect(bead.id == "GH-42")
        #expect(bead.title == "Fix the widget")
        #expect(bead.body == "The widget is broken.")
        #expect(bead.status == .open)
        #expect(bead.kind == .bug)
        #expect(bead.priority == 1) // priority:high → 1
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
                return (
                    mockResponse(statusCode: 200, url: url),
                    Data(sampleClosedIssueJSON.utf8)
                )
            }
            return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
        }

        let beads = try await service.fetchIssues(owner: "acme", repo: "widget", token: "tok")

        #expect(beads.count == 1)
        let bead = try #require(beads.first)
        #expect(bead.id == "GH-99")
        #expect(bead.status == .done)
        #expect(bead.kind == .feature)
        #expect(bead.priority == 2) // no priority label → default medium
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
                    return (mockResponse(statusCode: 200, url: url), Data(json.utf8))
                }
                return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
            }
            let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
            let bead = try #require(beads.first)
            #expect(
                bead.priority == expectedPriority,
                "Label '\(labelName)' should map to priority \(expectedPriority), got \(bead.priority)"
            )
        }
    }

    // MARK: - Pagination

    @Test("fetchIssues fetches multiple pages when first page is full (100 items)")
    func fetchIssuesPaginates() async throws {
        func makeIssues(start: Int, count: Int) -> String {
            let items = (start ..< (start + count)).map { n in
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
                return (
                    mockResponse(statusCode: 200, url: url),
                    Data(makeIssues(start: 1, count: 100).utf8)
                )
            } else if url.query?.contains("page=2") == true {
                return (
                    mockResponse(statusCode: 200, url: url),
                    Data(makeIssues(start: 101, count: 1).utf8)
                )
            }
            return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
        }

        let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
        #expect(beads.count == 101)
        #expect(callCount == 3) // page1=100 items, page2=1 item, page3=empty → stop
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
            return (
                mockResponse(statusCode: 201, url: req.url!),
                Data(createdIssueJSON.utf8)
            )
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
            return (
                mockResponse(statusCode: 200, url: req.url!),
                Data(updatedIssueJSON.utf8)
            )
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
