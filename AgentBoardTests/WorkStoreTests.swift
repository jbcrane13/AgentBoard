// swiftlint:disable file_length
import AgentBoardCore
import Foundation
import Testing

@Suite("WorkStore", .serialized)
@MainActor
// swiftlint:disable:next type_body_length
struct WorkStoreTests {
    // MARK: - Helpers

    private func makeStore(
        mockHandler: @escaping MockURLProtocol.Handler = { _ in
            let response = try HTTPURLResponse(
                url: URL(string: "http://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("[]".utf8))
        }
    ) throws -> (WorkStore, SettingsStore) {
        let service = GitHubWorkService(session: makeMockSession(handler: mockHandler))
        let cache = try AgentBoardCache(inMemory: true)
        let repo = SettingsRepository(
            suiteName: "WorkStoreTests-\(UUID().uuidString)",
            serviceName: "WorkStoreTests-\(UUID().uuidString)"
        )
        let settingsStore = SettingsStore(repository: repo)
        settingsStore.githubToken = "ghp_test"
        settingsStore.repositories = [ConfiguredRepository(owner: "org", name: "repo")]
        let store = WorkStore(service: service, cache: cache, settingsStore: settingsStore)
        return (store, settingsStore)
    }

    private func issueJSON(number: Int, title: String, body: String = "", labels: [String] = []) -> String {
        let labelsJSON = labels.map { #"{"name": "\#($0)"}"# }.joined(separator: ", ")
        return """
        {
            "number": \(number),
            "title": "\(title)",
            "body": "\(body)",
            "state": "open",
            "labels": [\(labelsJSON)],
            "assignees": [],
            "milestone": null,
            "created_at": "2026-04-01T00:00:00Z",
            "updated_at": "2026-04-02T00:00:00Z"
        }
        """
    }

    private func makeStoreWith(
        issues: [(number: Int, title: String, body: String, labels: [String])]
    ) async throws -> WorkStore {
        let payload = "[" + issues
            .map { issueJSON(number: $0.number, title: $0.title, body: $0.body, labels: $0.labels) }
            .joined(separator: ",") + "]"
        let (store, _) = try makeStore(mockHandler: { _ in
            let response = try HTTPURLResponse(
                url: URL(string: "http://api.github.com/repos/org/repo/issues")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(payload.utf8))
        })
        await store.refresh()
        return store
    }

    // MARK: - filteredItems

    @Test func filteredItemsReturnsAllWhenSearchEmpty() async throws {
        let store = try await makeStoreWith(issues: [
            (1, "Fix crash", "", []),
            (2, "Add feature", "", [])
        ])
        store.searchText = ""
        #expect(store.filteredItems.count == 2)
    }

    @Test func filteredItemsMatchesTitle() async throws {
        let store = try await makeStoreWith(issues: [
            (1, "Fix crash", "", []),
            (2, "Add feature", "", [])
        ])
        store.searchText = "crash"
        #expect(store.filteredItems.count == 1)
        #expect(store.filteredItems[0].issueNumber == 1)
    }

    @Test func filteredItemsMatchesTitleCaseInsensitive() async throws {
        let store = try await makeStoreWith(issues: [(1, "Fix Crash", "", [])])
        store.searchText = "CRASH"
        #expect(store.filteredItems.count == 1)
    }

    @Test func filteredItemsMatchesBodySummary() async throws {
        let store = try await makeStoreWith(issues: [(1, "Issue", "detailed description here", [])])
        store.searchText = "detailed"
        #expect(store.filteredItems.count == 1)
    }

    @Test func filteredItemsMatchesLabel() async throws {
        let store = try await makeStoreWith(issues: [
            (1, "Task A", "", ["agent:codex"]),
            (2, "Task B", "", ["agent:claude"])
        ])
        store.searchText = "codex"
        #expect(store.filteredItems.count == 1)
        #expect(store.filteredItems[0].issueNumber == 1)
    }

    @Test func filteredItemsMatchesIssueReference() async throws {
        let store = try await makeStoreWith(issues: [
            (42, "The answer", "", []),
            (7, "Lucky number", "", [])
        ])
        store.searchText = "#42"
        #expect(store.filteredItems.count == 1)
        #expect(store.filteredItems[0].issueNumber == 42)
    }

    @Test func filteredItemsReturnsEmptyWhenNoMatch() async throws {
        let store = try await makeStoreWith(issues: [(1, "Fix crash", "", [])])
        store.searchText = "zzznomatch"
        #expect(store.filteredItems.isEmpty)
    }

    // MARK: - groupedItems

    @Test func groupedItemsCoversAllWorkStates() throws {
        let (store, _) = try makeStore()
        let states = store.groupedItems.map(\.state)
        #expect(states.contains(.ready))
        #expect(states.contains(.inProgress))
        #expect(states.contains(.blocked))
        #expect(states.contains(.review))
    }

    @Test func groupedItemsPlacesItemsInCorrectGroup() async throws {
        let store = try await makeStoreWith(issues: [
            (1, "Ready item", "", ["status:ready"]),
            (2, "In progress", "", ["status:in-progress"]),
            (3, "Blocked item", "", ["status:blocked"])
        ])
        let readyGroup = store.groupedItems.first { $0.state == .ready }
        let inProgressGroup = store.groupedItems.first { $0.state == .inProgress }
        #expect(readyGroup?.items.count == 1)
        #expect(inProgressGroup?.items.count == 1)
    }

    @Test func groupedItemsRespectsSearchFilter() async throws {
        let store = try await makeStoreWith(issues: [
            (1, "Fix crash", "", ["status:ready"]),
            (2, "Add tests", "", ["status:ready"])
        ])
        store.searchText = "crash"
        let readyGroup = store.groupedItems.first { $0.state == .ready }
        #expect(readyGroup?.items.count == 1)
    }

    // MARK: - bootstrap

    @Test func bootstrapSkipsRefreshWhenGitHubNotConfigured() async throws {
        final class Flag: @unchecked Sendable { var value = false }
        let refreshCalled = Flag()
        let (store, settingsStore) = try makeStore(mockHandler: { _ in
            refreshCalled.value = true
            let response = try HTTPURLResponse(
                url: URL(string: "http://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("[]".utf8))
        })
        settingsStore.githubToken = ""
        settingsStore.repositories = []
        await store.bootstrap()
        #expect(!refreshCalled.value)
    }

    @Test func bootstrapIsIdempotent() async throws {
        final class Counter: @unchecked Sendable { var value = 0 }
        let callCount = Counter()
        let (store, _) = try makeStore(mockHandler: { _ in
            callCount.value += 1
            let response = try HTTPURLResponse(
                url: URL(string: "http://api.github.com/repos/org/repo/issues")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("[]".utf8))
        })
        await store.bootstrap()
        await store.bootstrap()
        #expect(callCount.value == 1)
    }

    // MARK: - refresh

    @Test func refreshPopulatesItemsFromGitHub() async throws {
        let store = try await makeStoreWith(issues: [
            (10, "Implement board", "Details here", ["status:ready", "priority:p1"])
        ])
        #expect(store.items.count == 1)
        #expect(store.items[0].issueNumber == 10)
        #expect(store.items[0].title == "Implement board")
        #expect(store.items[0].status == .ready)
        #expect(store.items[0].priority == .p1)
        #expect(store.errorMessage == nil)
        #expect(store.isLoading == false)
    }

    @Test func refreshLeavesItemsEmptyWhenNotConfigured() async throws {
        let service = GitHubWorkService(session: makeMockSession { _ in
            let response = try HTTPURLResponse(
                url: URL(string: "http://x.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("[]".utf8))
        })
        let cache = try AgentBoardCache(inMemory: true)
        let repo = SettingsRepository(
            suiteName: "refresh-unconfigured-\(UUID().uuidString)",
            serviceName: "refresh-unconfigured-\(UUID().uuidString)"
        )
        let store = WorkStore(service: service, cache: cache, settingsStore: SettingsStore(repository: repo))
        await store.refresh()
        #expect(store.items.isEmpty)
        #expect(store.errorMessage == nil)
    }

    /// A failing refetch with cached items must keep the items visible and not surface a
    /// transient errorMessage, per the explicit contract in `WorkStore.refresh`.
    @Test func refreshPreservesItemsAndSuppressesErrorWhenFetchFailsWithExistingItems() async throws {
        final class Phase: @unchecked Sendable { var failNext = false }
        let phase = Phase()
        let listPayload = "[" + issueJSON(
            number: 11,
            title: "Cached",
            body: "",
            labels: ["status:ready"]
        ) + "]"

        let (store, _) = try makeStore(mockHandler: { request in
            if phase.failNext {
                let response = try HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("server down".utf8))
            }
            let response = try HTTPURLResponse(
                url: URL(string: "http://api.github.com/repos/org/repo/issues")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(listPayload.utf8))
        })

        await store.refresh()
        #expect(store.items.count == 1)
        phase.failNext = true

        await store.refresh()

        #expect(store.items.count == 1)
        #expect(store.items.first?.issueNumber == 11)
        #expect(store.errorMessage == nil)
        #expect(store.isLoading == false)
    }

    /// A failing first refetch with no cached items should surface the error so the user knows.
    @Test func refreshSetsErrorMessageWhenFetchFailsWithNoItems() async throws {
        let (store, _) = try makeStore(mockHandler: { request in
            let response = try HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("server down".utf8))
        })

        await store.refresh()

        #expect(store.items.isEmpty)
        #expect(store.errorMessage != nil)
        #expect(store.isLoading == false)
    }

    // MARK: - workItem(for:)

    @Test func workItemForReferenceReturnsMatchingItem() async throws {
        let store = try await makeStoreWith(issues: [(5, "Target", "", [])])
        let ref = WorkReference(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            issueNumber: 5
        )
        #expect(store.workItem(for: ref)?.issueNumber == 5)
    }

    @Test func workItemForReferenceReturnsNilWhenNotFound() throws {
        let (store, _) = try makeStore()
        let ref = WorkReference(
            repository: ConfiguredRepository(owner: "org", name: "repo"),
            issueNumber: 99
        )
        #expect(store.workItem(for: ref) == nil)
    }

    // MARK: - updateStatus edge cases

    /// Dropping a card on its current column must not issue a network call.
    @Test func updateStatusSkipsRequestWhenAlreadyAtTargetState() async throws {
        final class Counter: @unchecked Sendable { var patches = 0 }
        let counter = Counter()
        let listPayload = "[" + issueJSON(
            number: 1,
            title: "Same-state",
            body: "",
            labels: ["status:ready"]
        ) + "]"

        let (store, _) = try makeStore(mockHandler: { request in
            if request.httpMethod == "PATCH" {
                counter.patches += 1
            }
            let response = try HTTPURLResponse(
                url: URL(string: "http://api.github.com/repos/org/repo/issues")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(listPayload.utf8))
        })
        await store.refresh()
        #expect(store.items.count == 1)
        let item = try #require(store.items.first)
        #expect(item.status == .ready)

        await store.updateStatus(for: item, to: .ready)

        #expect(counter.patches == 0)
        #expect(store.errorMessage == nil)
    }

    @Test func updateStatusUpdatesItemAndStatusMessageOnSuccess() async throws {
        let listPayload = "[" + issueJSON(
            number: 7,
            title: "Move me",
            body: "",
            labels: ["status:ready", "area:ui"]
        ) + "]"
        let updatedPayload = issueJSON(
            number: 7,
            title: "Move me",
            body: "",
            labels: ["status:in-progress", "area:ui"]
        )

        let (store, _) = try makeStore(mockHandler: { request in
            let body = (request.httpMethod == "PATCH")
                ? Data(updatedPayload.utf8)
                : Data(listPayload.utf8)
            let response = try HTTPURLResponse(
                url: request.url ?? URL(string: "http://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        })
        await store.refresh()
        let item = try #require(store.items.first)

        await store.updateStatus(for: item, to: .inProgress)

        #expect(store.items.first?.status == .inProgress)
        #expect(store.statusMessage?.contains("In Progress") == true)
        #expect(store.errorMessage == nil)
    }

    @Test func updateStatusReplacesStatusLabelsAndPreservesOthers() async throws {
        final class Capture: @unchecked Sendable { var labels: [String] = [] }
        let captured = Capture()
        let listPayload = "[" + issueJSON(
            number: 12,
            title: "Sticky labels",
            body: "",
            labels: ["status:ready", "area:ui", "topic:onboarding"]
        ) + "]"
        let updatedPayload = issueJSON(
            number: 12,
            title: "Sticky labels",
            body: "",
            labels: ["status:in-progress", "area:ui", "topic:onboarding"]
        )

        let (store, _) = try makeStore(mockHandler: { request in
            if request.httpMethod == "PATCH",
               let body = request.httpBody ?? request.bodyStreamData(),
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let labels = json["labels"] as? [String] {
                captured.labels = labels
            }
            let response = try HTTPURLResponse(
                url: request.url ?? URL(string: "http://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let body = request.httpMethod == "PATCH"
                ? Data(updatedPayload.utf8)
                : Data(listPayload.utf8)
            return (response, body)
        })
        await store.refresh()
        let item = try #require(store.items.first)

        await store.updateStatus(for: item, to: .inProgress)

        let lowered = captured.labels.map { $0.lowercased() }
        #expect(lowered.contains("status:in-progress"))
        #expect(!lowered.contains("status:ready"))
        #expect(lowered.contains("area:ui"))
        #expect(lowered.contains("topic:onboarding"))
    }

    @Test func updateStatusErrorsWhenGitHubNotConfigured() async throws {
        let (store, settingsStore) = try makeStore()
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
            labels: ["status:ready"],
            status: .ready,
            priority: .p2,
            agentHint: nil,
            createdAt: .now,
            updatedAt: .now
        )

        await store.updateStatus(for: item, to: .inProgress)

        #expect(store.errorMessage == "Connect GitHub before updating work items.")
    }

    @Test func updateStatusClearsStaleErrorMessageOnSuccess() async throws {
        let listPayload = "[" + issueJSON(
            number: 3,
            title: "Recovery",
            body: "",
            labels: ["status:ready"]
        ) + "]"
        let updatedPayload = issueJSON(
            number: 3,
            title: "Recovery",
            body: "",
            labels: ["status:done"]
        )

        let (store, _) = try makeStore(mockHandler: { request in
            let body = (request.httpMethod == "PATCH")
                ? Data(updatedPayload.utf8)
                : Data(listPayload.utf8)
            let response = try HTTPURLResponse(
                url: request.url ?? URL(string: "http://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        })
        await store.refresh()
        store.errorMessage = "Previous failure"
        let item = try #require(store.items.first)

        await store.updateStatus(for: item, to: .done)

        #expect(store.errorMessage == nil)
        #expect(store.items.first?.status == .done)
    }

    @Test func updateStatusSetsErrorMessageOnNetworkFailure() async throws {
        let listPayload = "[" + issueJSON(
            number: 9,
            title: "Will fail",
            body: "",
            labels: ["status:ready"]
        ) + "]"

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
            let response = try HTTPURLResponse(
                url: URL(string: "http://api.github.com/repos/org/repo/issues")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(listPayload.utf8))
        })
        await store.refresh()
        let item = try #require(store.items.first)

        await store.updateStatus(for: item, to: .inProgress)

        #expect(store.errorMessage != nil)
        // Item state should not have changed locally after a failed PATCH.
        #expect(store.items.first?.status == .ready)
    }

    @Test func closeIssueTransitionsToDone() async throws {
        let listPayload = "[" + issueJSON(
            number: 21,
            title: "Closeable",
            body: "",
            labels: ["status:ready"]
        ) + "]"
        let updatedPayload = issueJSON(
            number: 21,
            title: "Closeable",
            body: "",
            labels: ["status:done"]
        )
        let (store, _) = try makeStore(mockHandler: { request in
            let body = (request.httpMethod == "PATCH")
                ? Data(updatedPayload.utf8)
                : Data(listPayload.utf8)
            let response = try HTTPURLResponse(
                url: request.url ?? URL(string: "http://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        })
        await store.refresh()
        let item = try #require(store.items.first)

        await store.closeIssue(item)

        #expect(store.items.first?.status == .done)
    }

    @Test func reopenIssueTransitionsFromDoneToReady() async throws {
        let listPayload = "[" + makeClosedIssueJSON(
            number: 33,
            title: "Reopen me",
            labels: ["status:done"]
        ) + "]"
        let updatedPayload = issueJSON(
            number: 33,
            title: "Reopen me",
            body: "",
            labels: ["status:ready"]
        )
        let (store, _) = try makeStore(mockHandler: { request in
            let body = (request.httpMethod == "PATCH")
                ? Data(updatedPayload.utf8)
                : Data(listPayload.utf8)
            let response = try HTTPURLResponse(
                url: request.url ?? URL(string: "http://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        })
        await store.refresh()
        let item = try #require(store.items.first)
        #expect(item.status == .done)

        await store.reopenIssue(item)

        #expect(store.items.first?.status == .ready)
    }

    private func makeClosedIssueJSON(number: Int, title: String, labels: [String]) -> String {
        let labelsJSON = labels.map { #"{"name": "\#($0)"}"# }.joined(separator: ", ")
        return """
        {
            "number": \(number),
            "title": "\(title)",
            "body": "",
            "state": "closed",
            "labels": [\(labelsJSON)],
            "assignees": [],
            "milestone": null,
            "created_at": "2026-04-01T00:00:00Z",
            "updated_at": "2026-04-02T00:00:00Z"
        }
        """
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
