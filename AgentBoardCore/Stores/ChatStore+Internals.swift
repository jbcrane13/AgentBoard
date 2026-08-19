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

    /// Switches the active Hermes profile to the one `conversation` is bound to, when it names a
    /// known profile other than the one already active. The client reconfiguration (base URL,
    /// API key) that follows is fire-and-forget: `selectedConversationID` and the profile fields
    /// on `settingsStore` are already updated synchronously by the time this returns.
    func switchProfileIfNeeded(for conversation: ChatConversation) {
        guard let profileID = conversation.profileID,
              profileID != settingsStore.selectedHermesProfileID,
              settingsStore.hermesProfiles.contains(where: { $0.id == profileID }) else { return }
        settingsStore.selectHermesProfile(id: profileID)
        Task { try? await configureClient() }
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
            setLastFailedSend: { [weak self] request in self?.lastFailedSend = request },
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

    /// Re-issues the most recently failed `sendDraft()` call. Drops the failed assistant
    /// placeholder message first, if one was left behind with no content.
    public func retryLastSend() async {
        guard let request = lastFailedSend else { return }

        if let lastMessage = messagesByConversationID[request.conversationID]?.last,
           lastMessage.role == .assistant, lastMessage.content.isEmpty {
            messagesByConversationID[request.conversationID]?.removeLast()
        }
        lastFailedSend = nil
        errorMessage = nil
        statusMessage = nil

        let outcome = await streamCoordinator.send(
            request: request,
            callbacks: streamCallbacks(for: request.conversationID)
        )
        statusMessage = outcome.statusMessage
        errorMessage = outcome.errorMessage
        connectionState = outcome.connectionState
    }
}

private struct ChatPersistenceContext {
    let conversation: ChatConversation
    let messages: [ConversationMessage]
    let conversations: [ChatConversation]
    let messagesByConversationID: [UUID: [ConversationMessage]]
    let companionConfigured: Bool
}
