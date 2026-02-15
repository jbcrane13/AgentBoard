import XCTest
@testable import AgentBoard

@MainActor
final class AgentBoardSmokeTests: XCTestCase {
    func testProjectSamplesAreAvailable() {
        XCTAssertFalse(Project.samples.isEmpty)
    }

    func testAppStateDefaultsToBoardTabAndSplitPanel() {
        let state = AppState()
        XCTAssertEqual(state.selectedTab, .board)
        XCTAssertEqual(state.rightPanelMode, .split)
    }
}
