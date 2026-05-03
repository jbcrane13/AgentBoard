import AgentBoardCompanionKit
import AgentBoardCore
import Foundation
import Testing

struct CompanionSQLiteStoreTests {
    @Test
    func makeSummariesGroupsSessionsByAgentModel() {
        let now = Date(timeIntervalSince1970: 1234)
        let sessions = [
            AgentSession(
                id: "proc-1",
                source: "Local Machine",
                status: .running,
                model: "Codex",
                startedAt: now,
                lastSeenAt: now
            ),
            AgentSession(
                id: "proc-2",
                source: "Local Machine",
                status: .running,
                model: "Claude",
                startedAt: now,
                lastSeenAt: now
            ),
            AgentSession(
                id: "proc-3",
                source: "Local Machine",
                status: .running,
                model: "Codex",
                startedAt: now,
                lastSeenAt: now
            )
        ]

        let summaries = CompanionLocalProbe.makeSummaries(
            sessions: sessions,
            now: now,
            machineName: "Local Machine"
        )

        #expect(summaries.map(\.name) == ["Codex", "Claude"])
        #expect(summaries.map(\.activeSessionCount) == [2, 1])
    }

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
