@testable import AgentBoard
import Foundation
import Testing

// Extended tests for assignees, milestones, and state filtering (AB-bvu, AB-thl, AB-86l)
// Core GitHubIssuesService tests remain in GitHubIssuesServiceTests.swift

struct GitHubIssuesServiceExtendedTests {
    // MARK: - Assignees

    @Test("createIssue sends assignees in POST payload")
    func createIssueSendsAssignees() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let createdIssueJSON = """
        {"number":80,"title":"Assigned issue","body":null,"state":"open",
         "labels":[],"assignees":[{"login":"jbcrane13"}],"milestone":null,
         "created_at":"2026-03-01T00:00:00Z","updated_at":"2026-03-01T00:00:00Z"}
        """

        nonisolated(unsafe) var capturedBody: Data?
        MockURLProtocol.requestHandler = { req in
            capturedBody = req.httpBody
            return (
                mockResponse(statusCode: 201, url: req.url!),
                Data(createdIssueJSON.utf8)
            )
        }

        _ = try await service.createIssue(
            owner: "o", repo: "r", token: "t",
            title: "Assigned issue", body: nil, labels: [],
            assignees: ["jbcrane13"]
        )

        let body = try #require(capturedBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let assignees = try #require(json["assignees"] as? [String])
        #expect(assignees == ["jbcrane13"])
    }

    @Test("updateIssue sends assignees in PATCH payload")
    func updateIssueSendsAssignees() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let updatedIssueJSON = """
        {"number":42,"title":"Fix the widget","body":null,"state":"open",
         "labels":[],"assignees":[{"login":"jbcrane13"}],"milestone":null,
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-03-17T00:00:00Z"}
        """

        nonisolated(unsafe) var capturedBody: Data?
        MockURLProtocol.requestHandler = { req in
            capturedBody = req.httpBody
            return (
                mockResponse(statusCode: 200, url: req.url!),
                Data(updatedIssueJSON.utf8)
            )
        }

        _ = try await service.updateIssue(
            owner: "o", repo: "r", token: "t",
            number: 42, title: nil, body: nil,
            labels: nil, state: nil,
            assignees: ["jbcrane13"]
        )

        let body = try #require(capturedBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let assignees = try #require(json["assignees"] as? [String])
        #expect(assignees == ["jbcrane13"])
    }

    @Test("mapToBead extracts assignee from assignees array")
    func mapToBeadExtractsAssignee() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let issueJSON = """
        [{"number":42,"title":"Test","body":null,"state":"open",
          "labels":[],"assignees":[{"login":"jbcrane13"}],"milestone":null,
          "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]
        """

        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            if url.query?.contains("page=1") == true {
                return (mockResponse(statusCode: 200, url: url), Data(issueJSON.utf8))
            }
            return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
        }

        let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
        let bead = try #require(beads.first)
        #expect(bead.assignee == "jbcrane13")
    }

    // MARK: - State filtering

    @Test("fetchIssues URL contains state=all")
    func fetchIssuesURLContainsStateAll() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        nonisolated(unsafe) var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            return (mockResponse(statusCode: 200, url: req.url!), Data("[]".utf8))
        }

        _ = try await service.fetchIssues(owner: "o", repo: "r", token: "t")

        let url = try #require(capturedURL)
        #expect(url.query?.contains("state=all") == true)
    }

    @Test("fetchIssues returns both open and closed issues")
    func fetchIssuesReturnsBothOpenAndClosed() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let combinedJSON = """
        [
          {"number":42,"title":"Open bug","body":null,"state":"open",
           "labels":[],"assignees":[],"milestone":null,
           "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"},
          {"number":99,"title":"Closed feature","body":null,"state":"closed",
           "labels":[],"assignees":[],"milestone":null,
           "created_at":"2025-12-01T00:00:00Z","updated_at":"2025-12-15T00:00:00Z"}
        ]
        """

        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            if url.query?.contains("page=1") == true {
                return (mockResponse(statusCode: 200, url: url), Data(combinedJSON.utf8))
            }
            return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
        }

        let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
        #expect(beads.count == 2)
        #expect(beads.first(where: { $0.id == "GH-42" })?.status == .open)
        #expect(beads.first(where: { $0.id == "GH-99" })?.status == .done)
    }

    // MARK: - Milestones

    @Test("createIssue sends milestone in POST payload")
    func createIssueSendsMilestoneInPayload() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let responseJSON = """
        {"number":80,"title":"Milestone issue","body":null,"state":"open",
         "labels":[],"assignees":[],"milestone":{"number":3,"title":"Sprint 1"},
         "created_at":"2026-03-01T00:00:00Z","updated_at":"2026-03-01T00:00:00Z"}
        """

        nonisolated(unsafe) var capturedBody: Data?
        MockURLProtocol.requestHandler = { req in
            capturedBody = req.httpBody
            return (mockResponse(statusCode: 201, url: req.url!), Data(responseJSON.utf8))
        }

        _ = try await service.createIssue(
            owner: "o", repo: "r", token: "t",
            title: "Milestone issue", body: nil, labels: [],
            milestone: 3
        )

        let body = try #require(capturedBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["milestone"] as? Int == 3)
    }

    @Test("updateIssue sends milestone in PATCH payload")
    func updateIssueSendsMilestoneInPayload() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let responseJSON = """
        {"number":42,"title":"Updated","body":null,"state":"open",
         "labels":[],"assignees":[],"milestone":{"number":5,"title":"v3.0"},
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-03-17T00:00:00Z"}
        """

        nonisolated(unsafe) var capturedBody: Data?
        MockURLProtocol.requestHandler = { req in
            capturedBody = req.httpBody
            return (mockResponse(statusCode: 200, url: req.url!), Data(responseJSON.utf8))
        }

        _ = try await service.updateIssue(
            owner: "o", repo: "r", token: "t",
            number: 42, title: "Updated", body: nil, labels: nil, state: nil,
            milestone: 5
        )

        let body = try #require(capturedBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["milestone"] as? Int == 5)
    }

    @Test("fetchMilestones parses response correctly")
    func fetchMilestonesParses() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let milestonesJSON = """
        [{"number":1,"title":"v2.1","open_issues":5,"closed_issues":3,"due_on":"2026-04-01T00:00:00Z"},
         {"number":2,"title":"v2.2","open_issues":10,"closed_issues":0,"due_on":null}]
        """

        MockURLProtocol.requestHandler = { req in
            (mockResponse(statusCode: 200, url: req.url!), Data(milestonesJSON.utf8))
        }

        let milestones = try await service.fetchMilestones(owner: "o", repo: "r", token: "t")
        #expect(milestones.count == 2)

        let first = try #require(milestones.first)
        #expect(first.number == 1)
        #expect(first.title == "v2.1")
        #expect(first.openIssues == 5)
        #expect(first.closedIssues == 3)
        #expect(first.totalIssues == 8)
        #expect(first.progress > 0.37 && first.progress < 0.38)

        let second = milestones[1]
        #expect(second.dueOn == nil)
        #expect(second.progress == 0)
    }

    @Test("mapToBead extracts milestoneNumber and milestoneTitle")
    func mapToBeadExtractsMilestoneFields() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let issueJSON = """
        [{"number":42,"title":"Test","body":null,"state":"open",
          "labels":[],"assignees":[],"milestone":{"number":1,"title":"v2.1"},
          "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]
        """

        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            if url.query?.contains("page=1") == true {
                return (mockResponse(statusCode: 200, url: url), Data(issueJSON.utf8))
            }
            return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
        }

        let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
        let bead = try #require(beads.first)
        #expect(bead.milestoneNumber == 1)
        #expect(bead.milestoneTitle == "v2.1")
    }

    @Test("mapToBead handles null milestone")
    func mapToBeadHandlesNullMilestone() async throws {
        let session = makeMockSession()
        let service = GitHubIssuesService(session: session)

        let issueJSON = """
        [{"number":99,"title":"No milestone","body":null,"state":"open",
          "labels":[],"assignees":[],"milestone":null,
          "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]
        """

        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            if url.query?.contains("page=1") == true {
                return (mockResponse(statusCode: 200, url: url), Data(issueJSON.utf8))
            }
            return (mockResponse(statusCode: 200, url: url), Data("[]".utf8))
        }

        let beads = try await service.fetchIssues(owner: "o", repo: "r", token: "t")
        let bead = try #require(beads.first)
        #expect(bead.milestoneNumber == nil)
        #expect(bead.milestoneTitle == nil)
    }
}
