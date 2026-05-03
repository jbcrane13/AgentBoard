import Foundation

/// Thin wrapper around `hermes kanban` CLI for write operations.
/// Mutations go through the CLI so the gateway/dispatcher owns the write path
/// and we never contend with the SQLite claim/reclaim cycle.
public actor KanbanCLIWriter {
    public enum WriteError: LocalizedError, Equatable {
        case commandFailed(String)
        case invalidJSON(String)
        case taskNotFound(String)
        case processTimedOut
        case unsupportedPlatform

        public var errorDescription: String? {
            switch self {
            case let .commandFailed(msg): "Kanban CLI failed: \(msg)"
            case let .invalidJSON(msg): "Kanban CLI returned invalid JSON: \(msg)"
            case let .taskNotFound(id): "Task not found: \(id)"
            case .processTimedOut: "Kanban CLI timed out"
            case .unsupportedPlatform: "Kanban CLI is only available on macOS"
            }
        }
    }

    private let hermesPath: String
    private let timeoutSeconds: Double

    public init(
        hermesPath: String = "/opt/homebrew/bin/hermes",
        timeoutSeconds: Double = 15
    ) {
        self.hermesPath = hermesPath
        self.timeoutSeconds = timeoutSeconds
    }

    /// Resolve hermes binary path dynamically.
    private func resolveHermes() async throws -> String {
        // Try the configured path first
        if FileManager.default.isExecutableFile(atPath: hermesPath) {
            return hermesPath
        }
        // Fall back to PATH lookup
        return "hermes"
    }

    // MARK: - Create

    /// Create a new kanban task. Returns the created task (parsed from `--json` output).
    public func create(_ draft: KanbanCreateDraft) async throws -> KanbanTask {
        var args = ["kanban", "create", draft.title, "--json"]

        if let body = draft.body { args += ["--body", body] }
        if let assignee = draft.assignee { args += ["--assignee", assignee] }
        if draft.priority > 0 { args += ["--priority", "\(draft.priority)"] }
        if let tenant = draft.tenant { args += ["--tenant", tenant] }
        for parentID in draft.parentIDs {
            args += ["--parent", parentID]
        }

        let output = try await runHermes(args)
        return try parseKanbanTask(output)
    }

    // MARK: - Comment

    public func comment(taskID: String, body: String) async throws {
        let args = ["kanban", "comment", taskID, body]
        _ = try await runHermes(args)
    }

    // MARK: - Complete

    public func complete(taskID: String, summary: String) async throws {
        let args = ["kanban", "complete", taskID, "--summary", summary]
        _ = try await runHermes(args)
    }

    // MARK: - Block / Unblock

    public func block(taskID: String, reason: String) async throws {
        let args = ["kanban", "block", taskID, reason]
        _ = try await runHermes(args)
    }

    public func unblock(taskID: String) async throws {
        let args = ["kanban", "unblock", taskID]
        _ = try await runHermes(args)
    }

    // MARK: - Archive

    public func archive(taskID: String) async throws {
        let args = ["kanban", "archive", taskID]
        _ = try await runHermes(args)
    }

    // MARK: - Assign

    public func assign(taskID: String, assignee: String) async throws {
        let args = ["kanban", "assign", taskID, "--assignee", assignee]
        _ = try await runHermes(args)
    }

    // MARK: - CLI Execution

    private func runHermes(_ args: [String]) async throws -> String {
        #if os(macOS)
        let hermes = try await resolveHermes()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: hermes)
            process.arguments = args

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            // Enforce timeout
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + timeoutSeconds)
            timer.setEventHandler {
                process.terminate()
                continuation.resume(throwing: WriteError.processTimedOut)
            }
            timer.resume()

            process.terminationHandler = { proc in
                timer.cancel()
                let exitCode = proc.terminationStatus
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let outStr = String(data: outData, encoding: .utf8) ?? ""
                let errStr = String(data: errData, encoding: .utf8) ?? ""

                if exitCode == 0 {
                    continuation.resume(returning: outStr)
                } else {
                    let msg = errStr.isEmpty ? outStr : errStr
                    continuation.resume(
                        throwing: WriteError.commandFailed(
                            msg.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                timer.cancel()
                continuation.resume(
                    throwing: WriteError.commandFailed(error.localizedDescription)
                )
            }
        }
        #else
        _ = args
        throw WriteError.unsupportedPlatform
        #endif
    }

    // MARK: - JSON Parsing

    private func parseKanbanTask(_ jsonString: String) throws -> KanbanTask {
        guard let data = jsonString.data(using: .utf8) else {
            throw WriteError.invalidJSON("Cannot encode JSON string")
        }

        let decoder = JSONDecoder()
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WriteError.invalidJSON("Not a JSON object")
        }

        let id = raw["id"] as? String ?? ""
        let title = raw["title"] as? String ?? ""
        let body = raw["body"] as? String
        let assignee = raw["assignee"] as? String
        let statusRaw = raw["status"] as? String ?? "todo"
        let priority = raw["priority"] as? Int ?? 0
        let tenant = raw["tenant"] as? String
        let workspaceKindRaw = raw["workspace_kind"] as? String ?? "scratch"

        let createdAt: Date = {
            if let ts = raw["created_at"] as? TimeInterval {
                return Date(timeIntervalSince1970: ts)
            }
            return .now
        }()

        return KanbanTask(
            id: id,
            title: title,
            body: body,
            assignee: assignee,
            status: KanbanStatus(rawValue: statusRaw) ?? .todo,
            priority: priority,
            createdBy: raw["created_by"] as? String,
            createdAt: createdAt,
            workspaceKind: KanbanWorkspaceKind(rawValue: workspaceKindRaw) ?? .scratch,
            tenant: tenant,
            skills: raw["skills"] as? [String]
        )
    }
}
