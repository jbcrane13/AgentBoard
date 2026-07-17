import AgentBoardCore
import Foundation
import Testing

@Suite("ChatStore — capability toggles", .serialized)
struct ChatStoreCapabilityTests {
    @MainActor
    private func makeStore(hermesURL: String = "http://127.0.0.1:8642") throws -> ChatStore {
        let session = makeMockSession { _ in
            let response = try HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:8642/health")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let hermesClient = HermesGatewayClient(session: session)
        let cache = try AgentBoardCache(inMemory: true)
        let repo = SettingsRepository(
            suiteName: "CapabilityTests-\(UUID().uuidString)",
            serviceName: "CapabilityTests-\(UUID().uuidString)"
        )
        let settingsStore = SettingsStore(repository: repo)
        settingsStore.hermesGatewayURL = hermesURL
        settingsStore.hermesModelID = "hermes-agent"
        let store = ChatStore(
            hermesClient: hermesClient,
            cache: cache,
            settingsStore: settingsStore,
            companionClient: CompanionClient()
        )
        store.startNewConversation()
        return store
    }

    // MARK: - Capability toggles are handled locally (never forwarded to the agent)

    @Test
    @MainActor
    func thinkCommandIsHandledLocallyAndTogglesOn() async throws {
        let store = try makeStore()
        let conversationID = try #require(store.selectedConversationID)
        #expect(store.capabilities(for: conversationID).isEmpty)

        store.draft = "/think"
        await store.sendDraft()

        #expect(store.capabilities(for: conversationID).contains(.thinking))
        let content = try #require(store.messages.last?.content)
        #expect(content.contains("Thinking mode ON (client-side prompt injection)"))
        // Handled locally means only the notification message is present — no
        // separate agent-forwarded exchange was triggered.
        #expect(store.messages.count == 1)
    }

    @Test
    @MainActor
    func thinkCommandTwiceTogglesOffAgain() async throws {
        let store = try makeStore()
        let conversationID = try #require(store.selectedConversationID)

        store.draft = "/think"
        await store.sendDraft()
        #expect(store.capabilities(for: conversationID).contains(.thinking))

        store.draft = "/think"
        await store.sendDraft()
        #expect(!store.capabilities(for: conversationID).contains(.thinking))
        let content = try #require(store.messages.last?.content)
        #expect(content.contains("Thinking mode OFF (client-side prompt injection)"))
    }

    @Test
    @MainActor
    func capabilityTogglesArePerConversation() async throws {
        let store = try makeStore()
        let conversationA = try #require(store.selectedConversationID)

        store.draft = "/think"
        await store.sendDraft()
        #expect(store.capabilities(for: conversationA).contains(.thinking))

        store.startNewConversation()
        let conversationB = try #require(store.selectedConversationID)
        #expect(conversationB != conversationA)
        #expect(store.capabilities(for: conversationB).isEmpty)
    }

    @Test
    @MainActor
    func statusCommandListsActiveCapabilitiesWhenToggled() async throws {
        let store = try makeStore()
        store.draft = "/think"
        await store.sendDraft()

        store.draft = "/status"
        await store.sendDraft()

        let content = try #require(store.messages.last?.content)
        #expect(content.contains("Thinking (prompt-injected)"))
    }

    @Test
    @MainActor
    func statusCommandOmitsCapabilitiesLineWhenNoneActive() async throws {
        let store = try makeStore()
        store.draft = "/status"
        await store.sendDraft()

        let content = try #require(store.messages.last?.content)
        #expect(!content.contains("prompt-injected"))
    }
}
