import AgentBoardCore
import Foundation
import Testing

@Suite("LabelSchema")
struct LabelSchemaTests {
    // MARK: - IssueType

    @Test func issueTypeLabelValueUsesTypePrefix() {
        #expect(IssueType.bug.labelValue == "type:bug")
        #expect(IssueType.feature.labelValue == "type:feature")
        #expect(IssueType.task.labelValue == "type:task")
        #expect(IssueType.epic.labelValue == "type:epic")
        #expect(IssueType.chore.labelValue == "type:chore")
    }

    @Test func issueTypeTitleIsCapitalizedRawValue() {
        for type in IssueType.allCases {
            #expect(type.title == type.rawValue.capitalized)
        }
    }

    @Test func issueTypeIDMatchesRawValue() {
        for type in IssueType.allCases {
            #expect(type.id == type.rawValue)
        }
    }

    @Test func issueTypeDecodesFromRawValue() throws {
        let json = "\"feature\""
        let type = try JSONDecoder().decode(IssueType.self, from: Data(json.utf8))
        #expect(type == .feature)
    }

    // MARK: - AgentName

    @Test func agentNameLabelValueUsesAgentPrefix() {
        #expect(AgentName.daneel.labelValue == "agent:daneel")
        #expect(AgentName.quentin.labelValue == "agent:quentin")
        #expect(AgentName.friend.labelValue == "agent:friend")
        #expect(AgentName.argus.labelValue == "agent:argus")
        #expect(AgentName.dessin.labelValue == "agent:dessin")
    }

    @Test func agentNameAllCasesIncludesAllAgents() {
        let names = Set(AgentName.allCases.map(\.rawValue))
        #expect(names == ["daneel", "quentin", "friend", "argus", "dessin"])
    }

    @Test func agentNameTitleIsCapitalized() {
        #expect(AgentName.daneel.title == "Daneel")
        #expect(AgentName.dessin.title == "Dessin")
    }

    @Test func agentNameDecodesFromRawValue() throws {
        let json = "\"quentin\""
        let agent = try JSONDecoder().decode(AgentName.self, from: Data(json.utf8))
        #expect(agent == .quentin)
    }
}
