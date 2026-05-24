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
        // swiftlint:disable function_body_length
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
            final class RunState: @unchecked Sendable {
                private let lock = NSLock()
                private var didResume = false
                private var isCancelled = false
                private weak var process: Process?
                private var timer: DispatchSourceTimer?

                func setProcess(_ process: Process) {
                    lock.lock()
                    defer { lock.unlock() }
                    self.process = process
                }

                func setTimer(_ timer: DispatchSourceTimer?) {
                    lock.lock()
                    defer { lock.unlock() }
                    self.timer = timer
                }

                func cancelForTaskCancellation() {
                    let process: Process?
                    let timer: DispatchSourceTimer?
                    lock.lock()
                    isCancelled = true
                    process = self.process
                    timer = self.timer
                    lock.unlock()
                    timer?.cancel()
                    process?.terminate()
                }

                func cancelTimer() {
                    let timer: DispatchSourceTimer?
                    lock.lock()
                    timer = self.timer
                    lock.unlock()
                    timer?.cancel()
                }

                func wasCancelled() -> Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    return isCancelled
                }

                func resumeOnce(_ block: () -> Void) {
                    lock.lock()
                    guard !didResume else {
                        lock.unlock()
                        return
                    }
                    didResume = true
                    lock.unlock()
                    block()
                }
            }

            let state = RunState()

            return try await withTaskCancellationHandler {
                try Task.checkCancellation()

                return try await withCheckedThrowingContinuation { continuation in
                    let process = Process()
                    state.setProcess(process)
                    process.executableURL = URL(fileURLWithPath: executablePath)
                    process.arguments = arguments
                    if let environment {
                        process.environment = environment
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
                            state.resumeOnce {
                                continuation.resume(throwing: ProcessRunError.timedOut)
                            }
                        }
                        source.resume()
                        timer = source
                    } else {
                        timer = nil
                    }
                    state.setTimer(timer)

                    process.terminationHandler = { proc in
                        state.cancelTimer()
                        state.resumeOnce {
                            if state.wasCancelled() {
                                continuation.resume(throwing: CancellationError())
                                return
                            }
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
                    }

                    do {
                        try process.run()
                    } catch {
                        state.cancelTimer()
                        state.resumeOnce {
                            continuation.resume(throwing: ProcessRunError.launchFailed(error.localizedDescription))
                        }
                    }
                }
            } onCancel: {
                state.cancelForTaskCancellation()
            }
        }
        // swiftlint:enable function_body_length
    }
#endif
