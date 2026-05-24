import AgentBoardCore
import Testing

@Suite("PRDComposer")
struct PRDComposerTests {
    @Test(arguments: [
        (SessionLauncher.ExecutionPreset.ralphLoop, "Implement Refactor launcher", "Build verify"),
        (.tddSuperpowers, "Write failing tests", "Run full test suite"),
        (.claudeToCodex, "Phase 1: Implementation", "Phase 2: Test Validation"),
        (.codexReview, "Review code quality", "Build verify"),
        (.opencodeSession, "multi-model approach", "Cross-validate")
    ])
    func composeIncludesPresetSpecificTasks(
        preset: SessionLauncher.ExecutionPreset,
        expectedPrimaryText: String,
        expectedSecondaryText: String
    ) {
        let markdown = PRDComposer().compose(config: Self.config(preset: preset))

        #expect(markdown.contains("# PRD: Refactor launcher"))
        #expect(markdown.contains("#107 in jbcrane13/AgentBoard"))
        #expect(markdown.contains(expectedPrimaryText))
        #expect(markdown.contains(expectedSecondaryText))
        #expect(markdown.contains("## Anti-Stall Rules"))
    }

    @Test
    func composeAppendsCustomInstructionsWhenProvided() {
        let markdown = PRDComposer().compose(
            config: Self.config(
                preset: .ralphLoop,
                customInstructions: "Use a tiny fixture and explain the tradeoff."
            )
        )

        #expect(markdown.contains("## Custom Instructions"))
        #expect(markdown.contains("Use a tiny fixture and explain the tradeoff."))
    }

    @Test
    func composeOmitsCustomInstructionsWhenEmpty() {
        let markdown = PRDComposer().compose(config: Self.config(preset: .ralphLoop, customInstructions: ""))

        #expect(!markdown.contains("## Custom Instructions"))
    }

    private static func config(
        preset: SessionLauncher.ExecutionPreset,
        customInstructions: String = ""
    ) -> SessionLauncher.LaunchConfig {
        SessionLauncher.LaunchConfig(
            taskTitle: "Refactor launcher",
            issueNumber: 107,
            repo: "AgentBoard",
            fullRepo: "jbcrane13/AgentBoard",
            preset: preset,
            customInstructions: customInstructions
        )
    }
}
