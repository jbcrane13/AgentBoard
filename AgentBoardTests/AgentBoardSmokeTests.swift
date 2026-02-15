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

    func testAssistantMessageExtractsUniqueReferencedIssueIDs() {
        let message = ChatMessage(
            role: .assistant,
            content: "Please check AgentBoard-69u and AgentBoard-69u.3, then revisit AgentBoard-69u."
        )

        XCTAssertEqual(message.referencedIssueIDs, ["AgentBoard-69u", "AgentBoard-69u.3"])
    }
}
