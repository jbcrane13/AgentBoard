import AgentBoardCore
import Foundation
import Testing

/// Failing-first tests for issue #12: the agent picker in the issue create
/// and edit forms sets a draft agent, but that selection never reaches the
/// GitHub `assignees` field. These pin the expected behavior — a real
/// agent → GitHub username mapping on `AgentName`, and both UI call sites
/// forwarding the picked agent instead of a hardcoded empty array.
@Suite("GitHub assignee forwarding (issue #12)")
struct GitHubAssigneeForwardingTests {
    // MARK: - Agent → GitHub username mapping

    @Test func daneelMapsToRepoOwnerGitHubUsername() {
        // Issue #12 names the mapping explicitly: daneel → jbcrane13.
        #expect(AgentName.daneel.githubUsername == "jbcrane13")
    }

    @Test func everyAgentMapsToANonEmptyGitHubUsername() {
        // An empty assignee login would make the GitHub API call fail or
        // silently no-op — every known agent must resolve to a real login.
        for agent in AgentName.allCases {
            #expect(
                !agent.githubUsername.isEmpty,
                "\(agent.rawValue) has no GitHub username mapping"
            )
        }
    }

    // MARK: - UI call-site pins

    @Test func createIssueSheetForwardsPickedAgentAsAssignee() throws {
        let source = try readUISource("Screens/CreateIssueSheet.swift")
        #expect(
            !source.contains("assignees: [],"),
            "create() still hardcodes an empty assignees array"
        )
        #expect(
            source.contains("githubUsername"),
            "create() does not map the picked agent to a GitHub username"
        )
    }

    @Test func issueDetailSheetForwardsPickedAgentAsAssignee() throws {
        let source = try readUISource("Screens/IssueDetailSheet.swift")
        #expect(
            !source.contains("assignees: [],"),
            "save() still hardcodes an empty assignees array"
        )
        #expect(
            source.contains("githubUsername"),
            "save() does not map the picked agent to a GitHub username"
        )
    }

    // MARK: - Helpers

    private func readUISource(_ relativePath: String) throws -> String {
        let url = repoRoot
            .appendingPathComponent("AgentBoardUI")
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var repoRoot: URL {
        // This file lives at <repo>/AgentBoardTests/GitHubAssigneeForwardingTests.swift.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
