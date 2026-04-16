import Foundation

/// Agent that can be assigned to tasks
public struct Agent: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let role: String
    public let avatar: String?
    
    public init(id: String = UUID().uuidString, name: String, role: String, avatar: String? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.avatar = avatar
    }
    
    /// Default agents for assignment
    public static let defaultAgents: [Agent] = [
        Agent(id: "hermes", name: "Hermes", role: "Operations Agent"),
        Agent(id: "claude", name: "Claude Code", role: "Coding Agent"),
        Agent(id: "codex", name: "Codex", role: "Coding Agent"),
        Agent(id: "opencode", name: "OpenCode", role: "Coding Agent")
    ]
    
    /// Get agent by ID
    public static func agent(withId id: String) -> Agent? {
        defaultAgents.first { $0.id == id }
    }
    
    /// Get agent display name
    public var displayName: String {
        "\(name) (\(role))"
    }
}
