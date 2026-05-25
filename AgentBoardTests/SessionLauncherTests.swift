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

private actor FakeTmuxController: TmuxControlling {
    private let hasSessionResult: Bool
    private let paneOutput: String?

    init(hasSessionResult: Bool, paneOutput: String?) {
        self.hasSessionResult = hasSessionResult
        self.paneOutput = paneOutput
    }

    func launchSession(
        name _: String,
        repoPath _: String,
        agentLaunchFlag _: String,
        prdPath _: String
    ) async throws {}

    func hasSession(name _: String) async throws -> Bool {
        hasSessionResult
    }

    func capturePane(name _: String) async -> String? {
        paneOutput
    }

    nonisolated func openInTerminal(name _: String) {}
}
