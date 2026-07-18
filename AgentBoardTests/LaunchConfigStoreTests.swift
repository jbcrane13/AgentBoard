import AgentBoardCore
import Foundation
import Testing

@Suite("LaunchConfigStore")
struct LaunchConfigStoreTests {
    private func makeStore() -> LaunchConfigStore {
        LaunchConfigStore(defaults: UserDefaults(suiteName: "LaunchConfigStoreTests-\(UUID().uuidString)") ?? .standard)
    }

    private func makeConfig(issueNumber: Int = 200) -> SessionLauncher.LaunchConfig {
        SessionLauncher.LaunchConfig(
            taskTitle: "Fix the thing",
            issueNumber: issueNumber,
            repo: "AgentBoard",
            fullRepo: "jbcrane13/AgentBoard",
            preset: .tddSuperpowers,
            agentType: .codex,
            customInstructions: "Be thorough."
        )
    }

    @Test func configIsNilForUnknownSessionName() {
        let store = makeStore()
        #expect(store.config(forSessionName: "ab-agentboard-999") == nil)
    }

    @Test func storeThenLoadRoundTripsAllFields() {
        let store = makeStore()
        let config = makeConfig()

        store.store(config, forSessionName: "ab-agentboard-200")
        let loaded = store.config(forSessionName: "ab-agentboard-200")

        #expect(loaded?.taskTitle == config.taskTitle)
        #expect(loaded?.issueNumber == config.issueNumber)
        #expect(loaded?.repo == config.repo)
        #expect(loaded?.fullRepo == config.fullRepo)
        #expect(loaded?.preset == config.preset)
        #expect(loaded?.agentType == config.agentType)
        #expect(loaded?.customInstructions == config.customInstructions)
    }

    @Test func storeKeepsEntriesForDifferentSessionNamesIndependent() {
        let store = makeStore()
        store.store(makeConfig(issueNumber: 201), forSessionName: "ab-agentboard-201")
        store.store(makeConfig(issueNumber: 202), forSessionName: "ab-agentboard-202")

        #expect(store.config(forSessionName: "ab-agentboard-201")?.issueNumber == 201)
        #expect(store.config(forSessionName: "ab-agentboard-202")?.issueNumber == 202)
    }

    @Test func removeDropsOnlyTheNamedSession() {
        let store = makeStore()
        store.store(makeConfig(issueNumber: 203), forSessionName: "ab-agentboard-203")
        store.store(makeConfig(issueNumber: 204), forSessionName: "ab-agentboard-204")

        store.remove(sessionName: "ab-agentboard-203")

        #expect(store.config(forSessionName: "ab-agentboard-203") == nil)
        #expect(store.config(forSessionName: "ab-agentboard-204")?.issueNumber == 204)
    }
}
