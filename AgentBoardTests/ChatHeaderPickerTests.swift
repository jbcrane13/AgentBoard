import AgentBoardCore
import Foundation
import Testing

/// Verifies the contract relied on by the desktop chat header session/profile pickers
/// (issue #77). The pickers in `ChatScreen` invoke these store APIs when the user picks
/// an item, so this exercises the observable-state changes they depend on.
@Suite("Chat header pickers", .serialized)
@MainActor
struct ChatHeaderPickerTests {
    private func makeSettingsStore() -> SettingsStore {
        let repo = SettingsRepository(
            suiteName: "ChatHeaderPickerTests-\(UUID().uuidString)",
            serviceName: "ChatHeaderPickerTests-\(UUID().uuidString)"
        )
        let store = SettingsStore(repository: repo)
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.hermesModelID = "hermes-agent"
        return store
    }

    private func makeChatStore(settingsStore: SettingsStore) throws -> ChatStore {
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
        return ChatStore(hermesClient: hermesClient, cache: cache, settingsStore: settingsStore)
    }

    // MARK: - Profile picker contract

    @Test
    func virtualProfileUsesCurrentSentinelID() {
        // The desktop profile menu skips `selectHermesProfile` when `profile.id == "current"`,
        // so the virtual fallback profile must keep that exact id.
        let store = makeSettingsStore()
        let profiles = store.availableHermesProfiles
        #expect(profiles.count == 1)
        #expect(profiles[0].id == "current")
    }

    @Test
    func pickingSavedProfileUpdatesActiveProfile() throws {
        let store = makeSettingsStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.saveCurrentHermesProfile(named: "Local")
        store.hermesGatewayURL = "http://127.0.0.1:9000"
        store.saveCurrentHermesProfile(named: "Remote")

        let localID = try #require(store.hermesProfiles.first { $0.name == "Local" }?.id)
        let remoteID = try #require(store.hermesProfiles.first { $0.name == "Remote" }?.id)

        // Simulate picking "Local" from the picker.
        store.selectHermesProfile(id: localID)
        #expect(store.activeHermesProfile?.id == localID)
        #expect(store.hermesGatewayURL == "http://127.0.0.1:8642")

        // Now simulate picking "Remote".
        store.selectHermesProfile(id: remoteID)
        #expect(store.activeHermesProfile?.id == remoteID)
        #expect(store.hermesGatewayURL == "http://127.0.0.1:9000")
    }

    // MARK: - Session picker contract

    @Test
    func pickingSessionUpdatesSelectedConversation() throws {
        let settings = makeSettingsStore()
        let store = try makeChatStore(settingsStore: settings)
        store.startNewConversation()
        store.startNewConversation()
        let firstID = store.conversations[1].id
        let secondID = store.conversations[0].id

        // Simulate picking the first session from the picker.
        store.selectConversation(firstID)
        #expect(store.selectedConversation?.id == firstID)

        // And switching back via the picker.
        store.selectConversation(secondID)
        #expect(store.selectedConversation?.id == secondID)
    }

    @Test
    func pickingNewSessionCreatesAndSelectsIt() throws {
        let settings = makeSettingsStore()
        let store = try makeChatStore(settingsStore: settings)
        store.startNewConversation()
        let originalID = try #require(store.selectedConversationID)

        // Simulate the "New Session" picker action.
        store.startNewConversation()

        #expect(store.conversations.count == 2)
        #expect(store.selectedConversationID != originalID)
        #expect(store.selectedConversationID == store.conversations[0].id)
    }

    // MARK: - Edge cases

    @Test
    func pickingDeletedSessionLeavesSelectionUntouched() throws {
        // Race condition: a session is deleted between menu render and click.
        // The picker passes a now-stale UUID; selection must not become a phantom id.
        let settings = makeSettingsStore()
        let store = try makeChatStore(settingsStore: settings)
        store.startNewConversation()
        let validID = try #require(store.selectedConversationID)

        store.selectConversation(UUID())

        #expect(store.selectedConversationID == validID)
        #expect(store.selectedConversation?.id == validID)
    }

    @Test
    func pickingUnknownProfileLeavesActiveProfileUntouched() throws {
        // Race condition: a profile is removed between menu render and click.
        // SettingsStore.selectHermesProfile silently returns; verify state is preserved.
        let store = makeSettingsStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.saveCurrentHermesProfile(named: "Local")
        let localID = try #require(store.hermesProfiles.first { $0.name == "Local" }?.id)
        let originalURL = store.hermesGatewayURL

        store.selectHermesProfile(id: "ghost-profile-id")

        #expect(store.activeHermesProfile?.id == localID)
        #expect(store.hermesGatewayURL == originalURL)
    }
}
