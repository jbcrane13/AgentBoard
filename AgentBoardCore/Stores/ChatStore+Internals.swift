import Foundation

extension ChatStore {
    func configureClient() async throws {
        try endpointValidator.validate(
            hermesGatewayURL: settingsStore.hermesGatewayURL,
            companionURL: settingsStore.companionURL
        )
        try await hermesClient.configure(
            baseURL: settingsStore.hermesGatewayURL,
            apiKey: settingsStore.hermesAPIKey.trimmedOrNil,
            preferredModelID: settingsStore.hermesModelID.trimmedOrNil
        )
    }

    func apply(_ snapshot: ChatConversationSyncSnapshot) {
        conversations = snapshot.conversations
        messagesByConversationID = snapshot.messagesByConversationID
        selectedConversationID = snapshot.selectedConversationID
    }

    func streamCallbacks(for conversationID: UUID) -> ChatStreamCallbacks {
        ChatStreamCallbacks(
            setStatusMessage: { [weak self] message in self?.statusMessage = message },
            setConnectionState: { [weak self] state in self?.connectionState = state },
            setIsStreaming: { [weak self] isStreaming in self?.isStreaming = isStreaming },
            replaceMessages: { [weak self] messages in
                self?.messagesByConversationID[conversationID] = messages
            },
            upsertConversation: { [weak self] conversation in self?.upsert(conversation) },
            persist: { [weak self] in await self?.persistNow(conversationID: conversationID) }
        )
    }

    func persist(conversationID: UUID) {
        guard let context = persistenceContext(conversationID: conversationID) else { return }
        Task {
            await syncCoordinator.persist(
                conversation: context.conversation,
                messages: context.messages,
                allConversations: context.conversations,
                messagesByConversationID: context.messagesByConversationID,
                companionConfigured: context.companionConfigured
            )
        }
    }

    func persistNow(conversationID: UUID) async {
        guard let context = persistenceContext(conversationID: conversationID) else { return }
        await syncCoordinator.persist(
            conversation: context.conversation,
            messages: context.messages,
            allConversations: context.conversations,
            messagesByConversationID: context.messagesByConversationID,
            companionConfigured: context.companionConfigured
        )
    }

    func upsert(_ conversation: ChatConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
        conversations.sort { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
    }

    func clearDraft() {
        draft = ""
        pendingAttachments = []
    }

    func appendSystemMessage(_ content: String, to conversationID: UUID) async {
        let message = ConversationMessage(
            conversationID: conversationID,
            role: .assistant,
            content: content
        )
        var current = messagesByConversationID[conversationID] ?? []
        current.append(message)
        messagesByConversationID[conversationID] = current
        await persistNow(conversationID: conversationID)
    }

    private func persistenceContext(conversationID: UUID) -> ChatPersistenceContext? {
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else { return nil }
        return ChatPersistenceContext(
            conversation: conversation,
            messages: messagesByConversationID[conversationID] ?? [],
            conversations: conversations,
            messagesByConversationID: messagesByConversationID,
            companionConfigured: settingsStore.isCompanionConfigured
        )
    }
}

private struct ChatPersistenceContext {
    let conversation: ChatConversation
    let messages: [ConversationMessage]
    let conversations: [ChatConversation]
    let messagesByConversationID: [UUID: [ConversationMessage]]
    let companionConfigured: Bool
}
