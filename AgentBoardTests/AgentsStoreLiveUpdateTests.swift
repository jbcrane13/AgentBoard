@testable import AgentBoardCore
import Foundation
import Testing

/// Contract tests for `AgentsStore`'s event-driven live-update poll (kanban
/// center-stage pass). `startLiveUpdates()` drives a sleep loop that isn't
/// directly testable, so these exercise `pollForChanges()` — the single
/// iteration factored out of that loop — instead of waiting on real sleeps.
@Suite("AgentsStore live updates")
@MainActor
struct AgentsStoreLiveUpdateTests {
    @Test func pollForChangesTriggersExactlyOneRefreshWhenLatestEventIDAdvances() async throws {
        let fake = FakeLiveUpdateKanbanData()
        await fake.setLatestEventID(1)
        let store = try makeStore(kanbanData: fake)

        // First poll only establishes the baseline — it must not itself
        // trigger a refresh (the store was already freshly created).
        let primed = await store.pollForChanges()
        #expect(primed == false)
        var refreshCount = await fake.refreshCallCount
        #expect(refreshCount == 0)

        await fake.setLatestEventID(2)
        let triggered = await store.pollForChanges()
        #expect(triggered == true)
        refreshCount = await fake.refreshCallCount
        #expect(refreshCount == 1)
    }

    @Test func pollForChangesSkipsRefreshWhenLatestEventIDUnchanged() async throws {
        let fake = FakeLiveUpdateKanbanData()
        let store = try makeStore(kanbanData: fake)

        await store.pollForChanges()
        let triggered = await store.pollForChanges()
        #expect(triggered == false)
        let refreshCount = await fake.refreshCallCount
        #expect(refreshCount == 0)
    }

    @Test func pollForChangesIgnoresFailuresWithoutSettingUserFacingError() async throws {
        let fake = FakeLiveUpdateKanbanData()
        await fake.setMode(.failure)
        let store = try makeStore(kanbanData: fake)
        store.errorMessage = nil

        let triggered = await store.pollForChanges()
        #expect(triggered == false)
        #expect(store.errorMessage == nil)
        let refreshCount = await fake.refreshCallCount
        #expect(refreshCount == 0)
    }

    // MARK: - Helpers

    private func makeStore(kanbanData: any KanbanDataReading) throws -> AgentsStore {
        let suffix = UUID().uuidString
        let repo = SettingsRepository(
            suiteName: "AgentsStoreLiveUpdateTests-\(suffix)",
            serviceName: "AgentsStoreLiveUpdateTests-\(suffix)"
        )
        let settings = SettingsStore(repository: repo)
        return try AgentsStore(
            kanbanData: kanbanData,
            cliWriter: NoopCLIWriter(),
            cache: AgentBoardCache(inMemory: true),
            settingsStore: settings
        )
    }
}

// MARK: - Test doubles

private enum FakeLiveUpdateError: Error {
    case boom
}

private actor FakeLiveUpdateKanbanData: KanbanDataReading {
    enum Mode {
        case success
        case failure
    }

    private(set) var refreshCallCount = 0
    private var latestEventID = 1
    private var mode: Mode = .success

    func setLatestEventID(_ id: Int) {
        latestEventID = id
    }

    func setMode(_ newMode: Mode) {
        mode = newMode
    }

    func refresh() async throws -> Bool {
        refreshCallCount += 1
        return true
    }

    func fetchTasks(status _: KanbanStatus?, tenant _: String?, excludeArchived _: Bool) async throws -> [KanbanTask] {
        []
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

    func fetchLatestEventID() async throws -> Int {
        if case .failure = mode {
            throw FakeLiveUpdateError.boom
        }
        return latestEventID
    }

    func fetchEvents(taskID _: String, limit _: Int) async throws -> [KanbanEvent] {
        if case .failure = mode {
            throw FakeLiveUpdateError.boom
        }
        return []
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
