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

// MARK: - Connection Error Classification

enum ConnectionError: Sendable, Equatable {
    case deviceMismatch
    case pairingRequired
    case connectionRefused(String)
    case authFailed
    case generic(String)

    var userMessage: String {
        switch self {
        case .deviceMismatch:
            return "Device pairing failed. Delete ~/.agentboard/device-identity.json and restart AgentBoard."
        case .pairingRequired:
            return "Device pairing required. Run: openclaw devices approve --latest"
        case .connectionRefused(let url):
            return "Cannot reach gateway at \(url). Check that OpenClaw is running."
        case .authFailed:
            return "Authentication failed. Check your gateway token in Settings."
        case .generic(let message):
            return message
        }
    }

    var briefLabel: String {
        switch self {
        case .deviceMismatch:
            return "Device Mismatch"
        case .pairingRequired:
            return "Pairing Required"
        case .connectionRefused:
            return "Connection Refused"
        case .authFailed:
            return "Auth Failed"
        case .generic:
            return "Connection Error"
        }
    }

    /// Whether this error is permanent until the user changes config/state.
    /// Reconnect loops should stop retrying for these.
    var isNonRetryable: Bool {
        switch self {
        case .deviceMismatch, .pairingRequired, .authFailed:
            return true
        case .connectionRefused, .generic:
            return false
        }
    }

    var indicatorColor: Color {
        switch self {
        case .deviceMismatch, .pairingRequired, .authFailed:
            return .red
        case .connectionRefused:
            return .orange
        case .generic:
            return .red
        }
    }

    static func classify(_ error: Error, gatewayURL: String?) -> ConnectionError {
        let message = error.localizedDescription.lowercased()

        if message.contains("device identity mismatch") || message.contains("identity mismatch") {
            return .deviceMismatch
        }
        if message.contains("pairing required") {
            return .pairingRequired
        }
        if message.contains("unauthorized") || message.contains("invalid token") || message.contains("authentication failed") || message.contains("token missing") || message.contains("token_missing") {
            return .authFailed
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .timedOut:
                return .connectionRefused(gatewayURL ?? "unknown")
            default:
                break
            }
        }

        if message.contains("connection refused") || message.contains("could not connect") ||
            message.contains("network is down") || message.contains("no route to host") {
            return .connectionRefused(gatewayURL ?? "unknown")
        }

        return .generic(error.localizedDescription)
    }
}
