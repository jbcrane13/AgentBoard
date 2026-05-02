import AgentBoardCore
@testable import AgentBoardCompanionKit
import Foundation
import Testing

struct CompanionLocalProbeTests {
    @Test
    func makeSummariesGroupsSessionsByAgentModel() {
        let now = Date(timeIntervalSince1970: 1_234)
        let sessions = [
            AgentSession(id: "proc-1", source: "Local Machine", status: .running, model: "Codex", startedAt: now, lastSeenAt: now),
            AgentSession(id: "proc-2", source: "Local Machine", status: .running, model: "Claude", startedAt: now, lastSeenAt: now),
            AgentSession(id: "proc-3", source: "Local Machine", status: .running, model: "Codex", startedAt: now, lastSeenAt: now)
        ]

        let summaries = CompanionLocalProbe.makeSummaries(
            sessions: sessions,
            now: now,
            machineName: "Local Machine"
        )

        #expect(summaries.map(\.name) == ["Codex", "Claude"])
        #expect(summaries.map(\.activeSessionCount) == [2, 1])
    }
}
