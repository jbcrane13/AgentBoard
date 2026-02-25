import Foundation

enum SessionMonitorError: LocalizedError {
    case invalidSessionName
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSessionName:
            return "Unable to create a valid tmux session name."
        case .launchFailed(let message):
            return message
        }
    }
}

actor SessionMonitor {
    private let tmuxSocketPath: String

    init(tmuxSocketPath: String = "/tmp/openclaw-tmux-sockets/openclaw.sock") {
        self.tmuxSocketPath = tmuxSocketPath
        // Create socket directory immediately since it's needed for listSessions
        let socketDir = URL(fileURLWithPath: tmuxSocketPath).deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: socketDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func listSessions() async throws -> [CodingSession] {
        let sessionRows = try await listSessionRows()
        guard !sessionRows.isEmpty else { return [] }

        let paneRows = try await listPaneRows()
        let panesBySession = paneRows.reduce(into: [String: PaneRow]()) { partialResult, row in
            if partialResult[row.sessionName] == nil {
                partialResult[row.sessionName] = row
            }
        }

        let processRows = try await listProcessRows()
        let processesByPID = Dictionary(uniqueKeysWithValues: processRows.map { ($0.pid, $0) })
        let childrenByParent = Dictionary(grouping: processRows, by: \.ppid)

        let now = Date()
        var sessions: [CodingSession] = []
        sessions.reserveCapacity(sessionRows.count)

        for sessionRow in sessionRows {
            let pane = panesBySession[sessionRow.name]
            let relatedProcesses = collectProcesses(
                rootPID: pane?.panePID,
                byPID: processesByPID,
                childrenByParent: childrenByParent
            )

            let agentProcesses = relatedProcesses.filter {
                Self.agentType(for: $0.command) != nil
            }
            let selectedProcess = agentProcesses.first
            let detectedAgentType = selectedProcess.flatMap { Self.agentType(for: $0.command) }
                ?? pane.flatMap { Self.agentType(for: $0.paneCommand) }
                ?? .claudeCode

            let createdDate = Date(timeIntervalSince1970: sessionRow.createdEpoch)
            let elapsed = max(0, now.timeIntervalSince(createdDate))
            let cpuPercent = (agentProcesses.isEmpty ? relatedProcesses : agentProcesses).map(\.cpuPercent).max() ?? 0
            let status = resolveStatus(
                hasAgentProcess: !agentProcesses.isEmpty,
                isAttached: sessionRow.isAttached,
                cpuPercent: cpuPercent
            )

            var projectPath: URL?
            if let currentPath = pane?.currentPath, !currentPath.isEmpty {
                projectPath = URL(fileURLWithPath: currentPath, isDirectory: true)
            }
            if projectPath == nil, let pid = pane?.panePID {
                projectPath = try? await processWorkingDirectory(pid: pid)
            }

            let session = CodingSession(
                id: sessionRow.name,
                name: sessionRow.name,
                agentType: detectedAgentType,
                projectPath: projectPath,
                beadId: extractBeadID(from: sessionRow.name),
                status: status,
                startedAt: createdDate,
                elapsed: elapsed,
                model: selectedProcess.flatMap { parseModel(from: $0.command) },
                processID: pane?.panePID,
                cpuPercent: cpuPercent
            )
            sessions.append(session)
        }

        return sessions.sorted { lhs, rhs in
            if lhs.status.sortOrder != rhs.status.sortOrder {
                return lhs.status.sortOrder < rhs.status.sortOrder
            }
            return lhs.startedAt > rhs.startedAt
        }
    }

    func capturePane(session: String, lines: Int = 500) async throws -> String {
        let lineCount = max(50, lines)
        let result = try await runTmux(arguments: [
            "capture-pane",
            "-t", session,
            "-p",
            "-S", "-\(lineCount)",
        ])
        return result.stdout
    }

    func sendNudge(session: String) async throws {
        _ = try await runTmux(arguments: [
            "send-keys",
            "-t", session,
            "C-m",
        ])
    }

    func launchSession(
        projectPath: URL,
        agentType: AgentType,
        beadID: String?,
        prompt: String?
    ) async throws -> String {
        let socketDir = URL(fileURLWithPath: tmuxSocketPath).deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: socketDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw SessionMonitorError.launchFailed("Failed to create tmux socket directory: \(error.localizedDescription)")
        }

        let projectSlug = Self.slug(from: projectPath.lastPathComponent)
        let contextSlug = Self.slug(from: beadID ?? String(Int(Date().timeIntervalSince1970)))
        var sessionName = "ab-\(projectSlug)-\(contextSlug)"
        if sessionName == "ab--" {
            throw SessionMonitorError.invalidSessionName
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: projectPath.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SessionMonitorError.launchFailed("Project path does not exist: \(projectPath.path)")
        }

        // On first launch there may be no tmux server/socket yet; probing with
        // `has-session` in that state can fail before `new-session` bootstraps it.
        // Only run collision checks when the socket already exists.
        if FileManager.default.fileExists(atPath: tmuxSocketPath),
           try await sessionExists(sessionName) {
            sessionName += "-\(Int(Date().timeIntervalSince1970) % 10_000)"
        }

        let launchCommand = command(for: agentType)

        do {
            _ = try await runTmux(arguments: [
                "new-session",
                "-d",
                "-s", sessionName,
                "-c", projectPath.path,
                launchCommand,
            ])
        } catch let error as ShellCommandError {
            let errorMsg: String
            switch error {
            case .executableNotFound:
                errorMsg = "tmux command not found. Please install tmux."
            case .failed(let result):
                let output = result.combinedOutput
                if output.contains("command not found") || output.contains("not found") {
                    errorMsg = "Agent command '\(launchCommand)' not found. Please ensure \(agentType.rawValue) is installed and in PATH."
                } else if output.contains("No such file or directory") {
                    errorMsg = "Project path not found: \(projectPath.path)"
                } else {
                    errorMsg = "Failed to launch session: \(output)"
                }
            }
            throw SessionMonitorError.launchFailed(errorMsg)
        } catch {
            throw SessionMonitorError.launchFailed(error.localizedDescription)
        }

        let trimmedPrompt = (prompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let seedPrompt: String
        if let beadID, !beadID.isEmpty, !trimmedPrompt.isEmpty {
            seedPrompt = "[\(beadID)] \(trimmedPrompt)"
        } else if let beadID, !beadID.isEmpty {
            seedPrompt = "Continue work for bead \(beadID)."
        } else {
            seedPrompt = trimmedPrompt
        }

        if !seedPrompt.isEmpty {
            try? await Task.sleep(nanoseconds: 300_000_000)
            _ = try await runTmux(arguments: [
                "send-keys",
                "-t", sessionName,
                seedPrompt,
                "C-m",
            ])
        }

        return sessionName
    }

    private func resolveStatus(hasAgentProcess: Bool, isAttached: Bool, cpuPercent: Double) -> SessionStatus {
        if !hasAgentProcess {
            return isAttached ? .idle : .stopped
        }
        return cpuPercent > 0.1 ? .running : .idle
    }

    private func listSessionRows() async throws -> [SessionRow] {
        let result: ShellCommandResult
        do {
            result = try await runTmux(arguments: [
                "list-sessions",
                "-F", "#{session_name}\t#{session_created}\t#{session_attached}",
            ])
        } catch {
            if Self.isMissingTmuxServer(error: error) {
                return []
            }
            throw error
        }

        return result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> SessionRow? in
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard columns.count >= 3 else { return nil }
                let name = String(columns[0])
                guard !name.isEmpty else { return nil }
                let createdEpoch = TimeInterval(columns[1]) ?? Date().timeIntervalSince1970
                let isAttached = Int(columns[2]) ?? 0 > 0
                return SessionRow(name: name, createdEpoch: createdEpoch, isAttached: isAttached)
            }
    }

    private func listPaneRows() async throws -> [PaneRow] {
        let result: ShellCommandResult
        do {
            result = try await runTmux(arguments: [
                "list-panes",
                "-a",
                "-F", "#{session_name}\t#{pane_pid}\t#{pane_current_path}\t#{pane_current_command}",
            ])
        } catch {
            if Self.isMissingTmuxServer(error: error) {
                return []
            }
            throw error
        }

        return result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> PaneRow? in
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard columns.count >= 4 else { return nil }
                guard let panePID = Int(columns[1]) else { return nil }
                return PaneRow(
                    sessionName: String(columns[0]),
                    panePID: panePID,
                    currentPath: String(columns[2]),
                    paneCommand: String(columns[3])
                )
            }
    }

    private func listProcessRows() async throws -> [ProcessRow] {
        let result = try await ShellCommand.runAsync(arguments: [
            "ps",
            "-axo",
            "pid=,ppid=,pcpu=,command=",
        ])

        return result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> ProcessRow? in
                let columns = line.split(maxSplits: 3, whereSeparator: \.isWhitespace)
                guard columns.count == 4 else { return nil }
                guard let pid = Int(columns[0]), let ppid = Int(columns[1]) else { return nil }
                let cpuPercent = Double(columns[2]) ?? 0
                return ProcessRow(
                    pid: pid,
                    ppid: ppid,
                    cpuPercent: cpuPercent,
                    command: String(columns[3])
                )
            }
    }

    private func collectProcesses(
        rootPID: Int?,
        byPID: [Int: ProcessRow],
        childrenByParent: [Int: [ProcessRow]]
    ) -> [ProcessRow] {
        guard let rootPID else { return [] }
        var visited: Set<Int> = []
        var queue: [Int] = [rootPID]
        var collected: [ProcessRow] = []

        while let pid = queue.popLast() {
            guard visited.insert(pid).inserted else { continue }
            if let process = byPID[pid] {
                collected.append(process)
            }
            if let children = childrenByParent[pid] {
                queue.append(contentsOf: children.map(\.pid))
            }
        }

        return collected
    }

    private func processWorkingDirectory(pid: Int) async throws -> URL? {
        guard pid > 0 else { return nil }

        let result = try await ShellCommand.runAsync(arguments: [
            "lsof",
            "-a",
            "-p", String(pid),
            "-d", "cwd",
            "-Fn",
        ])

        let path = result.stdout
            .split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix("n") }
            .map { String($0.dropFirst()) }

        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func parseModel(from command: String) -> String? {
        let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        for (index, token) in tokens.enumerated() {
            if token == "--model", index + 1 < tokens.count {
                return tokens[index + 1]
            }
            if token == "-m", index + 1 < tokens.count {
                return tokens[index + 1]
            }
            if token.hasPrefix("--model=") {
                return String(token.dropFirst("--model=".count))
            }
        }
        return nil
    }

    private func extractBeadID(from text: String) -> String? {
        let pattern = #"\b[A-Za-z][A-Za-z0-9_-]*-[A-Za-z0-9.]+\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func command(for agentType: AgentType) -> String {
        switch agentType {
        case .claudeCode:
            return "claude"
        case .codex:
            return "codex"
        case .openCode:
            return "opencode"
        }
    }

    private func sessionExists(_ name: String) async throws -> Bool {
        do {
            _ = try await runTmux(arguments: ["has-session", "-t", name])
            return true
        } catch {
            if let commandError = error as? ShellCommandError {
                switch commandError {
                case .failed(let result):
                    if Self.isMissingSessionQueryMessage(result.stderr)
                        || Self.isMissingSessionQueryMessage(result.stdout) {
                        return false
                    }
                case .executableNotFound:
                    break
                }
            }
            throw error
        }
    }

    private func runTmux(arguments: [String]) async throws -> ShellCommandResult {
        try await ShellCommand.runAsync(arguments: [
            "tmux",
            "-S", tmuxSocketPath,
        ] + arguments)
    }

    private static func agentType(for command: String) -> AgentType? {
        let lowercased = command.lowercased()
        if lowercased.contains("claude") {
            return .claudeCode
        }
        if lowercased.contains("codex") {
            return .codex
        }
        if lowercased.contains("opencode") {
            return .openCode
        }
        return nil
    }

    static func isMissingTmuxServer(error: Error) -> Bool {
        isMissingTmuxServerMessage(error.localizedDescription)
    }

    static func isMissingTmuxServerMessage(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("no server running on")
            || lower.contains("failed to connect to server")
            || lower.contains("no such file")
            || lower.contains("can't find socket")
            || lower.contains("error connecting to")
    }

    static func isMissingSessionQueryMessage(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("can't find session")
            || isMissingTmuxServerMessage(lower)
    }

    private static func slug(from rawValue: String) -> String {
        let lowercased = rawValue.lowercased()
        let replaced = lowercased.replacingOccurrences(
            of: #"[^a-z0-9]+"#,
            with: "-",
            options: .regularExpression
        )
        return replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private struct SessionRow: Sendable {
    let name: String
    let createdEpoch: TimeInterval
    let isAttached: Bool
}

private struct PaneRow: Sendable {
    let sessionName: String
    let panePID: Int
    let currentPath: String
    let paneCommand: String
}

private struct ProcessRow: Sendable {
    let pid: Int
    let ppid: Int
    let cpuPercent: Double
    let command: String
}
