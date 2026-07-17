@testable import AgentBoardCore
import Testing

/// Full-matrix coverage of `KanbanBoardMove.forDrag`. Hermes only exposes
/// semantic transitions (promote/block/unblock/complete) — there is no
/// generic set-status, so every board column pair must map to exactly the
/// move the CLI supports, or `nil` if the drop is illegal.
@Suite("KanbanBoardMove")
struct KanbanBoardMoveTests {
    /// Key for a (from, to) column pair.
    private struct Pair: Hashable {
        let from: KanbanStatus
        let to: KanbanStatus
    }

    /// Every legal (from, to) pair over `KanbanStatus.boardColumns` and the
    /// move it maps to. Any pair absent from this table is expected to be
    /// illegal (`forDrag` returns `nil`).
    private static let expectedMoves: [Pair: KanbanBoardMove] = [
        Pair(from: .triage, to: .ready): .promote,
        Pair(from: .triage, to: .blocked): .block,
        Pair(from: .triage, to: .done): .complete,
        Pair(from: .todo, to: .ready): .promote,
        Pair(from: .todo, to: .blocked): .block,
        Pair(from: .todo, to: .done): .complete,
        Pair(from: .ready, to: .blocked): .block,
        Pair(from: .ready, to: .done): .complete,
        Pair(from: .running, to: .blocked): .block,
        Pair(from: .running, to: .done): .complete,
        Pair(from: .blocked, to: .ready): .unblock,
        Pair(from: .blocked, to: .done): .complete
    ]

    @Test func fullMatrixMatchesLegalTransitionTable() {
        for from in KanbanStatus.boardColumns {
            for to in KanbanStatus.boardColumns {
                let expected = Self.expectedMoves[Pair(from: from, to: to)]
                let actual = KanbanBoardMove.forDrag(from: from, to: to)
                #expect(
                    actual == expected,
                    "from \(from) to \(to): expected \(String(describing: expected)), got \(String(describing: actual))"
                )
            }
        }
    }

    // MARK: - Named cases

    @Test func promoteFromTriageOrTodoToReady() {
        #expect(KanbanBoardMove.forDrag(from: .triage, to: .ready) == .promote)
        #expect(KanbanBoardMove.forDrag(from: .todo, to: .ready) == .promote)
    }

    @Test func unblockFromBlockedToReady() {
        #expect(KanbanBoardMove.forDrag(from: .blocked, to: .ready) == .unblock)
    }

    @Test func blockFromAnyNonTerminalToBlocked() {
        #expect(KanbanBoardMove.forDrag(from: .triage, to: .blocked) == .block)
        #expect(KanbanBoardMove.forDrag(from: .todo, to: .blocked) == .block)
        #expect(KanbanBoardMove.forDrag(from: .ready, to: .blocked) == .block)
        #expect(KanbanBoardMove.forDrag(from: .running, to: .blocked) == .block)
    }

    @Test func completeFromAnyNonTerminalToDone() {
        #expect(KanbanBoardMove.forDrag(from: .triage, to: .done) == .complete)
        #expect(KanbanBoardMove.forDrag(from: .todo, to: .done) == .complete)
        #expect(KanbanBoardMove.forDrag(from: .ready, to: .done) == .complete)
        #expect(KanbanBoardMove.forDrag(from: .running, to: .done) == .complete)
        #expect(KanbanBoardMove.forDrag(from: .blocked, to: .done) == .complete)
    }

    @Test func sameColumnDropIsIllegal() {
        for status in KanbanStatus.boardColumns {
            #expect(KanbanBoardMove.forDrag(from: status, to: status) == nil)
        }
    }

    @Test func dropIntoRunningIsAlwaysIllegal() {
        for status in KanbanStatus.boardColumns where status != .running {
            #expect(KanbanBoardMove.forDrag(from: status, to: .running) == nil)
        }
    }

    @Test func dropIntoTriageTodoOrArchivedIsAlwaysIllegal() {
        for status in KanbanStatus.boardColumns {
            #expect(KanbanBoardMove.forDrag(from: status, to: .triage) == nil)
            #expect(KanbanBoardMove.forDrag(from: status, to: .todo) == nil)
            #expect(KanbanBoardMove.forDrag(from: status, to: .archived) == nil)
        }
    }

    @Test func doneIsTerminalAndNeverMovesAgain() {
        for status in KanbanStatus.boardColumns {
            #expect(KanbanBoardMove.forDrag(from: .done, to: status) == nil)
        }
    }

    // MARK: - Rejection messages

    @Test func rejectionMessageForRunningExplainsAgentClaim() {
        #expect(
            KanbanBoardMove.rejectionMessage(from: .todo, to: .running)
                == "Tasks enter Running when an agent claims them."
        )
    }

    @Test func rejectionMessageForSameColumnNamesTheColumn() {
        #expect(
            KanbanBoardMove.rejectionMessage(from: .ready, to: .ready)
                == "Task is already in Ready."
        )
    }

    @Test func rejectionMessageForDoneExplainsTerminalState() {
        #expect(
            KanbanBoardMove.rejectionMessage(from: .done, to: .blocked)
                == "Completed tasks can't be moved."
        )
    }
}
