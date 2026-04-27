import Foundation

public enum AgentBoardDesignTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue
    case grey

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .blue: "Blue"
        case .grey: "Grey"
        }
    }

    public var primaryAccentHex: String {
        switch self {
        case .blue: "#1bbfa6"
        case .grey: "#c97a3e"
        }
    }
}
