import Foundation

/// Result of parsing a slash command.
public enum SlashCommandResult: Sendable {
    case newConversation
    case clearConversation
    case switchModel(String)
    case showHelp
    case showStatus
    case showConfig
    case handled(String)
    case unknown(String)
    case passthrough
}

/// Handles `/` commands locally before they reach Hermes.
/// Mirrors the Telegram gateway command set.
public enum SlashCommandHandler: Sendable {
    private static let localCommands: Set<String> = [
        "/help", "/commands", "/new", "/clear",
        "/model", "/status", "/config"
    ]

    private static let passthroughCommands: Set<String> = [
        "/retry", "/compress", "/stop", "/compact"
    ]

    /// Parse and handle a slash command from user input.
    public static func handle(_ text: String) -> SlashCommandResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return .passthrough }

        let parts = trimmed.split(separator: " ", maxSplits: 1)
        let command = String(parts[0]).lowercased()
        let argument = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        if passthroughCommands.contains(command) {
            return .passthrough
        }

        switch command {
        case "/help", "/commands":
            return .showHelp

        case "/new":
            return .newConversation

        case "/clear":
            return .clearConversation

        case "/model":
            if argument.isEmpty {
                return .showStatus
            }
            return .switchModel(argument)

        case "/status":
            return .showStatus

        case "/config":
            return .showConfig

        default:
            return .unknown(command)
        }
    }

    /// Formatted help text listing all available commands.
    public static func formatHelp() -> String {
        """
        **AgentBoard Commands**

        `/help` — Show this help
        `/new` — Start a new conversation
        `/clear` — Clear current conversation
        `/model <name>` — Switch model (omit name to see current)
        `/status` — Show connection status
        `/config` — Show current configuration
        `/commands` — Show this help

        Other commands (`/retry`, `/stop`, etc.) are forwarded to the agent.
        """
    }

    /// Formatted status display.
    public static func formatStatus(
        connectionState: String,
        model: String,
        conversationTitle: String,
        messageCount: Int
    ) -> String {
        """
        **Connection Status**

        **State:** \(connectionState)
        **Model:** \(model)
        **Session:** \(conversationTitle)
        **Messages:** \(messageCount)
        """
    }

    /// Formatted configuration display.
    public static func formatConfig(
        gatewayURL: String,
        model: String,
        hasAPIKey: Bool,
        repos: [String]
    ) -> String {
        var lines = [
            "**Configuration**",
            "",
            "**Gateway:** \(gatewayURL)",
            "**Model:** \(model)",
            "**API Key:** \(hasAPIKey ? "Set" : "Not set")"
        ]

        if !repos.isEmpty {
            lines.append("")
            lines.append("**Repositories:**")
            for repo in repos {
                lines.append("  · \(repo)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
