import Foundation
import os

/// Manages launching agent sessions from task cards.
/// Creates tmux sessions pre-loaded with issue context and execution presets.
@MainActor
@Observable
public final class SessionLauncher {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "SessionLauncher")

    // MARK: - Models

    public enum AgentType: String, CaseIterable, Identifiable, Sendable {
        case claude
        case codex
        case opencode

        public var id: String {
            rawValue
        }

        public var displayName: String {
            switch self {
            case .claude: return "Claude Code"
            case .codex: return "Codex CLI"
            case .opencode: return "OpenCode"
            }
        }

        public var icon: String {
            switch self {
            case .claude: return "brain.head.profile"
            case .codex: return "terminal.fill"
            case .opencode: return "chevron.left.forwardslash.chevron.right"
            }
        }

        public var launchFlag: String {
            switch self {
            case .claude: return "claude"
            case .codex: return "codex"
            case .opencode: return "opencode"
            }
        }
    }

    public enum ExecutionPreset: String, CaseIterable, Identifiable, Sendable {
        case ralphLoop = "Ralph Loop"
        case tddSuperpowers = "TDD (Superpowers)"
        case claudeToCodex = "Claude → Codex Handoff"
        case codexReview = "Codex Review & Test"
        case opencodeSession = "OpenCode Session"

        public var id: String {
            rawValue
        }

        public var description: String {
            switch self {
            case .ralphLoop:
                return "Short iterations, PRD-driven, watchdog monitoring. Best for features and fixes."
            case .tddSuperpowers:
                return "Test-first workflow. Write failing tests, then implement. Best for business logic."
            case .claudeToCodex:
                return "Claude implements, auto-hands off to Codex for test validation. Best for large features."
            case .codexReview:
                return "Codex handles implementation with built-in review cycle. Best for PRs and testing."
            case .opencodeSession:
                return "OpenCode multi-model session. Best for parallel exploration and non-Anthropic models."
            }
        }

        public var icon: String {
            switch self {
            case .ralphLoop: return "arrow.triangle.2.circlepath"
            case .tddSuperpowers: return "checkmark.shield"
            case .claudeToCodex: return "arrow.right.circle"
            case .codexReview: return "terminal.fill"
            case .opencodeSession: return "chevron.left.forwardslash.chevron.right"
            }
        }

        public var agent: AgentType {
            switch self {
            case .ralphLoop: return .claude
            case .tddSuperpowers: return .claude
            case .claudeToCodex: return .claude
            case .codexReview: return .codex
            case .opencodeSession: return .opencode
            }
        }
    }

    public struct LaunchConfig {
        public let taskTitle: String
        public let issueNumber: Int
        public let repo: String
        public let fullRepo: String
        public let preset: ExecutionPreset
        public let agentType: AgentType
        public let customInstructions: String

        public init(
            taskTitle: String,
            issueNumber: Int,
            repo: String,
            fullRepo: String,
            preset: ExecutionPreset,
            agentType: AgentType? = nil,
            customInstructions: String
        ) {
            self.taskTitle = taskTitle
            self.issueNumber = issueNumber
            self.repo = repo
            self.fullRepo = fullRepo
            self.preset = preset
            self.agentType = agentType ?? preset.agent
            self.customInstructions = customInstructions
        }
    }

    public struct ActiveSession: Identifiable, Sendable {
        public let id: String
        public let sessionName: String
        public let issueNumber: Int
        public let preset: ExecutionPreset
        public let agentType: AgentType
        public let startTime: Date
        public var status: SessionStatus

        public enum SessionStatus: Sendable, CustomStringConvertible {
            case running, completed, failed, stalled

            public var description: String {
                switch self {
                case .running: "running"
                case .completed: "completed"
                case .failed: "failed"
                case .stalled: "stalled"
                }
            }
        }

        public var elapsed: String {
            let interval = Date().timeIntervalSince(startTime)
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - State

    public var activeSessions: [ActiveSession] = []
    public var isLaunching = false
    public var lastError: String?

    // MARK: - Launch

    @discardableResult
    public func launch(config: LaunchConfig) async -> String? {
        isLaunching = true
        lastError = nil

        let sessionName = "ab-\(config.repo.lowercased())-\(config.issueNumber)".replacingOccurrences(
            of: ".",
            with: "_"
        )
        let prdPath = "docs/PRD-issue-\(config.issueNumber).md"

        do {
            // 1. Generate PRD
            let prd = generatePRD(config: config)
            try writePRD(repo: config.repo, path: prdPath, content: prd)

            // 2. Launch tmux session
            try await launchTmuxSession(
                sessionName: sessionName,
                repo: config.repo,
                agentType: config.agentType,
                prdPath: prdPath
            )

            // 3. Track session
            let session = ActiveSession(
                id: UUID().uuidString,
                sessionName: sessionName,
                issueNumber: config.issueNumber,
                preset: config.preset,
                agentType: config.agentType,
                startTime: Date(),
                status: .running
            )
            activeSessions.append(session)
            isLaunching = false

            logger.info("Launched session: \(sessionName)")
            startMonitoring()
            return sessionName

        } catch {
            lastError = error.localizedDescription
            isLaunching = false
            logger.error("Launch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - PRD Generation

    private func generatePRD(config: LaunchConfig) -> String {
        var prd = """
        # PRD: \(config.taskTitle)

        ## Issue
        #\(config.issueNumber) in \(config.fullRepo)

        """

        switch config.preset {
        case .ralphLoop:
            prd += """
            ## Tasks
            - [ ] Implement \(config.taskTitle)
            - [ ] Handle edge cases and error states
            - [ ] Add accessibilityIdentifier to every interactive element
            - [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build

            """
        case .tddSuperpowers:
            prd += """
            ## Tasks
            - [ ] Write failing tests that define expected behavior
            - [ ] Implement \(config.taskTitle) to pass tests
            - [ ] Handle edge cases
            - [ ] Add accessibilityIdentifier to every interactive element
            - [ ] Run full test suite — all tests must pass

            """
        case .claudeToCodex:
            prd += """
            ## Phase 1: Implementation (Claude Code)
            - [ ] Implement \(config.taskTitle)
            - [ ] Handle edge cases
            - [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build
            - [ ] Commit to feature branch

            ## Phase 2: Test Validation (Codex — auto-handoff)
            - [ ] Run full test suite
            - [ ] Add missing tests if coverage gaps found
            - [ ] Run linter — no new warnings
            - [ ] Report results

            """
        case .codexReview:
            prd += """
            ## Tasks
            - [ ] Implement \(config.taskTitle)
            - [ ] Run full test suite
            - [ ] Review code quality and suggest improvements
            - [ ] Add accessibilityIdentifier to every interactive element
            - [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build

            """
        case .opencodeSession:
            prd += """
            ## Tasks
            - [ ] Analyze codebase for \(config.taskTitle)
            - [ ] Implement with multi-model approach
            - [ ] Cross-validate with different models
            - [ ] Add accessibilityIdentifier to every interactive element
            - [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build

            """
        }

        prd += """
        ## Constraints
        - Swift 6 strict concurrency
        - @Observable not ObservableObject
        - accessibilityIdentifier on every interactive element

        ## Anti-Stall Rules
        - Never wait for input. Never pause for confirmation. Keep moving.
        - When done: commit, push to feature branch, STOP.
        - Report: "DONE: [accomplished] | BLOCKED: [anything open]"
        """

        if !config.customInstructions.isEmpty {
            prd += "\n## Custom Instructions\n\(config.customInstructions)\n"
        }

        return prd
    }

    // MARK: - tmux Launch

    private func writePRD(repo: String, path: String, content: String) throws {
        #if os(macOS)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let projectDir = home.appendingPathComponent("Projects").appendingPathComponent(repo)
            let prdDir = projectDir.appendingPathComponent("docs")

            try FileManager.default.createDirectory(at: prdDir, withIntermediateDirectories: true)

            let prdFile = prdDir.appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)
            try content.write(to: prdFile, atomically: true, encoding: .utf8)
        #else
            throw LaunchError.unsupportedPlatform
        #endif
    }

    private func launchTmuxSession(
        sessionName: String,
        repo: String,
        agentType: AgentType,
        prdPath: String
    ) async throws {
        #if os(macOS)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let projectDir = home.appendingPathComponent("Projects").appendingPathComponent(repo).path
            let socket = home.appendingPathComponent(".tmux/sock").path
            let agent = agentType.launchFlag

            let shellCmd = "/opt/homebrew/bin/tmux -S \(socket) new -d -s \(sessionName)" +
                " \"cd \(projectDir) && unset ANTHROPIC_API_KEY" +
                " && /opt/homebrew/bin/ralphy --\(agent) --prd \(prdPath)" +
                "; EXIT_CODE=$?; echo EXITED: $EXIT_CODE; sleep 999999\""

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", shellCmd]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "unknown error"
                throw LaunchError.tmuxFailed(output)
            }
        #else
            throw LaunchError.unsupportedPlatform
        #endif
    }

    // MARK: - Monitoring

    public func checkSession(_ session: ActiveSession) async -> ActiveSession.SessionStatus {
        #if os(macOS)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let socket = home.appendingPathComponent(".tmux/sock").path

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tmux")
            process.arguments = ["-S", socket, "has-session", "-t", session.sessionName]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0 ? .running : .completed
            } catch {
                return .failed
            }
        #else
            return .failed
        #endif
    }

    /// Capture the current visible content of a tmux session pane.
    public func capturePane(sessionName: String) -> String? {
        #if os(macOS)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let socket = home.appendingPathComponent(".tmux/sock").path

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tmux")
            process.arguments = ["-S", socket, "capture-pane", "-t", sessionName, "-p", "-J"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return nil
            }
        #else
            return nil
        #endif
    }

    /// Open a tmux session in the system Terminal.app.
    public func openInTerminal(sessionName: String) {
        #if os(macOS)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let socket = home.appendingPathComponent(".tmux/sock").path

            let cmd = "tmux -S \(socket) attach -t \(sessionName)"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal.app"]

            let appleScript = """
            tell application "Terminal"
                activate
                do script "\(cmd)"
            end tell
            """

            let scriptProcess = Process()
            scriptProcess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            scriptProcess.arguments = ["-e", appleScript]

            do {
                try scriptProcess.run()
            } catch {
                logger.error("Failed to open Terminal.app: \(error.localizedDescription)")
            }
        #endif
    }

    /// Start monitoring active sessions for status changes.
    public func startMonitoring() {
        Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                for index in activeSessions.indices {
                    let session = activeSessions[index]
                    if session.status == .running {
                        let newStatus = await checkSession(session)
                        if newStatus != session.status {
                            activeSessions[index].status = newStatus
                            logger.info("Session \(session.sessionName) status changed to \(newStatus)")
                        }
                    }
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    // MARK: - Errors

    enum LaunchError: LocalizedError {
        case tmuxFailed(String)
        case unsupportedPlatform

        var errorDescription: String? {
            switch self {
            case let .tmuxFailed(msg): return "tmux launch failed: \(msg)"
            case .unsupportedPlatform: return "Session launching is only supported on macOS."
            }
        }
    }
}
