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
            settingsStore: settingsStore,
            companionClient: CompanionClient()
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

    @Test
    @MainActor
    func sendDraftStoresHermesSessionIDFromStreamingResponseHeader() async throws {
        let hermesClient = HermesGatewayClient(session: makeMockSession { request in
            #expect(request.url?.path == "/v1/chat/completions")

            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "text/event-stream",
                    "X-Hermes-Session-Id": "session-xyz"
                ]
            )!
            let payload = """
            data: {"choices":[{"delta":{"content":"Fresh reply"},"finish_reason":null}]}

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
            settingsStore: settingsStore,
            companionClient: CompanionClient()
        )

        store.startNewConversation()
        let conversationID = try #require(store.selectedConversationID)
        store.draft = "Plan the new shell"

        await store.sendDraft()

        #expect(store.selectedConversation?.hermesSessionID == "session-xyz")
        let cachedConversations = try cache.loadConversations()
        let cachedConversation = try #require(cachedConversations.first { $0.id == conversationID })
        #expect(cachedConversation.hermesSessionID == "session-xyz")
    }

    @Test
    @MainActor
    func sendDraftUpsertsToolActivitiesFromStreamedProgressEvents() async throws {
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

            event: hermes.tool.progress
            data: {"tool":"web_search","emoji":"🔍","label":"Searching the web…","toolCallId":"call_1","status":"running"}

            data: {"choices":[{"delta":{"content":" reply"},"finish_reason":null}]}

            event: hermes.tool.progress
            data: {"tool":"web_search","toolCallId":"call_1","status":"completed"}

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
            settingsStore: settingsStore,
            companionClient: CompanionClient()
        )

        store.startNewConversation()
        store.draft = "Search something"

        await store.sendDraft()

        #expect(store.messages.count == 2)
        #expect(store.messages[1].content == "Fresh reply")
        #expect(store.messages[1].toolActivities.count == 1)
        let activity = try #require(store.messages[1].toolActivities.first)
        #expect(activity.id == "call_1")
        #expect(activity.tool == "web_search")
        #expect(activity.emoji == "🔍")
        #expect(activity.label == "Searching the web…")
        #expect(activity.isComplete)
    }

    @Test
    @MainActor
    func sendDraftInjectsCapabilityInstructionsOutboundOnlyNeverDisplayed() async throws {
        // ChatStreamCoordinatorTests.buildOutboundMessagesPrependsSyntheticSystemMessage…
        // covers the outbound side directly. This test guards the other half of the
        // invariant: the synthetic message must never leak into the persisted/displayed
        // transcript that the user (and the cache) sees.
        let hermesClient = HermesGatewayClient(session: makeMockSession { request in
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let payload = """
            data: {"choices":[{"delta":{"content":"Reply"},"finish_reason":null}]}

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
            settingsStore: settingsStore,
            companionClient: CompanionClient()
        )

        store.startNewConversation()
        let conversationID = try #require(store.selectedConversationID)

        store.draft = "/think"
        await store.sendDraft()
        #expect(store.capabilities(for: conversationID).contains(.thinking))

        store.draft = "Plan the launch"
        await store.sendDraft()

        // The synthetic capability system message must never reach the persisted/displayed
        // transcript — only the outbound request to Hermes should carry it.
        #expect(!store.messages.contains { $0.content.contains("Capability overrides") })
        let cachedMessages = try cache.loadMessages(conversationID: conversationID)
        #expect(!cachedMessages.contains { $0.content.contains("Capability overrides") })
    }

    @Test
    @MainActor
    func bootstrapLoadsCompanionMessagesInParallelAndTreatsFailuresAsEmpty() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()
        let conversations = [
            ChatConversation(id: firstID, title: "First"),
            ChatConversation(id: secondID, title: "Second"),
            ChatConversation(id: thirdID, title: "Third")
        ]
        let firstMessages = [
            ConversationMessage(conversationID: firstID, role: .user, content: "hello")
        ]
        let thirdMessages = [
            ConversationMessage(conversationID: thirdID, role: .assistant, content: "done")
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let companionSession = makeMockSession { request in
            let url = try #require(request.url)
            if url.path == "/v1/conversations" {
                return try Self.jsonResponse(url: url, body: encoder.encode(conversations))
            }
            if url.path == "/v1/conversations/\(firstID.uuidString)/messages" {
                return try Self.jsonResponse(url: url, body: encoder.encode(firstMessages))
            }
            if url.path == "/v1/conversations/\(secondID.uuidString)/messages" {
                throw URLError(.badServerResponse)
            }
            if url.path == "/v1/conversations/\(thirdID.uuidString)/messages" {
                return try Self.jsonResponse(url: url, body: encoder.encode(thirdMessages))
            }
            Issue.record("Unexpected companion request: \(url.path)")
            throw URLError(.unsupportedURL)
        }
        let hermesClient = HermesGatewayClient(session: makeMockSession { request in
            let url = try #require(request.url)
            if url.path == "/health" {
                return try Self.jsonResponse(url: url, body: Data())
            }
            if url.path == "/v1/models" {
                return try Self.jsonResponse(url: url, body: Data("{\"data\":[{\"id\":\"hermes-agent\"}]}".utf8))
            }
            Issue.record("Unexpected Hermes request: \(url.path)")
            throw URLError(.unsupportedURL)
        })
        let settingsStore = SettingsStore(
            repository: SettingsRepository(
                suiteName: "ChatStoreCompanionTests-\(UUID().uuidString)",
                serviceName: "ChatStoreCompanionTests-\(UUID().uuidString)"
            )
        )
        settingsStore.companionURL = "http://companion.test:8742"
        settingsStore.hermesGatewayURL = "http://hermes.test:8642"

        let store = try ChatStore(
            hermesClient: hermesClient,
            cache: AgentBoardCache(inMemory: true),
            settingsStore: settingsStore,
            companionClient: CompanionClient(session: companionSession)
        )

        await store.bootstrap()

        #expect(store.conversations.map(\.id) == [firstID, secondID, thirdID])

        store.selectConversation(firstID)
        #expect(store.messages.count == 1)
        #expect(store.messages.first?.role == .user)
        #expect(store.messages.first?.content == "hello")

        store.selectConversation(secondID)
        #expect(store.messages.isEmpty)

        store.selectConversation(thirdID)
        #expect(store.messages.count == 1)
        #expect(store.messages.first?.role == .assistant)
        #expect(store.messages.first?.content == "done")
    }

    private static func jsonResponse(url: URL, body: Data) throws -> (HTTPURLResponse, Data) {
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
        return (response, body)
    }
}
