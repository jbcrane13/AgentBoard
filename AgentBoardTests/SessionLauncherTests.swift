import AgentBoardCore
import Foundation
import Testing

@Suite("SessionLauncher")
struct SessionLauncherTests {
    // MARK: - AgentType

    @Test("AgentType launchFlag values", arguments: [
        (SessionLauncher.AgentType.claude, "claude"),
        (SessionLauncher.AgentType.codex, "codex"),
        (SessionLauncher.AgentType.opencode, "opencode")
    ])
    func agentTypeLaunchFlag(agentType: SessionLauncher.AgentType, expected: String) {
        #expect(agentType.launchFlag == expected)
    }

    @Test func agentTypeDisplayNamesAreNonEmpty() {
        for agent in SessionLauncher.AgentType.allCases {
            #expect(!agent.displayName.isEmpty, "displayName is empty for \(agent.rawValue)")
        }
    }

    @Test func agentTypeIconsAreNonEmpty() {
        for agent in SessionLauncher.AgentType.allCases {
            #expect(!agent.icon.isEmpty, "icon is empty for \(agent.rawValue)")
        }
    }

    // MARK: - ExecutionPreset

    @Test func executionPresetAgentMappings() {
        #expect(SessionLauncher.ExecutionPreset.ralphLoop.agent == .claude)
        #expect(SessionLauncher.ExecutionPreset.tddSuperpowers.agent == .claude)
        #expect(SessionLauncher.ExecutionPreset.claudeToCodex.agent == .claude)
        #expect(SessionLauncher.ExecutionPreset.codexReview.agent == .codex)
        #expect(SessionLauncher.ExecutionPreset.opencodeSession.agent == .opencode)
    }

    @Test func executionPresetDescriptionsAreNonEmpty() {
        for preset in SessionLauncher.ExecutionPreset.allCases {
            #expect(!preset.description.isEmpty, "description is empty for \(preset.rawValue)")
        }
    }

    @Test func executionPresetIconsAreNonEmpty() {
        for preset in SessionLauncher.ExecutionPreset.allCases {
            #expect(!preset.icon.isEmpty, "icon is empty for \(preset.rawValue)")
        }
    }

    @Test func executionPresetIdsAreUnique() {
        let ids = SessionLauncher.ExecutionPreset.allCases.map(\.id)
        let unique = Set(ids)
        #expect(ids.count == unique.count)
    }

    // MARK: - LaunchConfig

    @Test func launchConfigUsesPresetAgentByDefault() {
        let config = SessionLauncher.LaunchConfig(
            taskTitle: "Test",
            issueNumber: 1,
            repo: "AgentBoard",
            fullRepo: "jbcrane13/AgentBoard",
            preset: .codexReview,
            customInstructions: ""
        )
        #expect(config.agentType == .codex)
    }

    @Test func launchConfigAllowsAgentTypeOverride() {
        let config = SessionLauncher.LaunchConfig(
            taskTitle: "Test",
            issueNumber: 1,
            repo: "AgentBoard",
            fullRepo: "jbcrane13/AgentBoard",
            preset: .ralphLoop,
            agentType: .codex,
            customInstructions: ""
        )
        #expect(config.agentType == .codex)
    }

    // MARK: - ActiveSession.elapsed

    @Test func activeSessionElapsedFormatsSeconds() {
        let session = SessionLauncher.ActiveSession(
            id: "test-id",
            sessionName: "ab-repo-1",
            issueNumber: 1,
            preset: .ralphLoop,
            agentType: .claude,
            startTime: Date().addingTimeInterval(-45),
            status: .running
        )
        // Format: M:SS — elapsed should be "0:45" ± a second
        let elapsed = session.elapsed
        #expect(elapsed.contains(":"))
        #expect(!elapsed.isEmpty)
    }

    @Test func activeSessionElapsedFormatsMinutes() {
        let session = SessionLauncher.ActiveSession(
            id: "test-id",
            sessionName: "ab-repo-2",
            issueNumber: 2,
            preset: .tddSuperpowers,
            agentType: .claude,
            startTime: Date().addingTimeInterval(-130),
            status: .running
        )
        // 130s = 2:10
        #expect(session.elapsed.hasPrefix("2:"))
    }

    // MARK: - ActiveSession.SessionStatus

    @Test func sessionStatusDescriptions() {
        #expect(SessionLauncher.ActiveSession.SessionStatus.running.description == "running")
        #expect(SessionLauncher.ActiveSession.SessionStatus.completed.description == "completed")
        #expect(SessionLauncher.ActiveSession.SessionStatus.failed.description == "failed")
        #expect(SessionLauncher.ActiveSession.SessionStatus.stalled.description == "stalled")
    }

    @Test @MainActor func tmuxSocketPathUsesExpectedSuffix() {
        #expect(SessionLauncher.tmuxSocketPath.hasSuffix("/.tmux/sock"))
    }

    @Test @MainActor func attachCommandReadOnlyIncludesSocketAndFlag() {
        let attach = SessionLauncher.attachCommand(for: "ab-repo-1", readOnly: true)
        #expect(attach.executable == SessionLauncher.tmuxExecutablePath)
        #expect(attach.arguments == [
            "-S", SessionLauncher.tmuxSocketPath,
            "attach-session", "-r", "-t", "ab-repo-1"
        ])
    }

    @Test @MainActor func attachCommandInteractiveOmitsReadOnlyFlag() {
        let attach = SessionLauncher.attachCommand(for: "ab-repo-1", readOnly: false)
        #expect(attach.executable == SessionLauncher.tmuxExecutablePath)
        #expect(attach.arguments == [
            "-S", SessionLauncher.tmuxSocketPath,
            "attach-session", "-t", "ab-repo-1"
        ])
    }

    @Test @MainActor func checkSessionReturnsCompletedWhenPaneShowsSuccessfulExit() async {
        let launcher = SessionLauncher(tmux: FakeTmuxController(
            hasSessionResult: true,
            paneOutput: "work complete\nEXITED: 0"
        ))
        let session = makeActiveSession(name: "ab-agentboard-130")

        let status = await launcher.checkSession(session)

        #expect(status == .completed)
    }

    @Test @MainActor func checkSessionReturnsFailedWhenPaneShowsNonzeroExit() async {
        let launcher = SessionLauncher(tmux: FakeTmuxController(
            hasSessionResult: true,
            paneOutput: "Failed to authenticate\nEXITED: 1"
        ))
        let session = makeActiveSession(name: "ab-agentboard-132")

        let status = await launcher.checkSession(session)

        #expect(status == .failed)
    }

    // MARK: - sendKeys (nudge)

    @Test @MainActor func sendKeysForwardsNameAndTextToTmux() async {
        let tmux = FakeTmuxController(hasSessionResult: true, paneOutput: nil)
        let launcher = SessionLauncher(tmux: tmux)

        await launcher.sendKeys(sessionName: "ab-agentboard-140", text: "yes")

        let calls = await tmux.sendKeysCalls
        #expect(calls.count == 1)
        #expect(calls.first?.name == "ab-agentboard-140")
        #expect(calls.first?.text == "yes")
        #expect(launcher.lastError == nil)
    }

    @Test @MainActor func sendKeysSetsLastErrorOnFailure() async {
        let tmux = FakeTmuxController(
            hasSessionResult: true,
            paneOutput: nil,
            sendKeysError: FakeTmuxError(message: "no such session")
        )
        let launcher = SessionLauncher(tmux: tmux)

        await launcher.sendKeys(sessionName: "ab-agentboard-141", text: "yes")

        #expect(launcher.lastError == "no such session")
    }

    // MARK: - killSession

    @Test @MainActor func killSessionRemovesActiveSessionOnSuccess() async {
        let tmux = FakeTmuxController(hasSessionResult: true, paneOutput: nil)
        let launcher = SessionLauncher(tmux: tmux)
        let session = makeActiveSession(name: "ab-agentboard-142")
        launcher.activeSessions = [session]

        await launcher.killSession(sessionName: session.sessionName)

        let calls = await tmux.killSessionCalls
        #expect(calls == [session.sessionName])
        #expect(launcher.activeSessions.isEmpty)
        #expect(launcher.lastError == nil)
    }

    @Test @MainActor func killSessionSetsLastErrorOnFailureAndKeepsSession() async {
        let tmux = FakeTmuxController(
            hasSessionResult: true,
            paneOutput: nil,
            killSessionError: FakeTmuxError(message: "kill failed")
        )
        let launcher = SessionLauncher(tmux: tmux)
        let session = makeActiveSession(name: "ab-agentboard-143")
        launcher.activeSessions = [session]

        await launcher.killSession(sessionName: session.sessionName)

        #expect(launcher.lastError == "kill failed")
        #expect(launcher.activeSessions.map(\.sessionName) == [session.sessionName])
    }

    // MARK: - canRelaunch

    @Test @MainActor func canRelaunchIsFalseForForeignSession() {
        let store = LaunchConfigStore(defaults: makeIsolatedDefaults())
        let launcher = SessionLauncher(
            tmux: FakeTmuxController(hasSessionResult: true, paneOutput: nil),
            launchConfigStore: store
        )

        #expect(!launcher.canRelaunch(sessionName: "ab-foreign-1"))
    }

    @Test @MainActor func canRelaunchIsTrueAfterConfigIsStored() {
        let store = LaunchConfigStore(defaults: makeIsolatedDefaults())
        let config = SessionLauncher.LaunchConfig(
            taskTitle: "Test",
            issueNumber: 150,
            repo: "AgentBoard",
            fullRepo: "jbcrane13/AgentBoard",
            preset: .ralphLoop,
            customInstructions: ""
        )
        store.store(config, forSessionName: "ab-agentboard-150")
        let launcher = SessionLauncher(
            tmux: FakeTmuxController(hasSessionResult: true, paneOutput: nil),
            launchConfigStore: store
        )

        #expect(launcher.canRelaunch(sessionName: "ab-agentboard-150"))
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SessionLauncherTests-\(UUID().uuidString)") ?? .standard
    }

    @MainActor
    private func makeActiveSession(name: String) -> SessionLauncher.ActiveSession {
        SessionLauncher.ActiveSession(
            id: name,
            sessionName: name,
            issueNumber: 130,
            preset: .ralphLoop,
            agentType: .claude,
            startTime: Date(),
            status: .running
        )
    }
}

private struct FakeTmuxError: Error, LocalizedError {
    let message: String
    var errorDescription: String? {
        message
    }
}

private actor FakeTmuxController: TmuxControlling {
    private let hasSessionResult: Bool
    private let paneOutput: String?
    private let sendKeysError: Error?
    private let killSessionError: Error?

    private(set) var sendKeysCalls: [(name: String, text: String)] = []
    private(set) var killSessionCalls: [String] = []
    private(set) var launchSessionCalls: [String] = []

    init(
        hasSessionResult: Bool,
        paneOutput: String?,
        sendKeysError: Error? = nil,
        killSessionError: Error? = nil
    ) {
        self.hasSessionResult = hasSessionResult
        self.paneOutput = paneOutput
        self.sendKeysError = sendKeysError
        self.killSessionError = killSessionError
    }

    func prepareWorkspace(name: String, repoPath: String) async throws -> String {
        "\(repoPath)/.agentboard-test-worktrees/\(name)"
    }

    func launchSession(
        name: String,
        repoPath _: String,
        agentLaunchFlag _: String,
        prdPath _: String
    ) async throws {
        launchSessionCalls.append(name)
    }

    func hasSession(name _: String) async throws -> Bool {
        hasSessionResult
    }

    func capturePane(name _: String) async -> String? {
        paneOutput
    }

    nonisolated func openInTerminal(name _: String) {}

    func sendKeys(name: String, text: String) async throws {
        sendKeysCalls.append((name, text))
        if let sendKeysError { throw sendKeysError }
    }

    func killSession(name: String) async throws {
        killSessionCalls.append(name)
        if let killSessionError { throw killSessionError }
    }
}
