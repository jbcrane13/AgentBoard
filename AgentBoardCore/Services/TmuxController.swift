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

    /// Sends a literal line of text to the session followed by Enter (nudge).
    /// The literal `-l` send and the Enter keypress are two separate
    /// `send-keys` invocations so Enter isn't interpreted as literal text.
    func sendKeys(name: String, text: String) async throws

    /// Kills the named tmux session outright.
    func killSession(name: String) async throws
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

    /// Pure argument builder for `sendKeys` — two separate `send-keys` calls so
    /// the Enter keypress is never sent inside the literal (`-l`) invocation.
    public static func sendKeysArguments(for sessionName: String, text: String) -> [[String]] {
        [
            ["-S", tmuxSocketPath, "send-keys", "-t", sessionName, "-l", text],
            ["-S", tmuxSocketPath, "send-keys", "-t", sessionName, "Enter"]
        ]
    }

    /// Pure argument builder for `killSession`.
    public static func killSessionArguments(for sessionName: String) -> [String] {
        ["-S", tmuxSocketPath, "kill-session", "-t", sessionName]
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

    public func sendKeys(name: String, text: String) async throws {
        #if os(macOS)
            let environment = await ShellEnvironment.enrichedEnvironment()
            for arguments in Self.sendKeysArguments(for: name, text: text) {
                let result: ProcessResult
                do {
                    result = try await Process.runAsync(
                        executablePath: Self.tmuxExecutablePath,
                        arguments: arguments,
                        environment: environment
                    )
                } catch let ProcessRunError.launchFailed(msg) {
                    throw TmuxError.launchFailed(msg)
                }
                guard result.succeeded else {
                    let output = result.stderrString.isEmpty ? result.stdoutString : result.stderrString
                    throw TmuxError.launchFailed(output.isEmpty ? "unknown error" : output)
                }
            }
        #else
            throw TmuxError.unsupportedPlatform
        #endif
    }

    public func killSession(name: String) async throws {
        #if os(macOS)
            let result: ProcessResult
            do {
                result = try await Process.runAsync(
                    executablePath: Self.tmuxExecutablePath,
                    arguments: Self.killSessionArguments(for: name),
                    environment: await ShellEnvironment.enrichedEnvironment()
                )
            } catch let ProcessRunError.launchFailed(msg) {
                throw TmuxError.launchFailed(msg)
            }
            guard result.succeeded else {
                let output = result.stderrString.isEmpty ? result.stdoutString : result.stderrString
                throw TmuxError.launchFailed(output.isEmpty ? "unknown error" : output)
            }
        #else
            throw TmuxError.unsupportedPlatform
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
