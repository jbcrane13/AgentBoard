import Foundation

// MARK: - Models

/// A single slash command with optional subcommands and arguments.
struct SlashCommand: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let usage: String?
    let subcommands: [SlashCommand]
    let arguments: [SlashArgument]

    init(
        name: String,
        description: String,
        usage: String? = nil,
        subcommands: [SlashCommand] = [],
        arguments: [SlashArgument] = []
    ) {
        self.id = "/\(name)"
        self.name = name
        self.description = description
        self.usage = usage ?? "/\(name)"
        self.subcommands = subcommands
        self.arguments = arguments
    }

    var fullName: String { "/\(name)" }
}

struct SlashArgument: Hashable {
    let label: String
    let required: Bool
    let description: String

    init(label: String, required: Bool = false, description: String = "") {
        self.label = label
        self.required = required
        self.description = description
    }

    var placeholder: String {
        required ? "<\(label)>" : "[\(label)]"
    }
}

/// A completion suggestion returned to the UI for autocomplete.
struct SlashCompletion: Identifiable, Hashable {
    let id: String
    let command: String
    let title: String
    let subtitle: String

    init(command: String, title: String, subtitle: String) {
        self.id = command
        self.command = command
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - Command Action

/// The action that should be taken when a slash command is entered.
enum SlashCommandAction: Sendable {
    /// Send the text as a regular chat message (no slash command matched).
    case chat
    /// Execute a built-in slash command with its full resolved text.
    case execute(name: String, arguments: String)
    /// Show an error message to the user.
    case error(message: String)
}

// MARK: - SlashCommandService

@Observable
@MainActor
final class SlashCommandService {

    // MARK: - Registered Commands

    private(set) var commands: [SlashCommand] = []

    // MARK: - Init

    init() {
        registerDefaults()
    }

    // MARK: - Registration

    func register(_ command: SlashCommand) {
        guard !commands.contains(where: { $0.name == command.name }) else { return }
        commands.append(command)
    }

    func replaceCommand(_ command: SlashCommand) {
        commands.removeAll { $0.name == command.name }
        commands.append(command)
    }

    // MARK: - Default Commands

    private func registerDefaults() {
        let defaults: [SlashCommand] = [
            SlashCommand(
                name: "status",
                description: "Show current session and connection status",
                usage: "/status",
                subcommands: [
                    SlashCommand(name: "gateway", description: "Show gateway connection details"),
                    SlashCommand(name: "sessions", description: "List active gateway sessions"),
                    SlashCommand(name: "agent", description: "Show current agent identity"),
                ]
            ),
            SlashCommand(
                name: "issues",
                description: "List and manage GitHub issues",
                usage: "/issues [command]",
                subcommands: [
                    SlashCommand(
                        name: "list",
                        description: "List open issues",
                        arguments: [
                            SlashArgument(label: "label", description: "Filter by label"),
                        ]
                    ),
                    SlashCommand(name: "refresh", description: "Force reload issues from GitHub"),
                    SlashCommand(
                        name: "view",
                        description: "View a specific issue",
                        arguments: [
                            SlashArgument(label: "number", required: true, description: "Issue number"),
                        ]
                    ),
                ]
            ),
            SlashCommand(
                name: "build",
                description: "Run project build commands",
                usage: "/build [target]",
                subcommands: [
                    SlashCommand(name: "run", description: "Build the AgentBoard project"),
                    SlashCommand(name: "clean", description: "Clean the build folder"),
                    SlashCommand(name: "test", description: "Build and run tests"),
                    SlashCommand(name: "lint", description: "Run SwiftLint"),
                ]
            ),
            SlashCommand(
                name: "test",
                description: "Run test suites",
                usage: "/test [suite]",
                subcommands: [
                    SlashCommand(name: "all", description: "Run all tests"),
                    SlashCommand(name: "unit", description: "Run unit tests only"),
                    SlashCommand(name: "ui", description: "Run UI tests only"),
                ]
            ),
            SlashCommand(
                name: "session",
                description: "Manage gateway sessions",
                usage: "/session [action]",
                subcommands: [
                    SlashCommand(name: "list", description: "List all sessions"),
                    SlashCommand(name: "switch", description: "Switch active session",
                                  arguments: [SlashArgument(label: "key", required: true)]),
                    SlashCommand(name: "nudge", description: "Send nudge to current session"),
                ]
            ),
            SlashCommand(
                name: "canvas",
                description: "Canvas panel commands",
                usage: "/canvas [action]",
                subcommands: [
                    SlashCommand(name: "clear", description: "Clear the canvas"),
                    SlashCommand(name: "export", description: "Export canvas content"),
                ]
            ),
            SlashCommand(
                name: "help",
                description: "Show available slash commands",
                usage: "/help [command]",
                arguments: [
                    SlashArgument(label: "command", description: "Command name for details"),
                ]
            ),
        ]
        for cmd in defaults {
            register(cmd)
        }
    }

    // MARK: - Parsing

    /// Returns true if the input starts with `/` and is a valid slash command prefix.
    var inputHasSlashPrefix: Bool = false

    /// Parses the input text and returns the appropriate action.
    func resolve(_ input: String) -> SlashCommandAction {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            return .chat
        }

        let parts = trimmed.dropFirst().split(separator: " ", maxSplits: 1)
        let commandName = String(parts.first ?? "")
        let rest = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

        guard let command = command(matching: commandName) else {
            return .error(message: "Unknown command: /\(commandName). Type /help for available commands.")
        }

        return .execute(name: command.name, arguments: rest)
    }

    /// Find a command by name (prefix-matched, exact preferred).
    func command(matching name: String) -> SlashCommand? {
        // Exact match first
        if let exact = commands.first(where: { $0.name == name }) {
            return exact
        }
        // Prefix match (only if unambiguous)
        let matches = commands.filter { $0.name.hasPrefix(name) }
        return matches.count == 1 ? matches.first : nil
    }

    /// Find a subcommand by name under a given command.
    func subcommand(named name: String, under parent: SlashCommand) -> SlashCommand? {
        return parent.subcommands.first { $0.name == name }
            ?? parent.subcommands.first { $0.name.hasPrefix(name) && parent.subcommands.filter({ $0.name.hasPrefix(name) }).count == 1 }
    }

    // MARK: - Autocomplete

    /// Returns completion suggestions for the current input.
    /// Only returns suggestions when the input starts with `/`.
    func completions(for input: String) -> [SlashCompletion] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return [] }

        let parts = trimmed.dropFirst().split(separator: " ", maxSplits: 1)
        let commandPart = String(parts.first ?? "").lowercased()
        let subcommandPart = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

        // Top-level command completions (no space typed yet, or space but no subcommand partial)
        if parts.count <= 1 || subcommandPart.isEmpty {
            return topLevelCompletions(matching: commandPart)
        }

        // Subcommand completions
        if let parent = command(matching: commandPart) {
            return subcommandCompletions(for: parent, matching: subcommandPart.lowercased())
        }

        return []
    }

    private func topLevelCompletions(matching prefix: String) -> [SlashCompletion] {
        let filtered = commands.filter { command in
            guard !prefix.isEmpty else { return true }
            return command.name.lowercased().hasPrefix(prefix)
        }
        return filtered.map { cmd in
            SlashCompletion(
                command: cmd.fullName,
                title: cmd.fullName,
                subtitle: cmd.description
            )
        }
    }

    private func subcommandCompletions(for parent: SlashCommand, matching prefix: String) -> [SlashCompletion] {
        let filtered = parent.subcommands.filter { sub in
            guard !prefix.isEmpty else { return true }
            return sub.name.lowercased().hasPrefix(prefix)
        }
        return filtered.map { sub in
            SlashCompletion(
                command: "\(parent.fullName) \(sub.name)",
                title: "\(parent.fullName) \(sub.name)",
                subtitle: sub.description
            )
        }
    }

    /// Returns the best completion text to insert when the user selects a completion.
    func completionText(for completion: SlashCompletion, originalInput: String) -> String {
        let trimmed = originalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        let commandPart = String(parts.first ?? "").lowercased()

        // If it's a top-level command, just replace
        if parts.count <= 1 {
            return completion.command
        }

        // Subcommand: keep parent, replace subcommand partial
        return completion.command
    }

    /// Returns help text for a specific command.
    func helpText(for commandName: String) -> String {
        let trimmed = commandName.hasPrefix("/") ? String(commandName.dropFirst()) : commandName
        guard let cmd = command(matching: trimmed) else {
            return "Unknown command: /\(trimmed). Type /help for available commands."
        }

        var lines: [String] = []
        lines.append("\(cmd.fullName) — \(cmd.description)")
        if let usage = cmd.usage {
            lines.append("  Usage: \(usage)")
        }
        if !cmd.subcommands.isEmpty {
            lines.append("  Subcommands:")
            for sub in cmd.subcommands {
                let usageParts = sub.arguments.map { $0.placeholder }.joined(separator: " ")
                let fullUsage = usageParts.isEmpty ? sub.fullName : "\(sub.fullName) \(usageParts)"
                lines.append("    \(fullUsage) — \(sub.description)")
            }
        }
        if !cmd.arguments.isEmpty {
            lines.append("  Arguments:")
            for arg in cmd.arguments {
                let req = arg.required ? "required" : "optional"
                lines.append("    \(arg.label) (\(req)) — \(arg.description)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Returns help text for all commands.
    func helpText() -> String {
        var lines: [String] = ["Available slash commands:"]
        for cmd in commands.sorted(by: { $0.name < $1.name }) {
            lines.append("  \(cmd.fullName) — \(cmd.description)")
            if !cmd.subcommands.isEmpty {
                for sub in cmd.subcommands {
                    let usageParts = sub.arguments.map { $0.placeholder }.joined(separator: " ")
                    let fullUsage = usageParts.isEmpty ? sub.fullName : "\(sub.fullName) \(usageParts)"
                    lines.append("    \(fullUsage) — \(sub.description)")
                }
            }
        }
        lines.append("\nType /help <command> for details.")
        return lines.joined(separator: "\n")
    }
}
