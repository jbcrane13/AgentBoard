import Foundation

/// Captured result of an async subprocess run.
public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data

    public var stdoutString: String {
        String(data: stdout, encoding: .utf8) ?? ""
    }

    public var stderrString: String {
        String(data: stderr, encoding: .utf8) ?? ""
    }

    public var succeeded: Bool { exitCode == 0 }
}

public enum ProcessRunError: Error, Sendable {
    case launchFailed(String)
    case timedOut
    case unsupportedPlatform
}

#if os(macOS)
    public extension Process {
        /// Async wrapper around `Process.run()` + `terminationHandler`.
        ///
        /// Replaces synchronous `process.waitUntilExit()` so the calling actor
        /// (especially `@MainActor` and other isolated actors) is not blocked
        /// while the subprocess runs. Captures stdout and stderr to in-memory
        /// `Data`. Pass `timeout` to terminate the process if it overruns.
        static func runAsync(
            executablePath: String,
            arguments: [String],
            environment: [String: String]? = nil,
            timeout: TimeInterval? = nil
        ) async throws -> ProcessResult {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                if let environment {
                    process.setValue(environment, forKey: "environment")
                }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let timer: DispatchSourceTimer?
                if let timeout {
                    let source = DispatchSource.makeTimerSource()
                    source.schedule(deadline: .now() + timeout)
                    source.setEventHandler {
                        process.terminate()
                        continuation.resume(throwing: ProcessRunError.timedOut)
                    }
                    source.resume()
                    timer = source
                } else {
                    timer = nil
                }

                process.terminationHandler = { proc in
                    timer?.cancel()
                    let outData = (try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data()
                    let errData = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()
                    continuation.resume(
                        returning: ProcessResult(
                            exitCode: proc.terminationStatus,
                            stdout: outData,
                            stderr: errData
                        )
                    )
                }

                do {
                    try process.run()
                } catch {
                    timer?.cancel()
                    continuation.resume(throwing: ProcessRunError.launchFailed(error.localizedDescription))
                }
            }
        }
    }
#endif
