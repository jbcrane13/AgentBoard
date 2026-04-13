import SwiftUI

struct AgentDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let githubUsername: String?
    let color: Color
    let role: String

    /// Agent initials for compact display (e.g., "DA" for Daneel)
    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1)) + String(words[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    var displayName: String {
        "\(emoji) \(name)"
    }

    /// Background color for agent badges (darker variant)
    var backgroundColor: Color {
        color.opacity(0.15)
    }

    /// GitHub label for agent assignment (e.g. "agent:daneel").
    var agentLabel: String? {
        id.isEmpty ? nil : "agent:\(id)"
    }

    static let knownAgents: [AgentDefinition] = [
        .init(id: "", name: "Unassigned", emoji: "📋", githubUsername: nil, color: .gray, role: "Not assigned"),
        .init(id: "daneel", name: "Daneel", emoji: "🤖", githubUsername: "jbcrane13", color: Color(hex: "4A9EE0"), role: "Main assistant"),
        .init(id: "friend", name: "Friend", emoji: "🛠️", githubUsername: "jbcrane13", color: Color(hex: "F0A030"), role: "Coding lead"),
        .init(id: "quentin", name: "Quentin", emoji: "🔬", githubUsername: "jbcrane13", color: Color(hex: "D46090"), role: "QA lead"),
        .init(id: "argus", name: "Argus", emoji: "⚙️", githubUsername: "jbcrane13", color: Color(hex: "22B882"), role: "Sys ops")
    ]

    static func find(_ id: String) -> AgentDefinition {
        knownAgents.first(where: { $0.id == id }) ?? .init(id: id, name: id, emoji: "🔹", githubUsername: nil, color: .gray, role: "Unknown")
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

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var intVal: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&intVal)
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, red, green, blue) = (255, (intVal >> 8) * 17, (intVal >> 4 & 0xF) * 17, (intVal & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, red, green, blue) = (255, intVal >> 16, intVal >> 8 & 0xFF, intVal & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, red, green, blue) = (intVal >> 24, intVal >> 16 & 0xFF, intVal >> 8 & 0xFF, intVal & 0xFF)
        default:
            (alpha, red, green, blue) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}