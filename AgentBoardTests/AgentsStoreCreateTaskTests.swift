@testable import AgentBoardCore
import Foundation
import Testing

/// Contract tests for `AgentsStore.createTask` that the kanban create sheet
/// relies on (issue #86). The bug was the *view*: `Task { await createTask(...) }`
/// dismissed the sheet before the CLI write resolved, so silent failures left
/// `errorMessage` set on a hidden sheet. The fix moved the dismiss into the
/// awaited continuation and gated it on `errorMessage == nil`.
///
/// These tests cover the store-side contract that gating depends on:
///   - success appends the task and clears `errorMessage`
///   - failure leaves `errorMessage` populated and `tasks` untouched
///   - a retry after failure clears the prior error so the sheet can dismiss
///
/// They do NOT cover the SwiftUI dismiss flow itself (`isPresentingCreateSheet`),
/// which lives in `AgentsScreen.swift` and is only reachable via XCUITest.
@Suite("AgentsStore.createTask wait-for-completion contract (issue #86)")
@MainActor
struct AgentsStoreCreateTaskTests {
    @Test func successAppendsTaskAndClearsStaleErrorMessage() async throws {
        let store = try makeStore(cliWriter: SuccessWriter())
        store.errorMessage = "stale error from earlier refresh"

        await store.createTask(KanbanCreateDraft(title: "Investigate flake"))

        #expect(store.tasks.contains(where: { $0.title == "Investigate flake" }))
        #expect(store.errorMessage == nil)
    }

    @Test func failurePopulatesErrorMessageAndLeavesTasksUntouched() async throws {
        let store = try makeStore(cliWriter: FailingWriter(message: "hermes timed out"))

        await store.createTask(KanbanCreateDraft(title: "Investigate flake"))

        #expect(store.tasks.isEmpty)
        #expect(store.errorMessage?.contains("hermes timed out") == true)
    }

    @Test func retryAfterFailureClearsErrorAndAppendsTask() async throws {
        // The user-facing flow the bug fix unlocked: sheet stays open after a
        // failure, user retries with the same draft, the next write succeeds —
        // `errorMessage` must be cleared so the sheet can dismiss.
        let writer = ToggleWriter()
        let store = try makeStore(cliWriter: writer)

        await store.createTask(KanbanCreateDraft(title: "Investigate flake"))
        #expect(store.errorMessage != nil)
        #expect(store.tasks.isEmpty)

        await writer.flipToSuccess()
        await store.createTask(KanbanCreateDraft(title: "Investigate flake"))

        #expect(store.errorMessage == nil)
        #expect(store.tasks.contains(where: { $0.title == "Investigate flake" }))
    }

    // MARK: - Edge cases

    @Test func successPopulatesStatusMessageWithCreatedTitle() async throws {
        // The view surfaces `statusMessage` as confirmation feedback, so the
        // contract is: a successful create publishes a message that names the
        // task that was just created.
        let store = try makeStore(cliWriter: SuccessWriter())

        await store.createTask(KanbanCreateDraft(title: "Wire dispatcher"))

        #expect(store.statusMessage?.contains("Wire dispatcher") == true)
    }

    @Test func duplicateIdFromCLIUpsertsInPlaceWithoutDuplicates() async throws {
        // Race scenario: a refresh runs concurrently with a create, and the
        // CLI returns a task whose id already exists locally. Upsert must
        // replace the existing entry rather than producing two rows.
        let writer = FixedIdWriter(id: "task-fixed-1")
        let store = try makeStore(cliWriter: writer)

        await store.createTask(KanbanCreateDraft(title: "First write"))
        await store.createTask(KanbanCreateDraft(title: "Second write"))

        let matching = store.tasks.filter { $0.id == "task-fixed-1" }
        #expect(matching.count == 1)
        #expect(matching.first?.title == "Second write")
    }

    @Test func sequentialCreatesPreserveNewestFirstOrdering() async throws {
        // The kanban board renders tasks newest-first within each column, and
        // the upsert path is responsible for that sort. This guards against a
        // regression where a freshly created task lands below older tasks.
        let writer = SequencedSuccessWriter(
            baseDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let store = try makeStore(cliWriter: writer)

        await store.createTask(KanbanCreateDraft(title: "Oldest"))
        await store.createTask(KanbanCreateDraft(title: "Middle"))
        await store.createTask(KanbanCreateDraft(title: "Newest"))

        #expect(store.tasks.map(\.title) == ["Newest", "Middle", "Oldest"])
    }

    // MARK: - Helpers

    private func makeStore(cliWriter: any KanbanCLIWriting) throws -> AgentsStore {
        let suffix = UUID().uuidString
        let repo = SettingsRepository(
            suiteName: "AgentsStoreCreateTaskTests-\(suffix)",
            serviceName: "AgentsStoreCreateTaskTests-\(suffix)"
        )
        let settings = SettingsStore(repository: repo)
        return try AgentsStore(
            kanbanData: KanbanDataService(databasePath: "/dev/null"),
            cliWriter: cliWriter,
            cache: AgentBoardCache(inMemory: true),
            settingsStore: settings
        )
    }
}

// MARK: - Test doubles

private struct SuccessWriter: KanbanCLIWriting {
    func create(_ draft: KanbanCreateDraft) async throws -> KanbanTask {
        KanbanTask(
            id: UUID().uuidString,
            title: draft.title,
            assignee: draft.assignee
        )
    }

    func comment(taskID _: String, body _: String) async throws {}
    func complete(taskID _: String, summary _: String) async throws {}
    func block(taskID _: String, reason _: String) async throws {}
    func unblock(taskID _: String) async throws {}
    func promote(taskID _: String) async throws {}
    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}

private struct FailingWriter: KanbanCLIWriting {
    let message: String

    func create(_: KanbanCreateDraft) async throws -> KanbanTask {
        throw KanbanCLIWriter.WriteError.commandFailed(message)
    }

    func comment(taskID _: String, body _: String) async throws {}
    func complete(taskID _: String, summary _: String) async throws {}
    func block(taskID _: String, reason _: String) async throws {}
    func unblock(taskID _: String) async throws {}
    func promote(taskID _: String) async throws {}
    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}

/// Fails the first `create` call, succeeds after `flipToSuccess()`.
/// Models the retry-after-failure path the issue #86 fix enables.
private actor ToggleWriter: KanbanCLIWriting {
    private var shouldSucceed = false

    func flipToSuccess() {
        shouldSucceed = true
    }

    func create(_ draft: KanbanCreateDraft) async throws -> KanbanTask {
        guard shouldSucceed else {
            throw KanbanCLIWriter.WriteError.commandFailed("hermes failed")
        }
        return KanbanTask(
            id: UUID().uuidString,
            title: draft.title,
            assignee: draft.assignee
        )
    }

    func comment(taskID _: String, body _: String) async throws {}
    func complete(taskID _: String, summary _: String) async throws {}
    func block(taskID _: String, reason _: String) async throws {}
    func unblock(taskID _: String) async throws {}
    func promote(taskID _: String) async throws {}
    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}

/// Always returns a task with the same `id`, regardless of draft. Models the
/// CLI returning a row whose id already exists locally (e.g. after a
/// concurrent refresh).
private struct FixedIdWriter: KanbanCLIWriting {
    let id: String

    func create(_ draft: KanbanCreateDraft) async throws -> KanbanTask {
        KanbanTask(id: id, title: draft.title, assignee: draft.assignee)
    }

    func comment(taskID _: String, body _: String) async throws {}
    func complete(taskID _: String, summary _: String) async throws {}
    func block(taskID _: String, reason _: String) async throws {}
    func unblock(taskID _: String) async throws {}
    func promote(taskID _: String) async throws {}
    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}

/// Returns successful tasks with monotonically increasing `createdAt`
/// timestamps so ordering assertions are deterministic regardless of clock
/// resolution on the test runner.
private actor SequencedSuccessWriter: KanbanCLIWriting {
    private var nextOffset: TimeInterval = 0
    private let baseDate: Date

    init(baseDate: Date) {
        self.baseDate = baseDate
    }

    func create(_ draft: KanbanCreateDraft) async throws -> KanbanTask {
        let createdAt = baseDate.addingTimeInterval(nextOffset)
        nextOffset += 60
        return KanbanTask(
            id: UUID().uuidString,
            title: draft.title,
            assignee: draft.assignee,
            createdAt: createdAt
        )
    }

    func comment(taskID _: String, body _: String) async throws {}
    func complete(taskID _: String, summary _: String) async throws {}
    func block(taskID _: String, reason _: String) async throws {}
    func unblock(taskID _: String) async throws {}
    func promote(taskID _: String) async throws {}
    func archive(taskID _: String) async throws {}
    func assign(taskID _: String, assignee _: String) async throws {}
}
