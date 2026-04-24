import Foundation
import Observation
import os

@MainActor
@Observable
public final class ChatStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "ChatStore")
    private let hermesClient: HermesGatewayClient
    private let cache: AgentBoardCache
    private let settingsStore: SettingsStore

    public private(set) var conversations: [ChatConversation] = []
    public var selectedConversationID: UUID?
    public private(set) var availableModels: [String] = []
    public private(set) var connectionState: ChatConnectionState = .disconnected
    public private(set) var isStreaming = false
    public var draft = ""
    public var statusMessage: String?
    public var errorMessage: String?

    private var messagesByConversationID: [UUID: [ConversationMessage]] = [:]
    private var didBootstrap = false

    public init(
        hermesClient: HermesGatewayClient,
        cache: AgentBoardCache,
        settingsStore: SettingsStore
    ) {
        self.hermesClient = hermesClient
        self.cache = cache
        self.settingsStore = settingsStore
    }

    public var messages: [ConversationMessage] {
        guard let selectedConversationID else { return [] }
        return messagesByConversationID[selectedConversationID] ?? []
    }

    public var selectedConversation: ChatConversation? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    public func bootstrap() async {
        guard !didBootstrap else { return }
        loadCachedConversations()

        if conversations.isEmpty {
            startNewConversation()
        }

        await refreshConnection()
        await refreshModels()
        didBootstrap = true
    }

    public func startNewConversation() {
        let conversation = ChatConversation(
            title: "New Conversation",
            modelID: settingsStore.hermesModelID.trimmedOrNil ?? availableModels.first ?? "hermes-agent"
        )
        conversations.insert(conversation, at: 0)
        messagesByConversationID[conversation.id] = []
        selectedConversationID = conversation.id
        persist(conversationID: conversation.id)
    }

    public func selectConversation(_ id: UUID) {
        selectedConversationID = id
    }

    public func renameConversation(id: UUID, title: String) {
        guard var conversation = conversations.first(where: { $0.id == id }) else { return }
        conversation.title = title
        conversation.updatedAt = .now
        upsert(conversation)
        persist(conversationID: id)
    }

    public func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }
        messagesByConversationID.removeValue(forKey: id)

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }

        do {
            try cache.deleteConversation(id: id)
        } catch {
            logger.error("Failed to delete conversation from cache: \(error.localizedDescription, privacy: .public)")
        }

        if conversations.isEmpty {
            startNewConversation()
        }
    }

    public func refreshConnection() async {
        errorMessage = nil
        statusMessage = nil
        connectionState = .connecting

        do {
            try await configureClient()
            let isHealthy = try await hermesClient.healthCheck()
            connectionState = isHealthy ? .connected : .failed
            statusMessage = isHealthy ? "Hermes gateway is reachable." : nil
        } catch {
            logger.error("Hermes health check failed: \(error.localizedDescription, privacy: .public)")
            connectionState = .failed
            errorMessage = error.localizedDescription
        }
    }

    public func refreshModels() async {
        do {
            try await configureClient()
            let models = try await hermesClient.fetchModels()
            availableModels = models.isEmpty
                ? [settingsStore.hermesModelID.trimmedOrNil ?? "hermes-agent"]
                : models.sortedCaseInsensitive()

            if settingsStore.hermesModelID.trimmedOrNil == nil, let firstModel = availableModels.first {
                settingsStore.hermesModelID = firstModel
            }
        } catch {
            logger.error("Hermes model refresh failed: \(error.localizedDescription, privacy: .public)")
            if availableModels.isEmpty {
                availableModels = [settingsStore.hermesModelID.trimmedOrNil ?? "hermes-agent"]
            }
            errorMessage = error.localizedDescription
        }
    }

    public func sendDraft() async {
        let trimmed = draft.trimmed
        guard !trimmed.isEmpty, let conversationID = selectedConversationID else { return }

        draft = ""
        errorMessage = nil
        statusMessage = nil

        var conversation = selectedConversation ?? ChatConversation(id: conversationID, title: "Conversation")
        let currentMessages = messagesByConversationID[conversationID] ?? []

        let userMessage = ConversationMessage(
            conversationID: conversationID,
            role: .user,
            content: trimmed
        )
        var assistantMessage = ConversationMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            isStreaming: true
        )

        let requestConversation = currentMessages + [userMessage]
        messagesByConversationID[conversationID] = requestConversation + [assistantMessage]

        if conversation.title == "New Conversation" {
            conversation.title = String(trimmed.prefix(48))
        }
        conversation.updatedAt = .now
        upsert(conversation)
        persist(conversationID: conversationID)

        isStreaming = true
        connectionState = connectionState == .connected ? .connected : .connecting

        do {
            try await configureClient()
            let stream = try await hermesClient.streamReply(for: requestConversation)
            connectionState = .connected

            for try await chunk in stream {
                assistantMessage.content += chunk
                updateMessage(assistantMessage, in: conversationID)
            }

            assistantMessage.isStreaming = false
            updateMessage(assistantMessage, in: conversationID)
            isStreaming = false
            statusMessage = "Reply streamed from Hermes."

            if var updatedConversation = selectedConversation {
                updatedConversation.updatedAt = .now
                updatedConversation.modelID = settingsStore.hermesModelID.trimmedOrNil
                upsert(updatedConversation)
            }
            persist(conversationID: conversationID)
        } catch {
            logger.error("Streaming reply failed: \(error.localizedDescription, privacy: .public)")
            connectionState = .failed
            errorMessage = error.localizedDescription
            isStreaming = false

            if assistantMessage.content.isEmpty {
                removeMessage(id: assistantMessage.id, conversationID: conversationID)
            } else {
                assistantMessage.isStreaming = false
                updateMessage(assistantMessage, in: conversationID)
            }
            persist(conversationID: conversationID)
        }
    }

    private func configureClient() async throws {
        try await hermesClient.configure(
            baseURL: settingsStore.hermesGatewayURL,
            apiKey: settingsStore.hermesAPIKey.trimmedOrNil,
            preferredModelID: settingsStore.hermesModelID.trimmedOrNil
        )
    }

    private func loadCachedConversations() {
        do {
            let cachedConversations = try cache.loadConversations()
            conversations = cachedConversations

            var loadedMessages: [UUID: [ConversationMessage]] = [:]
            for conversation in cachedConversations {
                loadedMessages[conversation.id] = try cache.loadMessages(conversationID: conversation.id)
            }
            messagesByConversationID = loadedMessages
            selectedConversationID = cachedConversations.first?.id
        } catch {
            logger.error("Failed to load chat cache: \(error.localizedDescription, privacy: .public)")
            conversations = []
            messagesByConversationID = [:]
            errorMessage = error.localizedDescription
        }
    }

    private func persist(conversationID: UUID) {
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else { return }
        let messages = messagesByConversationID[conversationID] ?? []

        do {
            try cache.saveConversationSnapshot(conversation: conversation, messages: messages)
        } catch {
            logger.error("Failed to persist conversation snapshot: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    private func upsert(_ conversation: ChatConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }

        conversations.sort { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
    }

    private func updateMessage(_ message: ConversationMessage, in conversationID: UUID) {
        guard var messages = messagesByConversationID[conversationID],
              let index = messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }
        messages[index] = message
        messagesByConversationID[conversationID] = messages
    }

    private func removeMessage(id: UUID, conversationID: UUID) {
        guard var messages = messagesByConversationID[conversationID] else { return }
        messages.removeAll { $0.id == id }
        messagesByConversationID[conversationID] = messages
    }
}
