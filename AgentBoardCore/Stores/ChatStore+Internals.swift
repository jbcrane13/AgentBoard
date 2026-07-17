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

    /// Best-effort hydration for conversations synced without local message history: if the
    /// conversation carries a Hermes session id and no messages have loaded locally yet, fetch
    /// the session's transcript from the gateway. Failures are logged and ignored — local state
    /// (empty though it may be) always wins.
    func hydrateFromHermesSessionIfNeeded(conversationID: UUID) {
        guard let sessionID = conversations.first(where: { $0.id == conversationID })?.hermesSessionID,
              (messagesByConversationID[conversationID] ?? []).isEmpty else { return }

        Task {
            do {
                try await configureClient()
                let messages = try await hermesClient.fetchSessionMessages(
                    sessionID: sessionID,
                    conversationID: conversationID
                )
                guard !messages.isEmpty, selectedConversationID == conversationID else { return }
                messagesByConversationID[conversationID] = messages
                await persistNow(conversationID: conversationID)
            } catch {
                logger.error("Hermes session hydration failed: \(error.localizedDescription, privacy: .public)")
            }
        }
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
