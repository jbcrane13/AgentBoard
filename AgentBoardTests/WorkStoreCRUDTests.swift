import AgentBoardCore
import Foundation
import Testing

@Suite("WorkStore CRUD", .serialized)
@MainActor
struct WorkStoreCRUDTests {
    // MARK: - Helpers

    private func makeStore(
        mockHandler: @escaping MockURLProtocol.Handler
    ) throws -> (WorkStore, SettingsStore) {
        let service = GitHubWorkService(session: makeMockSession(handler: mockHandler))
        let cache = try AgentBoardCache(inMemory: true)
        let suite = "WorkStoreCRUDTests-\(UUID().uuidString)"
        let repo = SettingsRepository(suiteName: suite, serviceName: suite)
        let settingsStore = SettingsStore(repository: repo)
        settingsStore.githubToken = "ghp_test"
        settingsStore.repositories = [ConfiguredRepository(owner: "org", name: "repo")]
        let store = WorkStore(service: service, cache: cache, settingsStore: settingsStore)
        return (store, settingsStore)
    }

    private func issueJSON(
        number: Int,
        title: String,
        body: String = "",
        labels: [String] = [],
        state: String = "open"
    ) -> String {
        let labelsJSON = labels.map { #"{"name": "\#($0)"}"# }.joined(separator: ", ")
        return """
        {
            "number": \(number),
            "title": "\(title)",
            "body": "\(body)",
            "state": "\(state)",
            "labels": [\(labelsJSON)],
            "assignees": [],
            "milestone": null,
            "created_at": "2026-04-01T00:00:00Z",
            "updated_at": "2026-04-02T00:00:00Z"
        }
        """
    }

    private func successResponse(for url: URL?) throws -> HTTPURLResponse {
        try HTTPURLResponse(
            url: url ?? URL(string: "http://api.github.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    // MARK: - createIssue

    @Test func createIssueAppendsToItemsOnSuccess() async throws {
        let createdJSON = issueJSON(number: 100, title: "Brand new", body: "Body here")
        let (store, _) = try makeStore(mockHandler: { request in
            let response = try self.successResponse(for: request.url)
            if request.httpMethod == "POST" {
                return (response, Data(createdJSON.utf8))
            }
            return (response, Data("[]".utf8))
        })
        let repo = ConfiguredRepository(owner: "org", name: "repo")

        await store.createIssue(repository: repo, title: "Brand new", body: "Body here")

        #expect(store.items.count == 1)
        #expect(store.items.first?.issueNumber == 100)
        #expect(store.items.first?.title == "Brand new")
        #expect(store.statusMessage == "Created org/repo#100.")
        #expect(store.errorMessage == nil)
    }

    @Test func createIssueSendsTitleBodyAndLabelsInRequestPayload() async throws {
        final class Capture: @unchecked Sendable {
            var payload: [String: Any] = [:]
        }
        let captured = Capture()
        let createdJSON = issueJSON(number: 101, title: "With labels", labels: ["type:bug"])
        let (store, _) = try makeStore(mockHandler: { request in
            if request.httpMethod == "POST",
               let body = request.httpBody ?? request.bodyStreamData(),
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                captured.payload = json
            }
            let response = try self.successResponse(for: request.url)
            return (response, Data(createdJSON.utf8))
        })
        let repo = ConfiguredRepository(owner: "org", name: "repo")

        await store.createIssue(
            repository: repo,
            title: "With labels",
            body: "Some body",
            labels: ["type:bug"],
            assignees: ["daneel"]
        )

        #expect(captured.payload["title"] as? String == "With labels")
        #expect(captured.payload["body"] as? String == "Some body")
        let labels = captured.payload["labels"] as? [String] ?? []
        #expect(labels.contains("type:bug"))
        let assignees = captured.payload["assignees"] as? [String] ?? []
        #expect(assignees.contains("daneel"))
    }

    @Test func createIssueErrorsWhenGitHubNotConfigured() async throws {
        let (store, settingsStore) = try makeStore(mockHandler: { request in
            let response = try self.successResponse(for: request.url)
            return (response, Data("{}".utf8))
        })
        settingsStore.githubToken = ""
        settingsStore.repositories = []

        await store.createIssue(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            title: "Should fail",
            body: ""
        )

        #expect(store.errorMessage == "Connect GitHub before creating issues.")
        #expect(store.items.isEmpty)
    }

    @Test func createIssueSurfacesServerErrorAsErrorMessage() async throws {
        let (store, _) = try makeStore(mockHandler: { request in
            if request.httpMethod == "POST" {
                let response = try HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("oops".utf8))
            }
            return try (self.successResponse(for: request.url), Data("[]".utf8))
        })
        let repo = ConfiguredRepository(owner: "org", name: "repo")

        await store.createIssue(repository: repo, title: "Will fail", body: "")

        #expect(store.errorMessage != nil)
        #expect(store.items.isEmpty)
    }

    @Test func createIssueClearsStaleStatusMessageEvenOnFailure() async throws {
        let (store, _) = try makeStore(mockHandler: { request in
            if request.httpMethod == "POST" {
                let response = try HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("oops".utf8))
            }
            return try (self.successResponse(for: request.url), Data("[]".utf8))
        })
        store.statusMessage = "Something old"

        await store.createIssue(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            title: "Boom",
            body: ""
        )

        #expect(store.statusMessage == nil)
    }

    // MARK: - updateIssue

    @Test func updateIssueAppliesPatchedFieldsToLocalItem() async throws {
        let listPayload = "[" + issueJSON(number: 50, title: "Old title", body: "Old body") + "]"
        let updatedPayload = issueJSON(number: 50, title: "New title", body: "New body")
        let (store, _) = try makeStore(mockHandler: { request in
            let response = try self.successResponse(for: request.url)
            let body = request.httpMethod == "PATCH"
                ? Data(updatedPayload.utf8)
                : Data(listPayload.utf8)
            return (response, body)
        })
        await store.refresh()
        let item = try #require(store.items.first)

        await store.updateIssue(item, title: "New title", body: "New body")

        #expect(store.items.first?.title == "New title")
        #expect(store.items.first?.bodySummary == "New body")
        #expect(store.statusMessage == "Updated org/repo#50.")
        #expect(store.errorMessage == nil)
    }

    @Test func updateIssueOmitsUnsetFieldsFromPayload() async throws {
        final class Capture: @unchecked Sendable {
            var payload: [String: Any] = [:]
        }
        let captured = Capture()
        let listPayload = "[" + issueJSON(number: 60, title: "Title only update") + "]"
        let updatedPayload = issueJSON(number: 60, title: "Updated title")
        let (store, _) = try makeStore(mockHandler: { request in
            if request.httpMethod == "PATCH",
               let body = request.httpBody ?? request.bodyStreamData(),
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                captured.payload = json
            }
            let response = try self.successResponse(for: request.url)
            let body = request.httpMethod == "PATCH"
                ? Data(updatedPayload.utf8)
                : Data(listPayload.utf8)
            return (response, body)
        })
        await store.refresh()
        let item = try #require(store.items.first)

        await store.updateIssue(item, title: "Updated title")

        #expect(captured.payload["title"] as? String == "Updated title")
        // The store should not have sent body/labels/assignees/milestone keys when those are nil.
        #expect(captured.payload["body"] == nil)
        #expect(captured.payload["labels"] == nil)
        #expect(captured.payload["assignees"] == nil)
        #expect(captured.payload["milestone"] == nil)
        #expect(captured.payload["state"] == nil)
    }

    @Test func updateIssueErrorsWhenGitHubNotConfigured() async throws {
        let (store, settingsStore) = try makeStore(mockHandler: { request in
            try (self.successResponse(for: request.url), Data("[]".utf8))
        })
        settingsStore.githubToken = ""
        settingsStore.repositories = []

        let item = WorkItem(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            issueNumber: 1,
            title: "Stub",
            bodySummary: "",
            isClosed: false,
            assignees: [],
            milestone: nil,
            labels: [],
            status: .ready,
            priority: .p2,
            agentHint: nil,
            createdAt: .now,
            updatedAt: .now
        )

        await store.updateIssue(item, title: "Doesn't matter")

        #expect(store.errorMessage == "Connect GitHub before updating issues.")
    }

    @Test func updateIssueSurfacesServerErrorAndKeepsLocalItemUnchanged() async throws {
        let listPayload = "[" + issueJSON(number: 70, title: "Original") + "]"
        let (store, _) = try makeStore(mockHandler: { request in
            if request.httpMethod == "PATCH" {
                let response = try HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("oops".utf8))
            }
            return try (self.successResponse(for: request.url), Data(listPayload.utf8))
        })
        await store.refresh()
        let item = try #require(store.items.first)

        await store.updateIssue(item, title: "Should not stick")

        #expect(store.errorMessage != nil)
        #expect(store.items.first?.title == "Original")
    }

    // MARK: - workItem(for:)

    @Test func workItemForReferenceReturnsMatchingItem() async throws {
        let listPayload = "[" + issueJSON(number: 5, title: "Findable") + "]"
        let (store, _) = try makeStore(mockHandler: { request in
            try (self.successResponse(for: request.url), Data(listPayload.utf8))
        })
        await store.refresh()
        let reference = WorkReference(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            issueNumber: 5
        )

        let result = store.workItem(for: reference)

        #expect(result?.title == "Findable")
    }

    @Test func workItemForReferenceReturnsNilWhenNoMatch() async throws {
        let listPayload = "[" + issueJSON(number: 5, title: "Only one") + "]"
        let (store, _) = try makeStore(mockHandler: { request in
            try (self.successResponse(for: request.url), Data(listPayload.utf8))
        })
        await store.refresh()
        let reference = WorkReference(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            issueNumber: 999
        )

        #expect(store.workItem(for: reference) == nil)
    }
}

private extension URLRequest {
    /// `URLProtocol` strips `httpBody` when a request streams; mirror it back from the stream.
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
