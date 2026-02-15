import SwiftUI

enum OpenClawConnectionState: Sendable {
    case disconnected
    case connecting
    case reconnecting
    case connected
}

extension OpenClawConnectionState {
    var label: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .reconnecting:
            return "Reconnecting"
        case .connected:
            return "Connected"
        }
    }

    var color: Color {
        switch self {
        case .disconnected:
            return .secondary
        case .connecting, .reconnecting:
            return .orange
        case .connected:
            return .green
        }
    }
}
