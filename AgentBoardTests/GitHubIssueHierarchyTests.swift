@testable import AgentBoard
import Foundation
import Testing

struct GitHubIssueHierarchyTests {
    @Test("fetchIssues reconstructs parent-child relationships from epic metadata")
    func fetchIssuesReconstructsHierarchyFromEpicBody() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let issuesJSON = """
        [
          {
            "number": 37,
            "title": "GitHub-only migration",
            "body": "## Child issues\n- [ ] #38 Fix build blockers\n- [ ] #39 Normalize flows",
            "state": "open",
            "labels": [{"name": "epic"}],
            "assignees": [],
            "milestone": null,
            "created_at": "2026-03-01T00:00:00Z",
            "updated_at": "2026-03-04T00:00:00Z"
          },
          {
            "number": 38,
            "title": "Fix build blockers",
            "body": "Task body",
            "state": "open",
            "labels": [{"name": "task"}],
            "assignees": [],
            "milestone": null,
            "created_at": "2026-03-02T00:00:00Z",
            "updated_at": "2026-03-03T00:00:00Z"
          },
          {
            "number": 39,
            "title": "Normalize flows",
            "body": "Task body",
            "state": "closed",
            "labels": [{"name": "feature"}],
            "assignees": [],
            "milestone": null,
            "created_at": "2026-03-02T00:00:00Z",
            "updated_at": "2026-03-02T12:00:00Z"
          }
        ]
        """

        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            if url.query?.contains("page=1") == true {
                return (mockResponse(statusCode: 200, url: url), Data(issuesJSON.utf8))
            }
            return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
        }

        let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")

        let epic = try #require(beads.first { $0.id == "GH-37" })
        let child38 = try #require(beads.first { $0.id == "GH-38" })
        let child39 = try #require(beads.first { $0.id == "GH-39" })

        #expect(epic.kind == .epic)
        #expect(child38.parentIssueNumber == 37)
        #expect(child38.epicId == "GH-37")
        #expect(child39.parentIssueNumber == 37)
        #expect(child39.epicId == "GH-37")
        #expect(child39.status == .done)
    }

    @Test("childIssueNumbers parses canonical and legacy child issue sections")
    func childIssueNumbersParsesSupportedSections() {
        let childIssues = GitHubIssueHierarchy.childIssueNumbers(
            in: """
            ## Sub-issues
            - [ ] owner/repo#41 Follow up
            - GH-42 Another follow up

            ## Notes
            - ignore this
            """
        )

        #expect(childIssues == [41, 42])
    }
}
