import AgentBoardCore
import Foundation
import Testing

@Suite("ChatStore — additional coverage", .serialized)
struct ChatStoreAdditionalTests {
    @MainActor
    private func makeStore(
        hermesURL: String = "http://127.0.0.1:8642",
        companionURL: String = "http://127.0.0.1:8742"
    ) throws -> ChatStore {
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
            suiteName: "ChatStoreAdditional-\(UUID().uuidString)",
            serviceName: "ChatStoreAdditional-\(UUID().uuidString)"
        )
        let settingsStore = SettingsStore(repository: repo)
        settingsStore.hermesGatewayURL = hermesURL
        settingsStore.companionURL = companionURL
        settingsStore.hermesModelID = "hermes-agent"
        return ChatStore(hermesClient: hermesClient, cache: cache, settingsStore: settingsStore)
    }

    // MARK: - bootstrap

    @Test
    @MainActor
    func bootstrapCreatesConversationWhenCacheEmpty() async throws {
        let store = try makeStore()
        await store.bootstrap()
        #expect(store.conversations.count == 1)
        #expect(store.selectedConversationID != nil)
    }

    @Test
    @MainActor
    func bootstrapIsIdempotent() async throws {
        let store = try makeStore()
        await store.bootstrap()
        let convID = store.selectedConversationID
        await store.bootstrap()
        #expect(store.selectedConversationID == convID)
        #expect(store.conversations.count == 1)
    }

    // MARK: - startNewConversation / selectConversation / renameConversation

    @Test
    @MainActor
    func startNewConversationAddsEntry() throws {
        let store = try makeStore()
        store.startNewConversation()
        #expect(store.conversations.count == 1)
        #expect(store.selectedConversationID == store.conversations[0].id)
    }

    @Test
    @MainActor
    func startNewConversationTitlesNewConversation() throws {
        let store = try makeStore()
        store.startNewConversation()
        #expect(store.conversations[0].title == "New Conversation")
    }

    @Test
    @MainActor
    func selectConversationSwitchesSelection() throws {
        let store = try makeStore()
        store.startNewConversation()
        store.startNewConversation()
        let firstID = store.conversations[1].id
        store.selectConversation(firstID)
        #expect(store.selectedConversationID == firstID)
    }

    @Test
    @MainActor
    func renameConversationUpdatesTitle() throws {
        let store = try makeStore()
        store.startNewConversation()
        let id = store.conversations[0].id
        store.renameConversation(id: id, title: "My Chat")
        #expect(store.conversations[0].title == "My Chat")
    }

    @Test
    @MainActor
    func renameConversationIgnoresBlankTitle() throws {
        let store = try makeStore()
        store.startNewConversation()
        let id = store.conversations[0].id
        store.renameConversation(id: id, title: "   ")
        #expect(store.conversations[0].title == "New Conversation")
    }

    // MARK: - deleteConversation

    @Test
    @MainActor
    func deleteConversationRemovesItAndCreatesNewIfEmpty() throws {
        let store = try makeStore()
        store.startNewConversation()
        let id = store.conversations[0].id
        store.deleteConversation(id: id)
        // Store auto-creates a new conversation when the last one is deleted
        #expect(store.conversations.count == 1)
        #expect(store.conversations[0].id != id)
    }

    @Test
    @MainActor
    func deleteConversationUpdatesSelectionWhenDeleted() throws {
        let store = try makeStore()
        store.startNewConversation()
        store.startNewConversation()
        let selectedID = try #require(store.selectedConversationID)
        store.deleteConversation(id: selectedID)
        #expect(store.selectedConversationID != selectedID)
    }

    // MARK: - Attachment management

    @Test
    @MainActor
    func addAttachmentAppendsToList() throws {
        let store = try makeStore()
        let attachment = ChatAttachment(
            type: .image,
            payload: .image(ImageAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/img.jpg")))
        )
        store.addAttachment(attachment)
        #expect(store.pendingAttachments.count == 1)
    }

    @Test
    @MainActor
    func removeAttachmentDeletesByID() throws {
        let store = try makeStore()
        let attachment = ChatAttachment(
            type: .image,
            payload: .image(ImageAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/img.jpg")))
        )
        store.addAttachment(attachment)
        store.removeAttachment(id: attachment.id)
        #expect(store.pendingAttachments.isEmpty)
    }

    @Test
    @MainActor
    func clearAttachmentsEmptiesAll() throws {
        let store = try makeStore()
        store.addAttachment(ChatAttachment(
            type: .image,
            payload: .image(ImageAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/a.jpg")))
        ))
        store.addAttachment(ChatAttachment(
            type: .image,
            payload: .image(ImageAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/b.jpg")))
        ))
        store.clearAttachments()
        #expect(store.pendingAttachments.isEmpty)
    }

    // MARK: - Endpoint validation (tested indirectly via sendDraft)

    @Test
    @MainActor
    func sendDraftRejectsWhenHermesMatchesCompanionEndpoint() async throws {
        // Both point to the same host:port
        let store = try makeStore(
            hermesURL: "http://127.0.0.1:8742",
            companionURL: "http://127.0.0.1:8742"
        )
        store.startNewConversation()
        store.draft = "Hello"
        await store.sendDraft()
        #expect(store.errorMessage != nil)
        #expect(store.messages.isEmpty)
    }

    @Test
    @MainActor
    func sendDraftRejectsHTTPSForLocalHermesEndpoint() async throws {
        let store = try makeStore(hermesURL: "https://127.0.0.1:8642")
        store.startNewConversation()
        store.draft = "Hello"
        await store.sendDraft()
        #expect(store.errorMessage != nil)
        #expect(store.messages.isEmpty)
    }

    @Test
    @MainActor
    func sendDraftRejectsHTTPSForTailscaleEndpoint() async throws {
        let store = try makeStore(hermesURL: "https://100.80.1.1:8642")
        store.startNewConversation()
        store.draft = "Hello"
        await store.sendDraft()
        #expect(store.errorMessage != nil)
    }

    @Test
    @MainActor
    func sendDraftAllowsHTTPSForPublicEndpoint() async throws {
        // Public host — HTTPS should be allowed (no validation error)
        // The mock will fail the actual request, but the error should be a network error, not a validation error
        let store = try makeStore(hermesURL: "https://api.example.com:8642")
        store.startNewConversation()
        store.draft = "Hello"
        await store.sendDraft()
        // Should not be a local-endpoint HTTPS error
        if let error = store.errorMessage {
            #expect(!error.contains("HTTPS"))
        }
    }

    // MARK: - selectModel

    @Test
    @MainActor
    func selectModelUpdatesSettingsStore() throws {
        let store = try makeStore()
        store.startNewConversation()

        // Manually call selectModel (avoiding the need for a live model list)
        let settingsRepo = SettingsRepository(
            suiteName: "selectModel-\(UUID().uuidString)",
            serviceName: "selectModel-\(UUID().uuidString)"
        )
        let settings = SettingsStore(repository: settingsRepo)
        let cache = try AgentBoardCache(inMemory: true)
        let client = HermesGatewayClient(session: makeMockSession { _ in
            let response = try HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:8642")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        })
        settings.hermesGatewayURL = "http://127.0.0.1:8642"
        let s = ChatStore(hermesClient: client, cache: cache, settingsStore: settings)
        s.startNewConversation()
        s.selectModel("hermes-pro")
        #expect(settings.hermesModelID == "hermes-pro")
        #expect(s.statusMessage?.contains("hermes-pro") == true)
    }

    // MARK: - canSendDraft (Enter-to-send guard)

    @Test
    @MainActor
    func canSendDraftFalseWhenDraftIsEmpty() throws {
        let store = try makeStore()
        store.startNewConversation()
        store.draft = ""
        #expect(store.canSendDraft == false)
    }

    @Test
    @MainActor
    func canSendDraftFalseWhenDraftIsWhitespaceOnly() throws {
        let store = try makeStore()
        store.startNewConversation()
        store.draft = "   \n  "
        #expect(store.canSendDraft == false)
    }

    @Test
    @MainActor
    func canSendDraftTrueWhenDraftHasContent() throws {
        let store = try makeStore()
        store.startNewConversation()
        store.draft = "Hello Hermes"
        #expect(store.canSendDraft == true)
    }

    @Test
    @MainActor
    func canSendDraftTrueWhenAttachmentsOnlyNoText() throws {
        let store = try makeStore()
        store.startNewConversation()
        store.draft = ""
        store.addAttachment(ChatAttachment(
            type: .image,
            payload: .image(ImageAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/img.jpg")))
        ))
        #expect(store.canSendDraft == true)
    }

    @Test
    @MainActor
    func canSendDraftTrueWhenWhitespaceTextWithAttachment() throws {
        let store = try makeStore()
        store.startNewConversation()
        store.draft = "   "
        store.addAttachment(ChatAttachment(
            type: .image,
            payload: .image(ImageAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/img.jpg")))
        ))
        #expect(store.canSendDraft == true)
    }
}
