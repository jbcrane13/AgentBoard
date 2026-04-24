import AgentBoardCore
import Foundation
import Testing

@Suite(.serialized)
struct ChatStoreTests {
    @Test
    @MainActor
    func sendDraftStreamsAssistantReplyAndCachesConversation() async throws {
        let hermesClient = HermesGatewayClient(session: makeMockSession { request in
            #expect(request.url?.path == "/v1/chat/completions")

            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let payload = """
            data: {"choices":[{"delta":{"content":"Fresh"},"finish_reason":null}]}

            data: {"choices":[{"delta":{"content":" reply"},"finish_reason":null}]}

            data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

            data: [DONE]

            """
            return (response, Data(payload.utf8))
        })

        let suiteName = "ChatStoreTests-\(UUID().uuidString)"
        let repository = SettingsRepository(
            suiteName: suiteName,
            serviceName: "ChatStoreTests-\(UUID().uuidString)"
        )
        let settingsStore = SettingsStore(repository: repository)
        settingsStore.hermesGatewayURL = "http://127.0.0.1:8642"
        settingsStore.hermesModelID = "hermes-agent"

        let cache = try AgentBoardCache(inMemory: true)
        let store = ChatStore(
            hermesClient: hermesClient,
            cache: cache,
            settingsStore: settingsStore
        )

        store.startNewConversation()
        store.draft = "Plan the new shell"

        await store.sendDraft()

        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[1].role == .assistant)
        #expect(store.messages[1].content == "Fresh reply")
        #expect(store.isStreaming == false)

        let cachedConversations = try cache.loadConversations()
        #expect(cachedConversations.count == 1)
        let cachedMessages = try cache.loadMessages(conversationID: cachedConversations[0].id)
        #expect(cachedMessages.count == 2)
    }
}
