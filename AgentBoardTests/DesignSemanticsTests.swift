import AgentBoardCore
import Testing

struct DesignSemanticsTests {
    @Test func workBoardColumnTitlesMatchDesignTemplate() {
        #expect(WorkState.open.designColumnTitle == "OPEN")
        #expect(WorkState.inProgress.designColumnTitle == "IN REVIEW")
        #expect(WorkState.done.designColumnTitle == "CLOSED")
    }

    @Test func currentComparisonDesignUsesGraphiteCopperTokens() {
        #expect(AgentBoardDesignHandoff.name == "AgentBoard Grey")
        #expect(AgentBoardDesignHandoff.primaryAccentHex == "#c97a3e")
        #expect(AgentBoardDesignHandoff.baseSurfaceHex == "#232629")
        #expect(AgentBoardDesignHandoff.textPrimaryHex == "#f1f2f4")
    }
}
