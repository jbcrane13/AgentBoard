@testable import AgentBoardCore
import Foundation
import Testing

/// Contract tests for `AgentsStore.moveTask`, the drag-and-drop entry point
/// for the agent kanban board (issue #143). Hermes exposes only semantic
/// transitions (promote/block/unblock/complete) — there is no generic
/// set-status — so the store must map a drop onto the one legal CLI call,
/// or reject it without ever touching the CLI.
@Suite("AgentsStore.moveTask (issue #143)")
@MainActor
struct AgentsStoreMoveTests {
    @Test func legalPromoteUpdatesStatusAndCallsWriter() async {
        let writer = RecordingWriter(seedTask: makeTask(id: "t1", status: .todo))
        let store = await makeStore(cliWriter: writer)

        await store.moveTask(id: "t1", to: .ready)

        #expect(store.tasks.first(where: { $0.id == "t1" })?.status == .ready)
        let calls = await writer.calls
        #expect(calls == [.promote(taskID: "t1")])
        #expect(store.errorMessage == nil)
    }

    @Test func legalBlockUpdatesStatusAndCallsWriterWithReason() async {
        let writer = RecordingWriter(seedTask: makeTask(id: "t1", status: .ready))
        let store = await makeStore(cliWriter: writer)

        await store.moveTask(id: "t1", to: .blocked)

        #expect(store.tasks.first(where: { $0.id == "t1" })?.status == .blocked)
        let calls = await writer.calls
        #expect(calls == [.block(taskID: "t1", reason: "Blocked from board")])
    }

    @Test func legalUnblockUpdatesStatusAndCallsWriter() async {
        let writer = RecordingWriter(seedTask: makeTask(id: "t1", status: .blocked))
        let store = await makeStore(cliWriter: writer)

        await store.moveTask(id: "t1", to: .ready)

        #expect(store.tasks.first(where: { $0.id == "t1" })?.status == .ready)
        let calls = await writer.calls
        #expect(calls == [.unblock(taskID: "t1")])
    }

    @Test func legalCompleteUpdatesStatusAndCallsWriterWithSummary() async {
        let writer = RecordingWriter(seedTask: makeTask(id: "t1", status: .running))
        let store = await makeStore(cliWriter: writer)

        await store.moveTask(id: "t1", to: .done)

        #expect(store.tasks.first(where: { $0.id == "t1" })?.status == .done)
        let calls = await writer.calls
        #expect(calls == [.complete(taskID: "t1", summary: "Completed from board")])
    }

    @Test func writerFailureRevertsOptimisticUpdateAndSetsError() async {
        let writer = FailingWriter(seedTask: makeTask(id: "t1", status: .todo), message: "hermes timed out")
        let store = await makeStore(cliWriter: writer)

        await store.moveTask(id: "t1", to: .ready)

        #expect(store.tasks.first(where: { $0.id == "t1" })?.status == .todo)
        #expect(store.errorMessage?.contains("hermes timed out") == true)
    }

    @Test func illegalDropNeverCallsWriterAndSetsRejectionMessage() async {
        let writer = RecordingWriter(seedTask: makeTask(id: "t1", status: .todo))
        let store = await makeStore(cliWriter: writer)

        await store.moveTask(id: "t1", to: .running)

        #expect(store.tasks.first(where: { $0.id == "t1" })?.status == .todo)
        let calls = await writer.calls
        #expect(calls.isEmpty)
        #expect(store.statusMessage == "Tasks enter Running when an agent claims them.")
    }

    @Test func illegalSameColumnDropNeverCallsWriter() async {
        let writer = RecordingWriter(seedTask: makeTask(id: "t1", status: .ready))
        let store = await makeStore(cliWriter: writer)

        await store.moveTask(id: "t1", to: .ready)

        let calls = await writer.calls
        #expect(calls.isEmpty)
        #expect(store.statusMessage == "Task is already in Ready.")
    }

    @Test func unknownTaskIdIsANoOp() async {
        let writer = RecordingWriter(seedTask: makeTask(id: "t1", status: .todo))
        let store = await makeStore(cliWriter: writer)

        await store.moveTask(id: "missing", to: .ready)

        let calls = await writer.calls
        #expect(calls.isEmpty)
        #expect(store.tasks.count == 1)
    }

    // MARK: - Helpers

    private func makeTask(id: String, status: KanbanStatus) -> KanbanTask {
        KanbanTask(id: id, title: "Task \(id)", status: status)
    }

    /// Builds a store wired to `cliWriter` and seeds it with the writer's
    /// `create()` response via the public `createTask` API (there is no
    /// internal seam for injecting `tasks` directly).
    private func makeStore(cliWriter: any KanbanCLIWriting) async -> AgentsStore {
        let suffix = UUID().uuidString
        let repo = SettingsRepository(
            suiteName: "AgentsStoreMoveTests-\(suffix)",
            serviceName: "AgentsStoreMoveTests-\(suffix)"
        )
        let settings = SettingsStore(repository: repo)
        let store = AgentsStore(
            kanbanData: KanbanDataService(databasePath: "/dev/null"),
            cliWriter: cliWriter,
            settingsStore: settings
        )
        await store.createTask(KanbanCreateDraft(title: "seed"))
        store.errorMessage = nil
        store.statusMessage = nil
        return store
    }
}

// MARK: - Test doubles

/// Returns a fixed seed task from `create` and records every subsequent
/// write call. Used to assert which CLI verb (if any) a drag maps onto.
private actor RecordingWriter: KanbanCLIWriting {
    enum Call: Equatable {
        case complete(taskID: String, summary: String)
        case block(taskID: String, reason: String)
        case unblock(taskID: String)
        case promote(taskID: String)
    }

    private let seedTask: KanbanTask
    private(set) var calls: [Call] = []

    init(seedTask: KanbanTask) {
        self.seedTask = seedTask
    }

    func create(_: KanbanCreateDraft) async throws -> KanbanTask {
        seedTask
    }

    func comment(taskID _: String, body _: String) async throws {}

    func complete(taskID: String, summary: String) async throws {
        calls.append(.complete(taskID: taskID, summary: summary))
    }

    func block(taskID: String, reason: String) async throws {
        calls.append(.block(taskID: taskID, reason: reason))
    }

    func unblock(taskID: String) async throws {
        calls.append(.unblock(taskID: taskID))
    }

    func promote(taskID: String) async throws {
        calls.append(.promote(taskID: taskID))
    }

    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}

/// Seeds via `create`, then fails every subsequent write call. Used to
/// verify the optimistic-update revert path.
private struct FailingWriter: KanbanCLIWriting {
    let seedTask: KanbanTask
    let message: String

    func create(_: KanbanCreateDraft) async throws -> KanbanTask {
        seedTask
    }

    func comment(taskID _: String, body _: String) async throws {}

    func complete(taskID _: String, summary _: String) async throws {
        throw KanbanCLIWriter.WriteError.commandFailed(message)
    }

    func block(taskID _: String, reason _: String) async throws {
        throw KanbanCLIWriter.WriteError.commandFailed(message)
    }

    func unblock(taskID _: String) async throws {
        throw KanbanCLIWriter.WriteError.commandFailed(message)
    }

    func promote(taskID _: String) async throws {
        throw KanbanCLIWriter.WriteError.commandFailed(message)
    }

    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}
