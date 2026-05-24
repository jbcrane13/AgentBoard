import Foundation
import os

public struct ChatConversationSyncSnapshot: Sendable {
    public let conversations: [ChatConversation]
    public let messagesByConversationID: [UUID: [ConversationMessage]]
    public let selectedConversationID: UUID?

    public init(
        conversations: [ChatConversation],
        messagesByConversationID: [UUID: [ConversationMessage]],
        selectedConversationID: UUID?
    ) {
        self.conversations = conversations
        self.messagesByConversationID = messagesByConversationID
        self.selectedConversationID = selectedConversationID
    }
}

public actor ChatConversationSyncCoordinator {
    private let cache: any AgentBoardCacheProtocol
    private let companionClient: CompanionClient
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "ChatSync")

    public init(
        cache: any AgentBoardCacheProtocol,
        companionClient: CompanionClient
    ) {
        self.cache = cache
        self.companionClient = companionClient
    }

    public func initialSnapshot(companionConfigured: Bool) async -> ChatConversationSyncSnapshot {
        guard companionConfigured else {
            return await loadLocalSnapshot()
        }

        do {
            let snapshot = try await companionSnapshot(currentSelection: nil)
            try await saveToLocalCache(snapshot: snapshot)
            return snapshot
        } catch {
            logger.error(
                "Companion unreachable during chat bootstrap — falling back to local cache: \(error.localizedDescription, privacy: .public)"
            )
            return await loadLocalSnapshot()
        }
    }

    public func refreshFromCompanion(
        currentSelection: UUID?,
        companionConfigured: Bool,
        didBootstrap: Bool
    ) async throws -> ChatConversationSyncSnapshot? {
        guard companionConfigured, didBootstrap else { return nil }
        let snapshot = try await companionSnapshot(currentSelection: currentSelection)
        try await saveToLocalCache(snapshot: snapshot)
        return snapshot
    }

    public func persist(
        conversation: ChatConversation,
        messages: [ConversationMessage],
        allConversations: [ChatConversation],
        messagesByConversationID: [UUID: [ConversationMessage]],
        companionConfigured: Bool
    ) async {
        do {
            try await cache.saveConversationSnapshot(conversation: conversation, messages: messages)
        } catch {
            logger.error("Failed to persist conversation snapshot: \(error.localizedDescription, privacy: .public)")
        }

        guard companionConfigured else { return }
        await syncToCompanion(
            conversations: allConversations,
            messagesByConversationID: messagesByConversationID
        )
    }

    public func deleteConversation(
        id: UUID,
        companionConfigured: Bool
    ) async {
        do {
            try await cache.deleteConversation(id: id)
        } catch {
            logger.error("Failed to delete conversation from cache: \(error.localizedDescription, privacy: .public)")
        }

        guard companionConfigured else { return }
        do {
            try await companionClient.deleteConversationOnServer(id: id)
        } catch {
            logger.error("Failed to delete conversation from companion: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func saveToLocalCache(snapshot: ChatConversationSyncSnapshot) async throws {
        for conversation in snapshot.conversations {
            let messages = snapshot.messagesByConversationID[conversation.id] ?? []
            try await cache.saveConversationSnapshot(conversation: conversation, messages: messages)
        }
    }

    private func syncToCompanion(
        conversations: [ChatConversation],
        messagesByConversationID: [UUID: [ConversationMessage]]
    ) async {
        let messagesByConversation = Dictionary(
            uniqueKeysWithValues: conversations.map { ($0.id, messagesByConversationID[$0.id] ?? []) }
        )

        do {
            try await companionClient.syncConversations(
                conversations: conversations,
                messagesByConversation: messagesByConversation
            )
        } catch {
            logger.error("Failed to sync conversations to companion: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadLocalSnapshot() async -> ChatConversationSyncSnapshot {
        do {
            let cachedConversations = try await cache.loadConversations()
            var loadedMessages: [UUID: [ConversationMessage]] = [:]
            for conversation in cachedConversations {
                loadedMessages[conversation.id] = try await cache.loadMessages(conversationID: conversation.id)
            }
            return ChatConversationSyncSnapshot(
                conversations: cachedConversations,
                messagesByConversationID: loadedMessages,
                selectedConversationID: cachedConversations.first?.id
            )
        } catch {
            logger.error("Failed to load chat cache: \(error.localizedDescription, privacy: .public)")
            return ChatConversationSyncSnapshot(
                conversations: [],
                messagesByConversationID: [:],
                selectedConversationID: nil
            )
        }
    }

    private func companionSnapshot(currentSelection: UUID?) async throws -> ChatConversationSyncSnapshot {
        let conversations = try await companionClient.listConversations()
        let messagesByConversationID = await fetchMessagesInParallel(for: conversations)
        let selectedID = if let currentSelection,
                            conversations.contains(where: { $0.id == currentSelection }) {
            currentSelection
        } else {
            conversations.first?.id
        }

        return ChatConversationSyncSnapshot(
            conversations: conversations,
            messagesByConversationID: messagesByConversationID,
            selectedConversationID: selectedID
        )
    }

    private func fetchMessagesInParallel(
        for conversations: [ChatConversation],
        maxConcurrentFetches: Int = 8
    ) async -> [UUID: [ConversationMessage]] {
        var result: [UUID: [ConversationMessage]] = [:]
        let batchSize = max(1, maxConcurrentFetches)

        for batchStart in stride(from: 0, to: conversations.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, conversations.count)
            let batch = conversations[batchStart ..< batchEnd]
            let batchMessages = await withTaskGroup(
                of: (UUID, [ConversationMessage]).self
            ) { group -> [UUID: [ConversationMessage]] in
                for conversation in batch {
                    group.addTask { [companionClient] in
                        let messages = (try? await companionClient.loadMessages(conversationID: conversation.id)) ?? []
                        return (conversation.id, messages)
                    }
                }

                var messagesByID: [UUID: [ConversationMessage]] = [:]
                for await (id, messages) in group {
                    messagesByID[id] = messages
                }
                return messagesByID
            }
            result.merge(batchMessages) { _, new in new }
        }

        return result
    }
}
