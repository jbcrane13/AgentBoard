import AgentBoardCore
import Foundation
import Testing

@Suite(.serialized)
struct GitHubWorkServiceTests {
    @Test
    func fetchWorkItemsMapsLabelsAndFiltersPullRequests() async throws {
        let service = GitHubWorkService(session: makeMockSession { request in
            #expect(request.url?.path == "/repos/openai/agentboard/issues")

            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = """
            [
              {
                "number": 14,
                "title": "Implement the new work board",
                "body": "First line\\nMore detail",
                "state": "open",
                "labels": [
                  {"name": "status:in-progress"},
                  {"name": "priority:p1"},
                  {"name": "agent:codex"}
                ],
                "assignees": [{"login": "blake"}],
                "milestone": {"number": 2, "title": "Hermes Rebuild"},
                "created_at": "2026-04-20T12:00:00Z",
                "updated_at": "2026-04-22T15:30:00Z"
              },
              {
                "number": 18,
                "title": "Support empty labels",
                "body": null,
                "state": "open",
                "labels": [],
                "assignees": [],
                "milestone": null,
                "created_at": "2026-04-18T08:00:00Z",
                "updated_at": "2026-04-19T09:00:00Z"
              },
              {
                "number": 99,
                "title": "Actually a pull request",
                "body": "Ignore me",
                "state": "open",
                "labels": [],
                "assignees": [],
                "milestone": null,
                "pull_request": {},
                "created_at": "2026-04-18T08:00:00Z",
                "updated_at": "2026-04-19T09:00:00Z"
              }
            ]
            """
            return (response, Data(payload.utf8))
        })
        await service.configure(
            repositories: [ConfiguredRepository(owner: "openai", name: "agentboard")],
            token: "ghp_example"
        )

        let items = try await service.fetchWorkItems()
        #expect(items.count == 2)

        let first = try #require(items.first)
        #expect(first.issueNumber == 14)
        #expect(first.status == .inProgress)
        #expect(first.priority == .p1)
        #expect(first.agentHint == "codex")
        #expect(first.bodySummary == "First line")

        let unlabeled = try #require(items.first(where: { $0.issueNumber == 18 }))
        #expect(unlabeled.status == .ready)
        #expect(unlabeled.priority == .p2)
    }
}
