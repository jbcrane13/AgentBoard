import AgentBoardCore
import Testing

struct DesignSemanticsTests {
    @Test func workBoardColumnTitlesMatchDesignTemplate() {
        #expect(WorkState.open.designColumnTitle == "OPEN")
        #expect(WorkState.inProgress.designColumnTitle == "IN REVIEW")
        #expect(WorkState.done.designColumnTitle == "CLOSED")
    }
}
