import AgentBoardCore
import Foundation
import Testing

@Suite("WorkStore", .serialized)
@MainActor
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
}
