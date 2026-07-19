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

    // MARK: - Assignees patch edge cases

    @Test func assigneesPatchWithNoAgentLeavesAssigneesUntouched() {
        // Sending [] in a PATCH clears assignees set outside the app —
        // "no agent picked" must omit the field entirely.
        #expect(AgentName.assigneesPatch(for: nil, existing: ["blake"]) == nil)
        #expect(AgentName.assigneesPatch(for: nil, existing: []) == nil)
    }

    @Test func assigneesPatchAddsAgentWhenNoneAssigned() {
        #expect(AgentName.assigneesPatch(for: .daneel, existing: []) == ["jbcrane13"])
    }

    @Test func assigneesPatchPreservesExternalAssignees() {
        // An assignee added via the GitHub web UI must survive picking an agent.
        #expect(
            AgentName.assigneesPatch(for: .daneel, existing: ["octocat"])
                == ["octocat", "jbcrane13"]
        )
    }

    @Test func assigneesPatchDoesNotDuplicateExistingAssignment() {
        #expect(
            AgentName.assigneesPatch(for: .daneel, existing: ["jbcrane13"])
                == ["jbcrane13"]
        )
    }

    @Test func assigneesPatchMatchesLoginsCaseInsensitively() {
        // GitHub logins are case-insensitive; "JBCrane13" is already assigned.
        #expect(
            AgentName.assigneesPatch(for: .daneel, existing: ["JBCrane13"])
                == ["JBCrane13"]
        )
    }

    // MARK: - UI call-site pins

    @Test func createIssueSheetForwardsPickedAgentAsAssignee() throws {
        let source = try readUISource("Screens/CreateIssueSheet.swift")
        #expect(
            !source.contains("assignees: [],"),
            "create() still hardcodes an empty assignees array"
        )
        #expect(
            source.contains("AgentName.assigneesPatch(for: selectedAgent, existing: [])"),
            "create() does not route the picked agent through assigneesPatch"
        )
    }

    @Test func issueDetailSheetForwardsPickedAgentAsAssignee() throws {
        let source = try readUISource("Screens/IssueDetailSheet.swift")
        #expect(
            !source.contains("assignees: [],"),
            "save() still hardcodes an empty assignees array"
        )
        #expect(
            source.contains("AgentName.assigneesPatch(for: editAgent, existing: item.assignees)"),
            "save() must merge the picked agent with the issue's existing assignees"
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
