import Foundation
import Observation
import os

@MainActor
@Observable
public final class ChatStore {
    @ObservationIgnored
    let logger = Logger(subsystem: "com.agentboard.modern", category: "ChatStore")
    @ObservationIgnored
    let hermesClient: HermesGatewayClient
    @ObservationIgnored
    let settingsStore: SettingsStore
    @ObservationIgnored
    let endpointValidator: ChatEndpointValidator
    @ObservationIgnored
    let syncCoordinator: ChatConversationSyncCoordinator
    @ObservationIgnored
    let streamCoordinator: ChatStreamCoordinator

    public internal(set) var conversations: [ChatConversation] = []
    public var selectedConversationID: UUID?
    public private(set) var availableModels: [String] = []
    public internal(set) var connectionState: ChatConnectionState = .disconnected
    public internal(set) var isStreaming = false
    public var draft = ""
    public var statusMessage: String?
    public var errorMessage: String?
    public var pendingAttachments: [ChatAttachment] = []

    var messagesByConversationID: [UUID: [ConversationMessage]] = [:]
    var didBootstrap = false
    private var conversationCapabilities: [UUID: Set<ChatCapability>] = [:]

    public init(
        hermesClient: HermesGatewayClient,
        cache: any AgentBoardCacheProtocol,
        settingsStore: SettingsStore,
        companionClient: CompanionClient,
        uploadService: AttachmentUploadService = AttachmentUploadService(),
        linkPreviewService: LinkPreviewService = LinkPreviewService(),
        endpointValidator: ChatEndpointValidator = ChatEndpointValidator()
    ) {
        self.hermesClient = hermesClient
        self.settingsStore = settingsStore
        self.endpointValidator = endpointValidator
        syncCoordinator = ChatConversationSyncCoordinator(cache: cache, companionClient: companionClient)
        streamCoordinator = ChatStreamCoordinator(
            hermesClient: hermesClient,
            settingsStore: settingsStore,
            uploadService: uploadService,
            linkPreviewService: linkPreviewService,
            endpointValidator: endpointValidator
        )
    }

    public var canSendDraft: Bool {
        !isStreaming && (draft.trimmedOrNil != nil || !pendingAttachments.isEmpty)
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
        apply(await syncCoordinator.initialSnapshot(companionConfigured: settingsStore.isCompanionConfigured))

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
        guard conversations.contains(where: { $0.id == id }) else { return }
        selectedConversationID = id
        hydrateFromHermesSessionIfNeeded(conversationID: id)
    }

    public func renameConversation(id: UUID, title: String) {
        guard var conversation = conversations.first(where: { $0.id == id }),
              let trimmedTitle = title.trimmedOrNil else { return }
        conversation.title = trimmedTitle
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

        let companionConfigured = settingsStore.isCompanionConfigured
        Task {
            await syncCoordinator.deleteConversation(id: id, companionConfigured: companionConfigured)
        }

        if conversations.isEmpty {
            startNewConversation()
        }
    }

    public func selectModel(_ modelID: String) {
        guard let trimmedModelID = modelID.trimmedOrNil else { return }
        settingsStore.hermesModelID = trimmedModelID

        if var conversation = selectedConversation {
            conversation.modelID = trimmedModelID
            conversation.updatedAt = .now
            upsert(conversation)
            persist(conversationID: conversation.id)
        }

        statusMessage = "Using \(trimmedModelID)."
        errorMessage = nil
    }

    public func capabilities(for conversationID: UUID) -> Set<ChatCapability> {
        conversationCapabilities[conversationID] ?? []
    }

    @discardableResult
    public func toggleCapability(_ capability: ChatCapability, for conversationID: UUID) -> Bool {
        var current = conversationCapabilities[conversationID] ?? []
        let isOn: Bool
        if current.contains(capability) {
            current.remove(capability)
            isOn = false
        } else {
            current.insert(capability)
            isOn = true
        }
        conversationCapabilities[conversationID] = current
        return isOn
    }

    public func addAttachment(_ attachment: ChatAttachment) {
        pendingAttachments.append(attachment)
    }

    public func removeAttachment(id: String) {
        pendingAttachments.removeAll { $0.id == id }
    }

    public func clearAttachments() {
        pendingAttachments.removeAll()
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

    public func refreshConversationsFromCompanion() async {
        do {
            guard let snapshot = try await syncCoordinator.refreshFromCompanion(
                currentSelection: selectedConversationID,
                companionConfigured: settingsStore.isCompanionConfigured,
                didBootstrap: didBootstrap
            ) else { return }
            apply(snapshot)
            logger.info("Conversations refreshed from companion: \(snapshot.conversations.count) conversations")
        } catch {
            logger
                .error(
                    "Failed to refresh conversations from companion: \(error.localizedDescription, privacy: .public)"
                )
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

    public func autoReconnectIfNeeded() async {
        guard connectionState == .failed || connectionState == .disconnected else { return }
        logger.info("Auto-reconnecting after background/foreground transition")
        await refreshConnection()
        if connectionState == .connected {
            await refreshModels()
        }
    }

    public func sendDraftWithRetry(maxAttempts: Int = 2) async {
        for attempt in 0 ..< maxAttempts {
            await sendDraft()
            if errorMessage == nil || attempt == maxAttempts - 1 { return }
            logger.info("Send failed (attempt \(attempt + 1)/\(maxAttempts)), retrying...")
            errorMessage = nil
            try? await Task.sleep(for: .seconds(1))
        }
    }

    public func diagnoseConnection() async {
        errorMessage = nil
        statusMessage = "Checking Hermes health..."
        connectionState = .connecting

        do {
            try await configureClient()
            let config = await hermesClient.currentConfiguration()
            let isHealthy = try await hermesClient.healthCheck()
            guard isHealthy else {
                connectionState = .failed
                errorMessage = "Hermes responded at \(config.baseURL), but /health did not return OK."
                return
            }
            statusMessage = "Health OK. Checking model list..."
            let models = try await hermesClient.fetchModels()
            availableModels = models.isEmpty
                ? [settingsStore.hermesModelID.trimmedOrNil ?? "hermes-agent"]
                : models.sortedCaseInsensitive()
            connectionState = .connected
            statusMessage = "Hermes OK at \(config.baseURL). Models: \(availableModels.joined(separator: ", "))."
        } catch {
            logger.error("Hermes diagnostics failed: \(error.localizedDescription, privacy: .public)")
            connectionState = .failed
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    public func sendDraft() async {
        let trimmed = draft.trimmed
        let attachmentsToSend = pendingAttachments
        guard !trimmed.isEmpty || !attachmentsToSend.isEmpty,
              let conversationID = selectedConversationID else { return }

        if trimmed.hasPrefix("/"), await handleSlashCommand(trimmed, conversationID: conversationID) {
            return
        }

        do {
            try endpointValidator.validate(
                hermesGatewayURL: settingsStore.hermesGatewayURL,
                companionURL: settingsStore.companionURL
            )
        } catch {
            errorMessage = error.localizedDescription
            connectionState = .failed
            return
        }

        draft = ""
        pendingAttachments = []
        errorMessage = nil
        statusMessage = nil

        let outcome = await streamCoordinator.send(
            request: ChatStreamRequest(
                conversationID: conversationID,
                text: trimmed,
                attachments: attachmentsToSend,
                conversation: selectedConversation ?? ChatConversation(id: conversationID, title: "Conversation"),
                currentMessages: messagesByConversationID[conversationID] ?? [],
                capabilities: capabilities(for: conversationID)
            ),
            callbacks: streamCallbacks(for: conversationID)
        )
        statusMessage = outcome.statusMessage
        errorMessage = outcome.errorMessage
        connectionState = outcome.connectionState
    }
}
