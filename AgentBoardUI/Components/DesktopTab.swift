import Foundation

enum DesktopTab: String, CaseIterable, Identifiable {
    case work
    case agents
    case sessions
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .work: "Work"
        case .agents: "Agents"
        case .sessions: "Sessions"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .work: "square.grid.3x3"
        case .agents: "person.3.sequence.fill"
        case .sessions: "bolt.horizontal.circle.fill"
        case .settings: "slider.horizontal.3"
        }
    }
}
