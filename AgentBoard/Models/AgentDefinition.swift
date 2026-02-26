import SwiftUI

struct AgentDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String

    var displayName: String {
        "\(emoji) \(name)"
    }

    static let knownAgents: [AgentDefinition] = [
        .init(id: "", name: "Unassigned", emoji: "📋"),
        .init(id: "daneel", name: "Daneel", emoji: "🤖"),
        .init(id: "quentin", name: "Quentin", emoji: "🔬"),
        .init(id: "argus", name: "Argus", emoji: "⚙️"),
    ]

    static func find(_ id: String) -> AgentDefinition {
        knownAgents.first(where: { $0.id == id }) ?? .init(id: id, name: id, emoji: "🔹")
    }
}
