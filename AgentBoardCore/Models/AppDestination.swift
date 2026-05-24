import Foundation

public enum AppDestination: String, CaseIterable, Identifiable, Sendable {
    case chat
    case work
    case agents
    case sessions
    case settings

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .chat: "Chat"
        case .work: "Work"
        case .agents: "Agents"
        case .sessions: "Sessions"
        case .settings: "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .work: "square.grid.2x2"
        case .agents: "person.3.sequence"
        case .sessions: "bolt.horizontal.circle"
        case .settings: "slider.horizontal.3"
        }
    }
}
