import Foundation
import AppKit

enum TerminalApp {
    case iTerm2
    case terminal
}

enum TerminalLauncher {
    /// Detect the preferred terminal app (iTerm2 if available, otherwise Terminal.app)
    static func detectPreferredTerminal() -> TerminalApp {
        let workspace = NSWorkspace.shared
        let iTerm2Path = "/Applications/iTerm.app"

        if FileManager.default.fileExists(atPath: iTerm2Path) {
            return .iTerm2
        }

        // Check if iTerm2 is installed elsewhere
        if workspace.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil {
            return .iTerm2
        }

        return .terminal
    }

    /// Check if tmux is available in PATH
    static func isTmuxAvailable() async -> Bool {
        do {
            _ = try await ShellCommand.runAsync(arguments: ["which", "tmux"])
            return true
        } catch {
            return false
        }
    }

    /// Open a command in the preferred terminal app
    static func openInTerminal(
        command: String,
        workingDirectory: String? = nil,
        terminalApp: TerminalApp? = nil
    ) async throws {
        let app = terminalApp ?? detectPreferredTerminal()

        var fullCommand = command
        if let workingDirectory {
            let escapedPath = shellSingleQuoted(workingDirectory)
            fullCommand = "cd \(escapedPath) && \(command)"
        }

        let script: String
        switch app {
        case .iTerm2:
            script = generateITerm2Script(command: fullCommand)
        case .terminal:
            script = generateTerminalScript(command: fullCommand)
        }

        _ = try await ShellCommand.runAsync(arguments: ["osascript", "-e", script])
    }

    /// Generate AppleScript for iTerm2
    static func generateITerm2Script(command: String) -> String {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return """
        tell application "iTerm"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow
                write text "\(escapedCommand)"
            end tell
        end tell
        """
    }

    /// Generate AppleScript for Terminal.app
    static func generateTerminalScript(command: String) -> String {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """
    }

    /// Shell single-quote a string for safe use in commands
    static func shellSingleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
