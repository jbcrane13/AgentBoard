import Foundation

/// Errors thrown by tmux operations.
public enum TmuxError: LocalizedError, Sendable {
    case launchFailed(String)
    case unsupportedPlatform

    public var errorDescription: String? {
        switch self {
        case let .launchFailed(msg): return "tmux launch failed: \(msg)"
        case .unsupportedPlatform: return "tmux operations are only supported on macOS."
        }
    }
}

/// Protocol-fronted gateway over tmux subprocess invocations. Provided so the
/// caller (SessionLauncher / SessionMonitor) can be unit-tested with an
/// in-memory fake instead of spawning real /opt/homebrew/bin/tmux. The
/// production conformer is `LiveTmuxController`.
public protocol TmuxControlling: Sendable {
    /// Spawn a detached tmux session that runs `ralphy --<agent> --prd <path>`
    /// inside the named repo's working directory.
    func launchSession(
        name: String,
        repoPath: String,
        agentLaunchFlag: String,
        prdPath: String
    ) async throws

    /// Returns true if a tmux session with the given name is currently alive.
    /// Throws when tmux probing itself fails so callers can distinguish a
    /// completed session from an unhealthy tmux/socket environment.
    func hasSession(name: String) async throws -> Bool

    /// Capture the visible content of a tmux session pane, or `nil` if the
    /// session is gone or capture failed.
    func capturePane(name: String) async -> String?

    /// Open the named tmux session in the system Terminal.app. Synchronous,
    /// fire-and-forget — used to give the user an interactive view.
    func openInTerminal(name: String)
}

/// Live tmux subprocess implementation backed by `/opt/homebrew/bin/tmux`.
public actor LiveTmuxController: TmuxControlling {
    public static let tmuxExecutablePath = "/opt/homebrew/bin/tmux"

    public static var tmuxSocketPath: String {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".tmux/sock")
            .path
    }

    public static func attachCommand(for sessionName: String) -> (executable: String, arguments: [String]) {
        (tmuxExecutablePath, ["-S", tmuxSocketPath, "attach", "-t", sessionName])
    }

    public init() {}

    public func launchSession(
        name: String,
        repoPath: String,
        agentLaunchFlag: String,
        prdPath: String
    ) async throws {
        #if os(macOS)
            let socket = Self.tmuxSocketPath
            let shellEnv = await ShellEnvironment.enrichedEnvironment()

            let shellCmd = "\(Self.tmuxExecutablePath) -S \(socket) new -d -s \(name)" +
                " \"cd \(repoPath)" +
                " && unset ANTHROPIC_API_KEY" +
                " && /opt/homebrew/bin/ralphy --\(agentLaunchFlag) --prd \(prdPath)" +
                "; EXIT_CODE=\\$?; echo EXITED: \\$EXIT_CODE; sleep 999999\""

            let result: ProcessResult
            do {
                result = try await Process.runAsync(
                    executablePath: "/bin/zsh",
                    arguments: ["-l", "-c", shellCmd],
                    environment: shellEnv
                )
            } catch let ProcessRunError.launchFailed(msg) {
                throw TmuxError.launchFailed(msg)
            }

            if !result.succeeded {
                let output = result.stderrString.isEmpty ? result.stdoutString : result.stderrString
                throw TmuxError.launchFailed(output.isEmpty ? "unknown error" : output)
            }
        #else
            throw TmuxError.unsupportedPlatform
        #endif
    }

    public func hasSession(name: String) async throws -> Bool {
        #if os(macOS)
            let result: ProcessResult
            do {
                result = try await Process.runAsync(
                    executablePath: Self.tmuxExecutablePath,
                    arguments: ["-S", Self.tmuxSocketPath, "has-session", "-t", name],
                    environment: await ShellEnvironment.enrichedEnvironment()
                )
            } catch let ProcessRunError.launchFailed(msg) {
                throw TmuxError.launchFailed(msg)
            } catch {
                throw error
            }
            return result.succeeded
        #else
            throw TmuxError.unsupportedPlatform
        #endif
    }

    public func capturePane(name: String) async -> String? {
        #if os(macOS)
            do {
                let result = try await Process.runAsync(
                    executablePath: Self.tmuxExecutablePath,
                    arguments: ["-S", Self.tmuxSocketPath, "capture-pane", "-t", name, "-p", "-J"],
                    environment: await ShellEnvironment.enrichedEnvironment()
                )
                guard result.succeeded else { return nil }
                return result.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return nil
            }
        #else
            return nil
        #endif
    }

    public nonisolated func openInTerminal(name: String) { // swiftlint:disable:this modifier_order
        #if os(macOS)
            let socket = Self.tmuxSocketPath
            let cmd = "source ~/.zshrc 2>/dev/null; \(Self.tmuxExecutablePath) -S \(socket) attach -t \(name)"

            let appleScript = """
            tell application "Terminal"
                activate
                do script "\(cmd)"
            end tell
            """

            let scriptProcess = Process()
            scriptProcess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            scriptProcess.arguments = ["-e", appleScript]

            try? scriptProcess.run()
        #endif
    }
}
