import Foundation

/// Category of a slash command — determines how it is processed.
public enum SlashCommandCategory: String, Sendable, CaseIterable {
    /// Handled entirely within the app; never reaches Hermes.
    case local
    /// Sent as-is to the Hermes gateway for processing.
    case passthrough
    /// Installed by a Hermes skill at runtime.
    case skill
}

/// A single slash command definition for registry and autocomplete.
public struct SlashCommand: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let category: SlashCommandCategory
    public let usage: String

    public init(
        name: String,
        description: String,
        category: SlashCommandCategory,
        usage: String? = nil
    ) {
        id = name
        self.name = name
        self.description = description
        self.category = category
        self.usage = usage ?? name
    }
}

/// Result of parsing a slash command.
public enum SlashCommandResult: Sendable, Equatable {
    case newConversation
    case clearConversation
    case switchModel(String)
    case showHelp
    case showStatus
    case showConfig
    case showSkills
    case activateSkill(String)
    case showMemory
    case showTools
    case toggleThinking
    case toggleWeb
    case toggleCode
    case toggleImage
    case toggleSpeak
    case resetConversation
    case handled(String)
    case unknown(String)
    case passthrough
}

/// Handles `/` commands locally before they reach Hermes.
/// Mirrors the Telegram gateway command set and supports skill-installed commands.
public enum SlashCommandHandler: Sendable {
    // MARK: - Command Registry

    private static let localCommands: Set<String> = [
        "/help", "/commands", "/new", "/clear",
        "/model", "/status", "/config",
        "/skills", "/memory", "/tools",
        "/think", "/web", "/code", "/image", "/speak", "/reset"
    ]

    private static let passthroughCommands: Set<String> = [
        "/retry", "/compress", "/stop", "/compact",
        "/skill"
    ]

    /// All built-in commands (local + passthrough). Skill commands are appended dynamically.
    public static let builtInCommands: [SlashCommand] = {
        let local: [SlashCommand] = [
            SlashCommand(name: "/help", description: "Show available commands", category: .local),
            SlashCommand(name: "/commands", description: "Show available commands", category: .local),
            SlashCommand(name: "/new", description: "Start a new conversation", category: .local),
            SlashCommand(name: "/clear", description: "Clear current conversation", category: .local),
            SlashCommand(
                name: "/model",
                description: "Switch model (omit name to see current)",
                category: .local,
                usage: "/model <name>"
            ),
            SlashCommand(name: "/status", description: "Show connection status", category: .local),
            SlashCommand(name: "/config", description: "Show current configuration", category: .local),
            SlashCommand(name: "/skills", description: "List available Hermes skills", category: .local),
            SlashCommand(
                name: "/skill",
                description: "Activate a Hermes skill",
                category: .passthrough,
                usage: "/skill <name>"
            ),
            SlashCommand(name: "/memory", description: "Show agent memory / context", category: .local),
            SlashCommand(name: "/tools", description: "List available agent tools", category: .local),
            SlashCommand(name: "/think", description: "Toggle deep thinking mode", category: .local),
            SlashCommand(name: "/web", description: "Toggle web search capability", category: .local),
            SlashCommand(name: "/code", description: "Toggle code execution", category: .local),
            SlashCommand(name: "/image", description: "Toggle image generation", category: .local),
            SlashCommand(name: "/speak", description: "Toggle voice / TTS output", category: .local),
            SlashCommand(name: "/reset", description: "Reset conversation context", category: .local),
            SlashCommand(name: "/retry", description: "Retry last response", category: .passthrough),
            SlashCommand(name: "/compress", description: "Compress conversation context", category: .passthrough),
            SlashCommand(name: "/stop", description: "Stop current response", category: .passthrough),
            SlashCommand(name: "/compact", description: "Compact conversation history", category: .passthrough)
        ]
        return local
    }()

    /// All commands including any skill-installed commands provided at call time.
    public static func allCommands(skills: [SlashCommand] = []) -> [SlashCommand] {
        builtInCommands + skills
    }

    /// Filter commands matching a typed prefix (e.g. "/st" → ["/status", "/stop"]).
    public static func commands(matching prefix: String, skills: [SlashCommand] = []) -> [SlashCommand] {
        let lowered = prefix.lowercased()
        return allCommands(skills: skills).filter { $0.name.lowercased().hasPrefix(lowered) }
    }

    // MARK: - Command Handling

    // swiftlint:disable:next cyclomatic_complexity
    public static func handle(_ text: String) -> SlashCommandResult {
        guard text.hasPrefix("/") else { return .passthrough }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = trimmed.split(separator: " ", maxSplits: 1)
        let command = String(parts[0]).lowercased()
        let argument = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        // Passthrough commands are forwarded to the agent as-is
        if passthroughCommands.contains(command) {
            // /skill <name> is a passthrough but we also track activation locally
            if command == "/skill", !argument.isEmpty {
                return .activateSkill(argument)
            }
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

        case "/skills":
            return .showSkills

        case "/memory":
            return .showMemory

        case "/tools":
            return .showTools

        case "/think":
            return .toggleThinking

        case "/web":
            return .toggleWeb

        case "/code":
            return .toggleCode

        case "/image":
            return .toggleImage

        case "/speak":
            return .toggleSpeak

        case "/reset":
            return .resetConversation

        default:
            return .unknown(command)
        }
    }

    // MARK: - Formatted Output

    /// Formatted help text listing all available commands.
    public static func formatHelp(skills: [SlashCommand] = []) -> String {
        var sections: [String] = []

        sections.append("**AgentBoard Commands**")
        sections.append("")

        let localCmds = allCommands(skills: skills).filter { $0.category == .local }
        sections.append("**Local Commands:**")
        for cmd in localCmds {
            sections.append("`\(cmd.usage)` — \(cmd.description)")
        }

        sections.append("")
        let passCmds = allCommands(skills: skills).filter { $0.category == .passthrough }
        sections.append("**Gateway Commands (forwarded to agent):**")
        for cmd in passCmds {
            sections.append("`\(cmd.usage)` — \(cmd.description)")
        }

        let skillCmds = skills.filter { $0.category == .skill }
        if !skillCmds.isEmpty {
            sections.append("")
            sections.append("**Skill Commands:**")
            for cmd in skillCmds {
                sections.append("`\(cmd.usage)` — \(cmd.description)")
            }
        }

        return sections.joined(separator: "\n")
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

    /// Formatted skills listing.
    public static func formatSkills(_ skills: [SlashCommand]) -> String {
        if skills.isEmpty {
            return "**Skills**\n\nNo skills currently installed. Use `/skill <name>` to activate a skill."
        }

        var lines = ["**Installed Skills**", ""]
        for skill in skills {
            lines.append("`/\(skill.name)` — \(skill.description)")
        }
        lines.append("")
        lines.append("Use `/skill <name>` to activate a skill.")
        return lines.joined(separator: "\n")
    }

    /// Formatted memory display.
    public static func formatMemory(
        contextLength: Int,
        maxContext: Int,
        summary: String?
    ) -> String {
        var lines = [
            "**Agent Memory**",
            "",
            "**Context:** \(contextLength) / \(maxContext) tokens"
        ]
        if let summary {
            lines.append("")
            lines.append("**Summary:** \(summary)")
        }
        return lines.joined(separator: "\n")
    }

    /// Formatted tools listing.
    public static func formatTools(_ tools: [String]) -> String {
        if tools.isEmpty {
            return "**Tools**\n\nNo tools currently available."
        }

        var lines = ["**Available Tools**", ""]
        for tool in tools {
            lines.append("  · \(tool)")
        }
        return lines.joined(separator: "\n")
    }
}
