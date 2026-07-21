import AgentBoardCore
import Testing

@Suite("PRDComposer")
struct PRDComposerTests {
    @Test(arguments: [
        (SessionLauncher.ExecutionPreset.ralphLoop, "Implement Refactor launcher", "required quality gates"),
        (.tddSuperpowers, "Write failing tests", "required quality gates"),
        (.claudeToCodex, "Phase 1: Implementation", "Phase 2: Test Validation"),
        (.codexReview, "Review code quality", "missing regression coverage"),
        (.opencodeSession, "multi-model approach", "required quality gates")
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

    @Test
    func composeUsesRepositoryNeutralConstraints() {
        let markdown = PRDComposer().compose(config: Self.config(preset: .tddSuperpowers))

        #expect(markdown.contains("repository-local AGENTS.md"))
        #expect(markdown.contains("repository's own build, lint, typecheck, and test commands"))
        #expect(!markdown.contains("Swift 6"))
        #expect(!markdown.contains("accessibilityIdentifier"))
        #expect(!markdown.contains("xcodebuild"))
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
