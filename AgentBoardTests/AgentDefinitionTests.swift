@testable import AgentBoard
import Testing

struct AgentDefinitionTests {
    @Test("githubAssignees returns mapped GitHub username for daneel")
    func githubAssigneesDaneel() {
        let result = AgentDefinition.githubAssignees(for: "daneel")
        #expect(result == ["jbcrane13"])
    }

    @Test("githubAssignees returns nil for empty string (unassigned)")
    func githubAssigneesEmpty() {
        let result = AgentDefinition.githubAssignees(for: "")
        #expect(result == nil)
    }

    @Test("githubAssignees returns nil for unknown agent ID")
    func githubAssigneesUnknown() {
        let result = AgentDefinition.githubAssignees(for: "unknown_agent")
        #expect(result == nil)
    }

    @Test("githubAssignees returns nil for agent with no GitHub username")
    func githubAssigneesQuentin() {
        let result = AgentDefinition.githubAssignees(for: "quentin")
        #expect(result == nil)
    }
}
