import AgentBoardCore
import Testing

@Suite("WorkBoardColumn")
struct WorkBoardColumnTests {
    @Test func readyMapsToTodo() {
        #expect(WorkBoardColumn.column(for: .ready) == .todo)
    }

    @Test func inProgressReviewAndBlockedMapToInProgress() {
        #expect(WorkBoardColumn.column(for: .inProgress) == .inProgress)
        #expect(WorkBoardColumn.column(for: .review) == .inProgress)
        #expect(WorkBoardColumn.column(for: .blocked) == .inProgress)
    }

    @Test func doneMapsToResolved() {
        #expect(WorkBoardColumn.column(for: .done) == .resolved)
    }

    @Test func everyWorkStateMapsToExactlyOneColumn() {
        for state in WorkState.allCases {
            let column = WorkBoardColumn.column(for: state)
            #expect(WorkBoardColumn.allCases.contains(column))
        }
    }

    @Test func dropTargetStatesMatchColumnMapping() {
        #expect(WorkBoardColumn.todo.dropTargetState == .ready)
        #expect(WorkBoardColumn.inProgress.dropTargetState == .inProgress)
        #expect(WorkBoardColumn.resolved.dropTargetState == .done)
    }

    @Test func dropTargetStateAlwaysMapsBackToItsOwnColumn() {
        for column in WorkBoardColumn.allCases {
            #expect(WorkBoardColumn.column(for: column.dropTargetState) == column)
        }
    }

    @Test func titlesMatchThreeColumnSpec() {
        #expect(WorkBoardColumn.todo.title == "To Do")
        #expect(WorkBoardColumn.inProgress.title == "In Progress")
        #expect(WorkBoardColumn.resolved.title == "Resolved")
    }
}
