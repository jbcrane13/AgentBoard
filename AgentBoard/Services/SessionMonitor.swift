import Foundation

private let defaultSessionMonitorTmuxSocketPath = "\(NSHomeDirectory())/.tmux/sock"

enum SessionMonitorError: LocalizedError {
    case invalidSessionName
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSessionName:
            return "Unable to create a valid tmux session name."
        case let .launchFailed(message):
            return message
        }
    }
}

actor SessionMonitor {
    private let tmuxSocketPath: String
    private let legacySocketPath = "/tmp/openclaw-tmux-sockets/openclaw.sock"

    init(tmuxSocketPath: String = defaultSessionMonitorTmuxSocketPath) {
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
        #if os(macOS)
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
                let cpuPercent = (agentProcesses.isEmpty ? relatedProcesses : agentProcesses).map(\.cpuPercent)
                    .max() ?? 0
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
                    sessionType: Self.detectSessionType(paneCommand: pane?.paneCommand, agentCommand: selectedProcess?.command),
                    projectPath: projectPath,
                    beadId: Self.extractBeadID(from: sessionRow.name),
                    linkedIssueNumber: Self.extractIssueNumber(from: sessionRow.name),
                    status: status,
                    startedAt: createdDate,
                    elapsed: elapsed,
                    model: selectedProcess.flatMap { Self.parseModel(from: $0.command) },
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
        #else
            return []
        #endif
    }

    func killSession(_ sessionName: String) async throws {
        #if os(macOS)
            _ = try await runTmux(arguments: [
                "kill-session",
                "-t", sessionName
            ])
        #else
            throw ShellCommandError.unavailableOnPlatform
        #endif
    }

    func capturePane(session: String, lines: Int = 500) async throws -> String {
        #if os(macOS)
            let lineCount = max(50, lines)
            let result = try await runTmux(arguments: [
                "capture-pane",
                "-t", session,
                "-p",
                "-S", "-\(lineCount)"
            ])
            return result.stdout
        #else
            throw ShellCommandError.unavailableOnPlatform
        #endif
    }

    func sendNudge(session: String) async throws {
        #if os(macOS)
            _ = try await runTmux(arguments: [
                "send-keys",
                "-t", session,
                "C-m"
            ])
        #else
            throw ShellCommandError.unavailableOnPlatform
        #endif
    }

    func launchSession(
        projectPath: URL,
        agentType: AgentType,
        sessionType: SessionType = .ralphLoop,
        issueNumber: Int?,
        prompt: String?
    ) async throws -> String {
        #if os(macOS)
            let socketDir = URL(fileURLWithPath: tmuxSocketPath).deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(
                    at: socketDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw SessionMonitorError
                    .launchFailed("Failed to create tmux socket directory: \(error.localizedDescription)")
            }

            let projectSlug = Self.slug(from: projectPath.lastPathComponent)
            let contextSlug: String
            if let issueNumber {
                contextSlug = "gh\(issueNumber)"
            } else {
                contextSlug = String(Int(Date().timeIntervalSince1970))
            }
            var sessionName = "ab-\(projectSlug)-\(contextSlug)"
            if sessionName == "ab--" {
                throw SessionMonitorError.invalidSessionName
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: projectPath.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw SessionMonitorError.launchFailed("Project path does not exist: \(projectPath.path)")
            }

            // On first launch there may be no tmux server/socket yet; probing with
            // `has-session` in that state can fail before `new-session` bootstraps it.
            // Only run collision checks when the socket already exists.
            if FileManager.default.fileExists(atPath: tmuxSocketPath),
               try await sessionExists(sessionName) {
                sessionName += "-\(Int(Date().timeIntervalSince1970) % 10000)"
            }

            let agentCommand = commandParts(for: agentType, sessionType: sessionType, sessionName: sessionName)

            // Create the tmux session with the default shell (no command argument).
            // This lets the user's shell profile source normally, ensuring PATH includes
            // agent CLIs like ~/.claude/bin/claude. We then send the agent command via
            // send-keys so it runs inside the fully-configured shell.
            do {
                _ = try await runTmux(arguments: [
                    "new-session",
                    "-d",
                    "-s", sessionName,
                    "-c", projectPath.path
                ])
            } catch let error as ShellCommandError {
                let errorMsg: String
                switch error {
                case .executableNotFound:
                    errorMsg = "tmux command not found. Please install tmux."
                case let .failed(result):
                    let output = result.combinedOutput
                    if output.contains("No such file or directory") {
                        errorMsg = "Project path not found: \(projectPath.path)"
                    } else {
                        errorMsg = "Failed to launch session: \(output)"
                    }
                case .unavailableOnPlatform:
                    errorMsg = "tmux is unavailable on this platform."
                }
                throw SessionMonitorError.launchFailed(errorMsg)
            } catch {
                throw SessionMonitorError.launchFailed(error.localizedDescription)
            }

            try await sendAgentCommand(
                sessionName: sessionName,
                agentCommand: agentCommand,
                sessionType: sessionType,
                issueNumber: issueNumber,
                prompt: prompt
            )

            return sessionName
        #else
            throw ShellCommandError.unavailableOnPlatform
        #endif
    }

    #if os(macOS)
        private func sendAgentCommand(
            sessionName: String,
            agentCommand: [String],
            sessionType: SessionType,
            issueNumber: Int?,
            prompt: String?
        ) async throws {
            // Brief delay for the shell to initialize before sending commands.
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Send the agent command into the session's shell.
            let agentCommandString = agentCommand.joined(separator: " ")
            _ = try await runTmux(arguments: [
                "send-keys",
                "-t", sessionName,
                agentCommandString,
                "C-m"
            ])

            // Build and send the seed prompt if one was provided or an issue is linked.
            // For Ralph loops, the prompt is included in the command, so skip this.
            if sessionType == .standard {
                let seedPrompt = Self.buildSeedPrompt(issueNumber: issueNumber, prompt: prompt)
                if !seedPrompt.isEmpty {
                    // Wait for the agent CLI to start and be ready for input.
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    _ = try await runTmux(arguments: [
                        "send-keys",
                        "-t", sessionName,
                        seedPrompt,
                        "C-m"
                    ])
                }
            }
        }

        private func resolveStatus(hasAgentProcess: Bool, isAttached: Bool, cpuPercent: Double) -> SessionStatus {
            if !hasAgentProcess {
                return isAttached ? .idle : .stopped
            }
            return cpuPercent > 0.1 ? .running : .idle
        }

        /// Delimiter used in tmux format strings. Using `|||` instead of `\t` because
        /// the tab escape is unreliable when passed through Process arguments on macOS.
        private static let tmuxDelimiter = "|||"

        private func listSessionRows() async throws -> [SessionRow] {
            let delim = Self.tmuxDelimiter
            let result: ShellCommandResult
            do {
                result = try await runTmux(arguments: [
                    "list-sessions",
                    "-F", "#{session_name}\(delim)#{session_created}\(delim)#{session_attached}"
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
                    let columns = String(line).components(separatedBy: delim)
                    guard columns.count >= 3 else { return nil }
                    let name = columns[0]
                    guard !name.isEmpty else { return nil }
                    let createdEpoch = TimeInterval(columns[1]) ?? Date().timeIntervalSince1970
                    let isAttached = Int(columns[2]) ?? 0 > 0
                    return SessionRow(name: name, createdEpoch: createdEpoch, isAttached: isAttached)
                }
        }

        private func listPaneRows() async throws -> [PaneRow] {
            let delim = Self.tmuxDelimiter
            let result: ShellCommandResult
            do {
                result = try await runTmux(arguments: [
                    "list-panes",
                    "-a",
                    "-F",
                    "#{session_name}\(delim)#{pane_pid}\(delim)#{pane_current_path}\(delim)#{pane_current_command}"
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
                    let columns = String(line).components(separatedBy: delim)
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
                "pid=,ppid=,pcpu=,command="
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
                "-Fn"
            ])

            let path = result.stdout
                .split(whereSeparator: \.isNewline)
                .first { $0.hasPrefix("n") }
                .map { String($0.dropFirst()) }

            guard let path, !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        private func commandParts(for agentType: AgentType, sessionType: SessionType, sessionName: String) -> [String] {
            let baseCommand: [String]
            switch agentType {
            case .claudeCode:
                baseCommand = ["ralphy", "--claude"]
            case .codex:
                baseCommand = ["ralphy", "--codex"]
            case .openCode:
                baseCommand = ["ralphy", "--opencode"]
            }

            switch sessionType {
            case .ralphLoop:
                // Ralph loop with completion hook that fires wake event
                // Build completion hook with shell variables ($ must not be escaped)
                let exitCapture = "EXIT_CODE=$?"
                let echoCmd = "echo EXITED: $EXIT_CODE"
                let wakeEvent = "openclaw system event --text 'Ralph loop " + sessionName + " finished (exit $EXIT_CODE) in $(pwd)' --mode now"
                let sleepCmd = "sleep 999999"
                let completionHook = exitCapture + "; " + echoCmd + "; " + wakeEvent + "; " + sleepCmd
                return baseCommand + ["&&", completionHook]
            case .standard:
                // Standard session without Ralph loop
                switch agentType {
                case .claudeCode:
                    return ["claude", "--dangerously-skip-permissions"]
                case .codex:
                    return ["codex"]
                case .openCode:
                    return ["opencode"]
                }
            }
        }

        private func sessionExists(_ name: String) async throws -> Bool {
            do {
                _ = try await runTmux(arguments: ["has-session", "-t", name])
                return true
            } catch {
                if let commandError = error as? ShellCommandError {
                    switch commandError {
                    case let .failed(result):
                        if Self.isMissingSessionQueryMessage(result.stderr)
                            || Self.isMissingSessionQueryMessage(result.stdout) {
                            return false
                        }
                    case .executableNotFound:
                        break
                    case .unavailableOnPlatform:
                        break
                    }
                }
                throw error
            }
        }

        private func runTmux(arguments: [String]) async throws -> ShellCommandResult {
            try await ShellCommand.runAsync(arguments: [
                "tmux",
                "-S", tmuxSocketPath
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

        private static func detectSessionType(paneCommand: String?, agentCommand: String?) -> SessionType {
            // Check if the command includes ralphy
            let commandsToCheck = [paneCommand, agentCommand].compactMap { $0 }
            for cmd in commandsToCheck {
                if cmd.lowercased().contains("ralphy") {
                    return .ralphLoop
                }
            }
            return .standard
        }
    #endif
}

// MARK: - Static Helpers (outside actor body for lint compliance)

extension SessionMonitor {
    static func defaultTmuxSocketPath() -> String {
        defaultSessionMonitorTmuxSocketPath
    }

    /// Extracts a GitHub issue number from a session name (e.g. "ab-agentboard-gh16" → 16).
    static func extractIssueNumber(from sessionName: String) -> Int? {
        let pattern = #"\bgh(\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsRange = NSRange(sessionName.startIndex ..< sessionName.endIndex, in: sessionName)
        guard let match = regex.firstMatch(in: sessionName, range: nsRange),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: sessionName) else {
            return nil
        }
        return Int(sessionName[range])
    }

    static func buildSeedPrompt(issueNumber: Int?, prompt: String?) -> String {
        let trimmedPrompt = (prompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let issueNumber, !trimmedPrompt.isEmpty {
            return "[GH-\(issueNumber)] \(trimmedPrompt)"
        } else if let issueNumber {
            return "Continue work for GitHub issue #\(issueNumber)."
        }
        return trimmedPrompt
    }

    static func parseModel(from command: String) -> String? {
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

    static func extractBeadID(from text: String) -> String? {
        let pattern = #"\b[A-Za-z][A-Za-z0-9_-]*-[A-Za-z0-9.]+\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
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

#if os(macOS)
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
#endif
