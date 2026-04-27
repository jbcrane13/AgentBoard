import AgentBoardCore
import Testing

struct DesignSemanticsTests {
    @Test func workBoardColumnTitlesMatchDesignTemplate() {
        #expect(WorkState.ready.designColumnTitle == "READY")
        #expect(WorkState.inProgress.designColumnTitle == "IN PROGRESS")
        #expect(WorkState.blocked.designColumnTitle == "BLOCKED")
        #expect(WorkState.review.designColumnTitle == "REVIEW")
    }
}
