import AgentBoardCompanionKit
import AgentBoardCore
import Foundation
import Testing

struct CompanionSQLiteStoreTests {
    @Test
    func replaceSessionsAndAgents() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appending(path: "agentboard-tests-\(UUID().uuidString).sqlite")

        let store = try CompanionSQLiteStore(databaseURL: databaseURL)
        try await store.initializeSchema()

        let repository = ConfiguredRepository(owner: "openai", name: "agentboard")
        let workReference = WorkReference(repository: repository, issueNumber: 7)

        try await store.replaceSessions(
            [
                AgentSession(
                    id: "proc-7",
                    source: "Blake's MacBook Pro",
                    status: .running,
                    linkedTaskID: "task-7",
                    workItem: workReference,
                    model: "hermes-agent"
                )
            ]
        )

        try await store.replaceAgents(
            [
                AgentSummary(
                    id: "codex",
                    name: "Codex",
                    health: .online,
                    activeTaskCount: 1,
                    activeSessionCount: 1,
                    recentActivity: "Running locally."
                )
            ]
        )

        let sessions = try await store.listSessions()
        let agents = try await store.listAgents()

        #expect(sessions.count == 1)
        #expect(sessions[0].workItem?.issueReference == "openai/agentboard#7")
        #expect(agents.count == 1)
        #expect(agents[0].health == .online)
    }
}
