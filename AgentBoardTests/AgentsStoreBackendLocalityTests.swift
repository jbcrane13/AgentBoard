@testable import AgentBoardCore
import Foundation
import Testing

/// Contract tests for `AgentsStore`'s locality-driven live-update cadence:
/// 2s for the local SQLite backend, 15s for a remote HTTP dashboard backend
/// (whose `fetchLatestEventID()` is a full board fetch, not a cheap
/// indexed `MAX(id)`), and a ≥30s failure backoff that never undercuts the
/// locality's normal cadence.
@Suite("AgentsStore backend locality")
@MainActor
struct AgentsStoreBackendLocalityTests {
    @Test
    func localLocalityDefaultsToTwoSecondCadence() throws {
        let store = try makeStore(kanbanData: FakeLocalityKanbanData(), backendLocality: .local)
        #expect(store.liveUpdatePollInterval == .seconds(2))
        #expect(store.backendLocality == .local)
    }

    @Test
    func remoteLocalityDefaultsToFifteenSecondCadence() throws {
        let store = try makeStore(kanbanData: FakeLocalityKanbanData(), backendLocality: .remote)
        #expect(store.liveUpdatePollInterval == .seconds(15))
        #expect(store.backendLocality == .remote)
    }

    @Test
    func localFailureBackoffIsAtLeastThirtySecondsAndNotShorterThanNormalCadence() async throws {
        let fake = FakeLocalityKanbanData()
        await fake.setShouldFail(true)
        let store = try makeStore(kanbanData: fake, backendLocality: .local)

        _ = await store.pollForChanges()

        #expect(store.liveUpdatePollInterval >= .seconds(30))
        #expect(store.liveUpdatePollInterval >= .seconds(2))
    }

    @Test
    func remoteFailureBackoffIsAtLeastThirtySecondsAndNotShorterThanNormalCadence() async throws {
        let fake = FakeLocalityKanbanData()
        await fake.setShouldFail(true)
        let store = try makeStore(kanbanData: fake, backendLocality: .remote)

        _ = await store.pollForChanges()

        #expect(store.liveUpdatePollInterval >= .seconds(30))
        #expect(store.liveUpdatePollInterval >= .seconds(15))
    }

    @Test
    func updateBackendSwitchesLocalityAndResetsCadenceAndBaseline() async throws {
        let local = FakeLocalityKanbanData()
        let store = try makeStore(kanbanData: local, backendLocality: .local)

        // Establish a baseline event id on the local backend.
        _ = await store.pollForChanges()

        let remote = FakeLocalityKanbanData()
        await remote.setLatestEventID(99)
        store.updateBackend(remote, writer: NoopLocalityCLIWriter(), locality: .remote)

        #expect(store.backendLocality == .remote)
        #expect(store.liveUpdatePollInterval == .seconds(15))

        // The baseline was reset, so the first poll against the new backend
        // only primes it — it must not fire a refresh by comparing against
        // the old backend's event id.
        let triggered = await store.pollForChanges()
        #expect(triggered == false)
        let refreshCount = await remote.refreshCallCount
        #expect(refreshCount == 0)
    }

    /// Guards against the shape of bug issue #207 fixed for `KanbanCLIWriter`
    /// itself: `updateBackend` must not just overwrite a stored reference
    /// that nothing reads again — every subsequent write has to actually go
    /// through the newly-injected writer. Proven here by injecting two
    /// distinguishable fake writers and checking which one observed the
    /// call, not merely that the store's `backendLocality` flipped.
    @Test
    func updateBackendSwapIsEffectiveNotMerelyStored() async throws {
        let firstWriter = RecordingLocalityCLIWriter()
        let store = try makeStore(
            kanbanData: FakeLocalityKanbanData(),
            backendLocality: .local,
            cliWriter: firstWriter
        )

        let secondWriter = RecordingLocalityCLIWriter()
        store.updateBackend(FakeLocalityKanbanData(), writer: secondWriter, locality: .remote)

        await store.commentOnTask(id: "t1", body: "hello")

        let firstCalls = await firstWriter.commentCalls
        let secondCalls = await secondWriter.commentCalls
        #expect(firstCalls.isEmpty)
        #expect(secondCalls == [RecordingLocalityCLIWriter.CommentCall(taskID: "t1", body: "hello")])
    }

    // MARK: - Helpers

    private func makeStore(
        kanbanData: any KanbanDataReading,
        backendLocality: KanbanBackendLocality,
        cliWriter: any KanbanCLIWriting = NoopLocalityCLIWriter()
    ) throws -> AgentsStore {
        let suffix = UUID().uuidString
        let repo = SettingsRepository(
            suiteName: "AgentsStoreBackendLocalityTests-\(suffix)",
            serviceName: "AgentsStoreBackendLocalityTests-\(suffix)"
        )
        let settings = SettingsStore(repository: repo)
        return try AgentsStore(
            kanbanData: kanbanData,
            cliWriter: cliWriter,
            cache: AgentBoardCache(inMemory: true),
            settingsStore: settings,
            backendLocality: backendLocality
        )
    }
}

// MARK: - Test doubles

private enum FakeLocalityError: Error {
    case boom
}

private actor FakeLocalityKanbanData: KanbanDataReading {
    private(set) var refreshCallCount = 0
    private var latestEventID = 1
    private var shouldFail = false

    func setLatestEventID(_ id: Int) {
        latestEventID = id
    }

    func setShouldFail(_ value: Bool) {
        shouldFail = value
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
        if shouldFail {
            throw FakeLocalityError.boom
        }
        return latestEventID
    }

    func fetchEvents(taskID _: String, limit _: Int) async throws -> [KanbanEvent] {
        if shouldFail {
            throw FakeLocalityError.boom
        }
        return []
    }
}

private struct NoopLocalityCLIWriter: KanbanCLIWriting {
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

/// Records `comment` calls with which instance received them, so
/// `updateBackendSwapIsEffectiveNotMerelyStored` can distinguish "the store
/// still points at the writer injected at construction" from "the store now
/// routes writes through whichever writer `updateBackend` swapped in".
/// An actor, not a plain struct, so concurrent mutation of `commentCalls`
/// stays Swift 6-safe (matches `RecordingWriter` in AgentsStoreMoveTests.swift).
private actor RecordingLocalityCLIWriter: KanbanCLIWriting {
    struct CommentCall: Equatable {
        let taskID: String
        let body: String
    }

    private(set) var commentCalls: [CommentCall] = []

    func create(_ draft: KanbanCreateDraft) async throws -> KanbanTask {
        KanbanTask(id: UUID().uuidString, title: draft.title)
    }

    func comment(taskID: String, body: String) async throws {
        commentCalls.append(CommentCall(taskID: taskID, body: body))
    }

    func complete(taskID _: String, summary _: String) async throws {}
    func block(taskID _: String, reason _: String) async throws {}
    func unblock(taskID _: String) async throws {}
    func promote(taskID _: String) async throws {}
    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}
