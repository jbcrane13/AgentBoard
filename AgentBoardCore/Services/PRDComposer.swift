import Foundation

/// Builds the Markdown PRD that gets handed to a freshly-launched agent
/// session. Pure value-producing struct — no I/O, easy to unit-test, and
/// the right home for a future data-driven preset registry.
public struct PRDComposer: Sendable {
    public init() {}

    public func compose(config: SessionLauncher.LaunchConfig) -> String {
        var prd = """
        # PRD: \(config.taskTitle)

        ## Issue
        #\(config.issueNumber) in \(config.fullRepo)

        """

        prd += taskSection(for: config)

        prd += """
        ## Constraints
        - Swift 6 strict concurrency
        - @Observable not ObservableObject
        - accessibilityIdentifier on every interactive element

        ## Anti-Stall Rules
        - Never wait for input. Never pause for confirmation. Keep moving.
        - When done: commit, push to feature branch, STOP.
        - Report: "DONE: [accomplished] | BLOCKED: [anything open]"
        """

        if !config.customInstructions.isEmpty {
            prd += "\n## Custom Instructions\n\(config.customInstructions)\n"
        }

        return prd
    }

    // MARK: - Per-preset task sections

    private func taskSection(for config: SessionLauncher.LaunchConfig) -> String {
        switch config.preset {
        case .ralphLoop:
            return """
            ## Tasks
            - [ ] Implement \(config.taskTitle)
            - [ ] Handle edge cases and error states
            - [ ] Add accessibilityIdentifier to every interactive element
            - [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build

            """
        case .tddSuperpowers:
            return """
            ## Tasks
            - [ ] Write failing tests that define expected behavior
            - [ ] Implement \(config.taskTitle) to pass tests
            - [ ] Handle edge cases
            - [ ] Add accessibilityIdentifier to every interactive element
            - [ ] Run full test suite — all tests must pass

            """
        case .claudeToCodex:
            return """
            ## Phase 1: Implementation (Claude Code)
            - [ ] Implement \(config.taskTitle)
            - [ ] Handle edge cases
            - [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build
            - [ ] Commit to feature branch

            ## Phase 2: Test Validation (Codex — auto-handoff)
            - [ ] Run full test suite
            - [ ] Add missing tests if coverage gaps found
            - [ ] Run linter — no new warnings
            - [ ] Report results

            """
        case .codexReview:
            return """
            ## Tasks
            - [ ] Implement \(config.taskTitle)
            - [ ] Run full test suite
            - [ ] Review code quality and suggest improvements
            - [ ] Add accessibilityIdentifier to every interactive element
            - [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build

            """
        case .opencodeSession:
            return """
            ## Tasks
            - [ ] Analyze codebase for \(config.taskTitle)
            - [ ] Implement with multi-model approach
            - [ ] Cross-validate with different models
            - [ ] Add accessibilityIdentifier to every interactive element
            - [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build

            """
        }
    }
}
