@testable import AgentBoard
import Foundation
import Testing

actor FlakySessionOpenClawService: OpenClawServicing {
    enum Mode {
        case success([GatewaySession])
        case failure(Error)
    }

    private var mode: Mode = .success([])

    func setMode(_ mode: Mode) {
        self.mode = mode
    }

    var isConnected: Bool {
        true
    }

    var events: AsyncStream<GatewayEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func configure(gatewayURLString _: String?, token _: String?) throws {}
    func connect() async throws {}
    func disconnect() async {}
    func sendChat(sessionKey _: String, message _: String, thinking _: String?) async throws {}
    func chatHistory(sessionKey _: String, limit _: Int) async throws -> GatewayChatHistory {
        GatewayChatHistory(messages: [], thinkingLevel: nil)
    }

    func abortChat(sessionKey _: String, runId _: String?) async throws {}
    func listSessions(activeMinutes _: Int?, limit _: Int?) async throws -> [GatewaySession] {
        switch mode {
        case let .success(sessions):
            return sessions
        case let .failure(error):
            throw error
        }
    }

    func createSession(
        label: String?,
        projectPath _: String?,
        agentType: String?,
        beadId _: String?,
        prompt _: String?
    ) async throws -> GatewaySession {
        GatewaySession(
            id: "main",
            key: "main",
            label: label,
            agentId: agentType,
            model: nil,
            status: "active",
            lastActiveAt: Date(),
            thinkingLevel: nil
        )
    }

    func patchSession(key _: String, thinkingLevel _: String?) async throws {}

    func agentIdentity(sessionKey _: String?) async throws -> GatewayAgentIdentity {
        GatewayAgentIdentity(agentId: nil, name: "Assistant", avatar: nil)
    }
}

@MainActor
struct AppStateGatewaySessionRefreshTests {
    @Test("refreshGatewaySessions surfaces failure instead of swallowing it")
    func refreshFailureSurfacesError() async {
        let service = FlakySessionOpenClawService()
        await service.setMode(.failure(URLError(.notConnectedToInternet)))
        let state = AppState(
            openClawService: service,
            bootstrapOnInit: false,
            startBackgroundLoops: false
        )

        await state.refreshGatewaySessions()

        #expect(state.errorMessage?.contains("Gateway session refresh failed") == true)
    }

    @Test("refreshGatewaySessions success updates sessions and clears prior refresh error")
    func refreshSuccessClearsRefreshError() async {
        let service = FlakySessionOpenClawService()
        let session = GatewaySession(
            id: "session-1",
            key: "session-1",
            label: "Main",
            agentId: "codex",
            model: "gpt-5.3-codex",
            status: "active",
            lastActiveAt: Date(),
            thinkingLevel: "low"
        )
        await service.setMode(.success([session]))

        let state = AppState(
            openClawService: service,
            bootstrapOnInit: false,
            startBackgroundLoops: false
        )
        state.errorMessage = "Gateway session refresh failed: stale"

        await state.refreshGatewaySessions()

        #expect(state.gatewaySessions.count == 1)
        #expect(state.gatewaySessions.first?.key == "session-1")
        #expect(state.errorMessage == nil)
    }

    @Test("refreshGatewaySessions recovers after failure then success")
    func refreshRecoversAfterFailure() async {
        let service = FlakySessionOpenClawService()
        let state = AppState(
            openClawService: service,
            bootstrapOnInit: false,
            startBackgroundLoops: false
        )

        await service.setMode(.failure(URLError(.timedOut)))
        await state.refreshGatewaySessions()
        #expect(state.errorMessage?.contains("Gateway session refresh failed") == true)

        await service.setMode(
            .success([
                GatewaySession(
                    id: "session-2",
                    key: "session-2",
                    label: "Recovered",
                    agentId: "claude-code",
                    model: nil,
                    status: "active",
                    lastActiveAt: Date(),
                    thinkingLevel: nil
                )
            ])
        )
        await state.refreshGatewaySessions()

        #expect(state.gatewaySessions.count == 1)
        #expect(state.gatewaySessions.first?.key == "session-2")
        #expect(state.errorMessage == nil)
    }
}
