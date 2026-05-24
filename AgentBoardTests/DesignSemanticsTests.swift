import AgentBoardCore
import Testing

struct DesignSemanticsTests {
    @Test func workBoardColumnTitlesMatchDesignTemplate() {
        #expect(WorkState.ready.designColumnTitle == "READY")
        #expect(WorkState.inProgress.designColumnTitle == "IN PROGRESS")
        #expect(WorkState.blocked.designColumnTitle == "BLOCKED")
        #expect(WorkState.review.designColumnTitle == "REVIEW")
    }

    @Test func currentComparisonDesignUsesGraphiteCopperTokens() {
        #expect(AgentBoardDesignHandoff.name == "AgentBoard Grey")
        #expect(AgentBoardDesignHandoff.primaryAccentHex == "#c97a3e")
        #expect(AgentBoardDesignHandoff.baseSurfaceHex == "#232629")
        #expect(AgentBoardDesignHandoff.textPrimaryHex == "#f1f2f4")
    }
}
