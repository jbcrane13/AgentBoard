import Foundation

struct ShellCommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        let parts = [stdout, stderr].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: "\n")
    }
}

enum ShellCommandError: LocalizedError {
    case executableNotFound
    case failed(ShellCommandResult)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Unable to find shell executable."
        case .failed(let result):
            return result.combinedOutput.isEmpty
                ? "Command failed with exit code \(result.exitCode)."
                : result.combinedOutput
        }
    }
}

enum ShellCommand {
    static func run(arguments: [String], workingDirectory: URL? = nil) throws -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        // macOS GUI apps have a restricted PATH. Add common tool directories
        // so that user-installed CLIs (bd, git, etc.) are discoverable.
        var env = ProcessInfo.processInfo.environment
        let basePath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "\(home)/.local/bin"
        ]
        env["PATH"] = (extraPaths + [basePath]).joined(separator: ":")
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ShellCommandError.executableNotFound
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let result = ShellCommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)

        guard result.exitCode == 0 else {
            throw ShellCommandError.failed(result)
        }

        return result
    }

    static func runAsync(arguments: [String], workingDirectory: URL? = nil) async throws -> ShellCommandResult {
        try await Task.detached(priority: .userInitiated) {
            try run(arguments: arguments, workingDirectory: workingDirectory)
        }.value
    }
}
