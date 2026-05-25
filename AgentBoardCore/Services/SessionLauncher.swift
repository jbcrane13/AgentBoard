import Foundation
import os

/// Manages launching agent sessions from task cards.
/// Composes a `PRDComposer` (Markdown PRD generation), a `TmuxControlling`
/// (tmux subprocess invocations), and a polling status monitor.
@MainActor
@Observable
public final class SessionLauncher {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "SessionLauncher")
    private let prdComposer: PRDComposer
    private let tmux: any TmuxControlling

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

    public struct LaunchConfig: Sendable {
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

        public init(
            id: String,
            sessionName: String,
            issueNumber: Int,
            preset: ExecutionPreset,
            agentType: AgentType,
            startTime: Date,
            status: SessionStatus
        ) {
            self.id = id
            self.sessionName = sessionName
            self.issueNumber = issueNumber
            self.preset = preset
            self.agentType = agentType
            self.startTime = startTime
            self.status = status
        }

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

    public enum LaunchError: LocalizedError {
        case tmuxFailed(String)
        case unsupportedPlatform

        public var errorDescription: String? {
            switch self {
            case let .tmuxFailed(msg): return "tmux launch failed: \(msg)"
            case .unsupportedPlatform: return "Session launching is only supported on macOS."
            }
        }
    }

    // MARK: - State

    public var activeSessions: [ActiveSession] = []
    public var isLaunching = false
    public var lastError: String?
    private var monitorTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        prdComposer: PRDComposer = PRDComposer(),
        tmux: any TmuxControlling = LiveTmuxController()
    ) {
        self.prdComposer = prdComposer
        self.tmux = tmux
    }

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
            let prd = prdComposer.compose(config: config)
            try writePRD(repo: config.repo, path: prdPath, content: prd)

            let repoPath = Self.repoPath(for: config.repo)
            do {
                try await tmux.launchSession(
                    name: sessionName,
                    repoPath: repoPath,
                    agentLaunchFlag: config.agentType.launchFlag,
                    prdPath: prdPath
                )
            } catch let TmuxError.launchFailed(msg) {
                throw LaunchError.tmuxFailed(msg)
            } catch TmuxError.unsupportedPlatform {
                throw LaunchError.unsupportedPlatform
            }

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

    // MARK: - Tmux pass-throughs (used by SessionTerminalView)

    public func checkSession(_ session: ActiveSession) async -> ActiveSession.SessionStatus {
        if let output = await tmux.capturePane(name: session.sessionName),
           let exitCode = Self.launchExitCode(in: output) {
            return exitCode == 0 ? .completed : .failed
        }

        do {
            let alive = try await tmux.hasSession(name: session.sessionName)
            return alive ? .running : .completed
        } catch {
            logger.error("Failed to check tmux session: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    private static func launchExitCode(in output: String) -> Int? {
        for line in output.split(whereSeparator: \.isNewline).reversed() {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("EXITED:") else { continue }

            let codeText = trimmed
                .dropFirst("EXITED:".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(codeText)
        }

        return nil
    }

    public func capturePane(sessionName: String) async -> String? {
        await tmux.capturePane(name: sessionName)
    }

    public func openInTerminal(sessionName: String) {
        tmux.openInTerminal(name: sessionName)
    }

    // MARK: - Static tmux paths (referenced by EmbeddedTerminalView)

    public static var tmuxExecutablePath: String {
        LiveTmuxController.tmuxExecutablePath
    }

    public static var tmuxSocketPath: String {
        LiveTmuxController.tmuxSocketPath
    }

    public static func attachCommand(for sessionName: String) -> (executable: String, arguments: [String]) {
        LiveTmuxController.attachCommand(for: sessionName)
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
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

    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    // MARK: - PRD file I/O

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

    private static func repoPath(for repo: String) -> String {
        #if os(macOS)
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent("Projects").appendingPathComponent(repo).path
        #else
            return "/" // unreachable — launch() throws unsupportedPlatform via tmux on iOS
        #endif
    }
}
