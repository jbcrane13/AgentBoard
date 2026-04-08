import SwiftUI

struct AgentDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let githubUsername: String?

    var displayName: String {
        "\(emoji) \(name)"
    }

    static let knownAgents: [AgentDefinition] = [
        .init(id: "", name: "Unassigned", emoji: "📋", githubUsername: nil),
        .init(id: "daneel", name: "Daneel", emoji: "🤖", githubUsername: "jbcrane13"),
        .init(id: "friend", name: "Friend", emoji: "🛠️", githubUsername: nil),
        .init(id: "quentin", name: "Quentin", emoji: "🔬", githubUsername: nil),
        .init(id: "argus", name: "Argus", emoji: "⚙️", githubUsername: nil)
    ]

    static func find(_ id: String) -> AgentDefinition {
        knownAgents.first(where: { $0.id == id }) ?? .init(id: id, name: id, emoji: "🔹", githubUsername: nil)
    }

    /// Map an agent ID to GitHub usernames for the assignees API field.
    static func githubAssignees(for agentID: String) -> [String]? {
        guard !agentID.isEmpty,
              let agent = knownAgents.first(where: { $0.id == agentID }),
              let username = agent.githubUsername else {
            return nil
        }
        return [username]
    }
}
