import Foundation

enum ChatBackend: String, CaseIterable, Codable, Sendable, Identifiable {
    case hermes
    case openClaw

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .hermes:
            return "Hermes"
        case .openClaw:
            return "OpenClaw"
        }
    }

    var shortDescription: String {
        switch self {
        case .hermes:
            return "HTTP + SSE gateway chat"
        case .openClaw:
            return "WebSocket JSON-RPC sessions"
        }
    }

    static var platformDefault: ChatBackend {
        #if os(iOS)
            return .hermes
        #else
            return .openClaw
        #endif
    }
}
