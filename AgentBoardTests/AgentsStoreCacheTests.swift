@testable import AgentBoardCore
import Foundation
import Testing

/// Contract tests for the SwiftData cache layer added to `AgentsStore` for
/// offline kanban support (issue #144). Mirrors `WorkStore`'s cache contract:
/// `bootstrap()` renders whatever is cached before the live refresh
/// resolves, a successful refresh persists the fresh snapshot, and a failed
/// refresh keeps the cached tasks visible instead of clearing the board.
@Suite("AgentsStore cache hydration (issue #144)")
@MainActor
struct AgentsStoreCacheTests {
    @Test func bootstrapRendersCachedTasksBeforeAnySuccessfulRefresh() async throws {
        // kanbanData points at /dev/null, so the live refresh always fails —
        // isolating what bootstrap() does with the cache on its own.
        let cache = try AgentBoardCache(inMemory: true)
        let cachedTask = KanbanTask(id: "cached-1", title: "From cache", status: .todo)
        try cache.replaceKanbanTasks([cachedTask])

        let store = makeStore(kanbanData: KanbanDataService(databasePath: "/dev/null"), cache: cache)

        await store.bootstrap()

        #expect(store.tasks.map(\.id) == ["cached-1"])
    }

    @Test func failedRefreshRetainsCachedTasksAndSetsStatusMessage() async throws {
        let cache = try AgentBoardCache(inMemory: true)
        let cachedTask = KanbanTask(id: "cached-1", title: "From cache", status: .todo)
        try cache.replaceKanbanTasks([cachedTask])

        let store = makeStore(kanbanData: FakeKanbanData(mode: .failure), cache: cache)

        await store.bootstrap()

        #expect(store.tasks.map(\.id) == ["cached-1"])
        #expect(store.statusMessage == "Showing cached tasks — kanban refresh failed.")
        #expect(store.errorMessage == nil)
    }

    @Test func successfulRefreshReplacesCacheWithFreshTasks() async throws {
        let cache = try AgentBoardCache(inMemory: true)
        let cachedTask = KanbanTask(id: "cached-1", title: "From cache", status: .todo)
        try cache.replaceKanbanTasks([cachedTask])

        let freshTask = KanbanTask(id: "fresh-1", title: "From refresh", status: .todo)
        let store = makeStore(kanbanData: FakeKanbanData(mode: .success([freshTask])), cache: cache)

        await store.bootstrap()

        #expect(store.tasks.map(\.id) == ["fresh-1"])
        let persisted = try cache.loadKanbanTasks()
        #expect(persisted.map(\.id) == ["fresh-1"])
    }

    @Test func bootstrapWithEmptyCacheAndFailingRefreshLeavesTasksEmptyWithError() async throws {
        let cache = try AgentBoardCache(inMemory: true)
        let store = makeStore(kanbanData: FakeKanbanData(mode: .failure), cache: cache)

        await store.bootstrap()

        #expect(store.tasks.isEmpty)
        #expect(store.errorMessage != nil)
    }

    // MARK: - Helpers

    private func makeStore(kanbanData: any KanbanDataReading, cache: any AgentBoardCacheProtocol) -> AgentsStore {
        let suffix = UUID().uuidString
        let repo = SettingsRepository(
            suiteName: "AgentsStoreCacheTests-\(suffix)",
            serviceName: "AgentsStoreCacheTests-\(suffix)"
        )
        let settings = SettingsStore(repository: repo)
        return AgentsStore(
            kanbanData: kanbanData,
            cliWriter: NoopCLIWriter(),
            cache: cache,
            settingsStore: settings
        )
    }
}

// MARK: - Test doubles

private enum FakeKanbanDataError: Error {
    case boom
}

private struct FakeKanbanData: KanbanDataReading {
    enum Mode {
        case success([KanbanTask])
        case failure
    }

    let mode: Mode

    func refresh() async throws -> Bool {
        if case .failure = mode {
            throw FakeKanbanDataError.boom
        }
        return true
    }

    func fetchTasks(status _: KanbanStatus?, tenant _: String?, excludeArchived _: Bool) async throws -> [KanbanTask] {
        switch mode {
        case let .success(tasks): return tasks
        case .failure: throw FakeKanbanDataError.boom
        }
    }

    func fetchLinks(for _: String) async throws -> (parents: [String], children: [String]) {
        ([], [])
    }

    func fetchComments(for _: String) async throws -> [KanbanComment] {
        []
    }

    func fetchRuns(for _: String) async throws -> [KanbanRun] {
        []
    }
}

private struct NoopCLIWriter: KanbanCLIWriting {
    func create(_ draft: KanbanCreateDraft) async throws -> KanbanTask {
        KanbanTask(id: UUID().uuidString, title: draft.title)
    }

    func comment(taskID _: String, body _: String) async throws {}
    func complete(taskID _: String, summary _: String) async throws {}
    func block(taskID _: String, reason _: String) async throws {}
    func unblock(taskID _: String) async throws {}
    func promote(taskID _: String) async throws {}
    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}
