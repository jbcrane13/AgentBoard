// swiftlint:disable file_length
import Foundation
import Observation
import os

private enum ChatStoreError: LocalizedError {
    case hermesEndpointMatchesCompanion(String)
    case hermesLocalEndpointUsesHTTPS(String)

    var errorDescription: String? {
        switch self {
        case let .hermesEndpointMatchesCompanion(endpoint):
            return """
            Chat is pointed at the companion service at \(
                endpoint
            ). Companion handles tasks and sessions; set this profile's \
            Hermes Gateway URL to that profile's API server port.
            """
        case let .hermesLocalEndpointUsesHTTPS(endpoint):
            return """
            Hermes Gateway URL is using HTTPS at \(endpoint), but Hermes' API server is HTTP by default. Use \
            http://<host>:<profile-port>, or put a TLS proxy in front of Hermes.
            """
        }
    }
}

@MainActor
@Observable
// swiftlint:disable:next type_body_length
public final class ChatStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "ChatStore")
    private let hermesClient: HermesGatewayClient
    private let cache: AgentBoardCache
    private let settingsStore: SettingsStore
    private let uploadService = AttachmentUploadService()
    private let linkPreviewService = LinkPreviewService()
    public private(set) var conversations: [ChatConversation] = []
    public var selectedConversationID: UUID?
    public private(set) var availableModels: [String] = []
    public private(set) var connectionState: ChatConnectionState = .disconnected
    public private(set) var isStreaming = false
    public var draft = ""
    public var statusMessage: String?
    public var errorMessage: String?
    public var pendingAttachments: [ChatAttachment] = []

    public var canSendDraft: Bool {
        !isStreaming && (draft.trimmedOrNil != nil || !pendingAttachments.isEmpty)
    }

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
        guard conversations.contains(where: { $0.id == id }) else { return }
        selectedConversationID = id
    }

    public func renameConversation(id: UUID, title: String) {
        guard
            var conversation = conversations.first(where: { $0.id == id }),
            let trimmedTitle = title.trimmedOrNil
        else { return }
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

        do {
            try cache.deleteConversation(id: id)
        } catch {
            logger.error("Failed to delete conversation from cache: \(error.localizedDescription, privacy: .public)")
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

    // MARK: - Attachment Management

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

        // Intercept slash commands before sending to Hermes
        if trimmed.hasPrefix("/") {
            let handled = await handleSlashCommand(trimmed, conversationID: conversationID)
            if handled { return }
        }

        // Validate the Hermes endpoint before mutating any state. A misconfigured
        // gateway (HTTPS on a local host, pointed at the companion port, etc.)
        // must surface as an error without appending the user message.
        do {
            try validateHermesEndpoint()
        } catch {
            errorMessage = error.localizedDescription
            connectionState = .failed
            return
        }

        draft = ""
        pendingAttachments = []
        errorMessage = nil
        statusMessage = nil

        var conversation = selectedConversation ?? ChatConversation(id: conversationID, title: "Conversation")
        let currentMessages = messagesByConversationID[conversationID] ?? []

        var allAttachments = attachmentsToSend
        let linkPreviews = await linkPreviewService.buildPreviews(for: trimmed)
        allAttachments.append(contentsOf: linkPreviews)
        let uploadedAttachments = await uploadAttachments(allAttachments)

        let userMessage = ConversationMessage(
            conversationID: conversationID,
            role: .user,
            content: trimmed,
            attachments: uploadedAttachments
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

    private func normalizedHermesGatewayURL() -> URL {
        let baseURL = settingsStore.hermesGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackURL = URL(string: "http://127.0.0.1:8642")!
        guard let url = URL(string: baseURL) else {
            return fallbackURL
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var pathComponents = url.pathComponents.filter { $0 != "/" }
        if pathComponents.last == "v1" {
            pathComponents.removeLast()
        }
        components?.path = pathComponents.isEmpty ? "" : "/" + pathComponents.joined(separator: "/")
        return components?.url ?? url
    }

    private func uploadEndpointURL() -> URL {
        normalizedHermesGatewayURL().appendingPathComponent("v1/upload")
    }

    private func uploadAttachments(_ attachments: [ChatAttachment]) async -> [ChatAttachment] {
        var results: [ChatAttachment] = []
        for var attachment in attachments {
            if attachment.payload.localURL != nil, attachment.state == .pendingUpload {
                statusMessage = "Uploading \(attachment.type.rawValue)..."
                do {
                    let remoteURL = try await uploadService.upload(
                        attachment: attachment,
                        to: uploadEndpointURL(),
                        apiKey: settingsStore.hermesAPIKey.trimmedOrNil
                    ) { [weak self] progress in
                        Task { @MainActor in
                            self?.statusMessage = "Uploading... \(Int(progress * 100))%"
                        }
                    }
                    attachment.state = .uploaded(remoteURL: remoteURL)
                } catch {
                    logger.error("Attachment upload failed: \(error.localizedDescription, privacy: .public)")
                    attachment.state = .uploadingFailed(error: error.localizedDescription)
                }
            }
            results.append(attachment)
        }
        statusMessage = nil
        return results
    }

    private func configureClient() async throws {
        try validateHermesEndpoint()

        try await hermesClient.configure(
            baseURL: settingsStore.hermesGatewayURL,
            apiKey: settingsStore.hermesAPIKey.trimmedOrNil,
            preferredModelID: settingsStore.hermesModelID.trimmedOrNil
        )
    }

    private func validateHermesEndpoint() throws {
        try validateHermesScheme()

        guard let hermesEndpoint = Self.normalizedEndpoint(settingsStore.hermesGatewayURL),
              let companionEndpoint = Self.normalizedEndpoint(settingsStore.companionURL),
              hermesEndpoint == companionEndpoint else {
            return
        }

        throw ChatStoreError.hermesEndpointMatchesCompanion(settingsStore.hermesGatewayURL)
    }

    private func validateHermesScheme() throws {
        guard let url = URL(string: settingsStore.hermesGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              Self.isLocalOrPrivateHost(host) else {
            return
        }

        throw ChatStoreError.hermesLocalEndpointUsesHTTPS(settingsStore.hermesGatewayURL)
    }

    private static func normalizedEndpoint(_ rawValue: String) -> String? {
        guard let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased()
        else { return nil }

        let defaultPort = scheme == "https" ? 443 : 80
        let port = url.port ?? defaultPort
        return "\(scheme)://\(host):\(port)"
    }

    private static func isLocalOrPrivateHost(_ host: String) -> Bool {
        let normalizedHost = host.lowercased()
        if ["localhost", "::1"].contains(normalizedHost) || normalizedHost.hasPrefix("127.") {
            return true
        }

        let octets = normalizedHost.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else { return false }

        if octets[0] == 10 || octets[0] == 127 || octets[0] == 192 && octets[1] == 168 {
            return true
        }

        if octets[0] == 172, (16 ... 31).contains(octets[1]) {
            return true
        }

        // Tailscale and other CGNAT-style private overlays live in 100.64.0.0/10.
        return octets[0] == 100 && (64 ... 127).contains(octets[1])
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

    private func clearDraft() {
        draft = ""
        pendingAttachments = []
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func handleSlashCommand(_ text: String, conversationID: UUID) async -> Bool {
        let result = SlashCommandHandler.handle(text)
        switch result {
        case .newConversation:
            clearDraft()
            startNewConversation()
            return true
        case .clearConversation:
            clearDraft()
            deleteConversation(id: conversationID)
            startNewConversation()
            return true
        case let .switchModel(modelID):
            clearDraft()
            selectModel(modelID)
            statusMessage = "Switched to model: \(modelID)"
            return true
        case .showHelp:
            clearDraft()
            appendSystemMessage(SlashCommandHandler.formatHelp(), to: conversationID)
            return true
        case .showStatus:
            clearDraft()
            let stateStr = switch connectionState {
            case .connected: "Connected"
            case .connecting: "Connecting"
            case .disconnected: "Disconnected"
            case .reconnecting: "Reconnecting"
            case .failed: "Failed"
            }
            let status = SlashCommandHandler.formatStatus(
                connectionState: stateStr,
                model: settingsStore.hermesModelID,
                conversationTitle: selectedConversation?.title ?? "None",
                messageCount: messages.count
            )
            appendSystemMessage(status, to: conversationID)
            return true
        case .showConfig:
            clearDraft()
            let config = SlashCommandHandler.formatConfig(
                gatewayURL: settingsStore.hermesGatewayURL,
                model: settingsStore.hermesModelID,
                hasAPIKey: settingsStore.hermesAPIKey.trimmedOrNil != nil,
                repos: settingsStore.repositories.map(\.fullName)
            )
            appendSystemMessage(config, to: conversationID)
            return true
        case .showSkills:
            clearDraft()
            appendSystemMessage(SlashCommandHandler.formatSkills([]), to: conversationID)
            return true
        case let .activateSkill(name):
            clearDraft()
            appendSystemMessage("Activating skill: \(name)…", to: conversationID)
            statusMessage = "Skill '\(name)' activated"
            return true
        case .showMemory, .showTools, .toggleThinking, .toggleWeb,
             .toggleCode, .toggleImage, .toggleSpeak:
            return handleToggleCommand(result, conversationID: conversationID)
        case .resetConversation:
            clearDraft()
            startNewConversation()
            statusMessage = "Conversation reset"
            return true
        case let .handled(response):
            clearDraft()
            appendSystemMessage(response, to: conversationID)
            return true
        case let .unknown(command):
            statusMessage = "Sending /\(command) to agent..."
            return false
        case .passthrough:
            return false
        }
    }

    private func handleToggleCommand(
        _ result: SlashCommandResult,
        conversationID: UUID
    ) -> Bool {
        clearDraft()
        let message = switch result {
        case .showMemory: "Memory lookup sent to Hermes. Response will appear below."
        case .showTools: "Tool listing sent to Hermes. Response will appear below."
        case .toggleThinking: "Toggled thinking mode. Sent to agent."
        case .toggleWeb: "Toggled web access. Sent to agent."
        case .toggleCode: "Toggled code execution. Sent to agent."
        case .toggleImage: "Toggled image generation. Sent to agent."
        case .toggleSpeak: "Toggled voice output. Sent to agent."
        default: "Command sent to agent."
        }
        appendSystemMessage(message, to: conversationID)
        return false
    }

    private func appendSystemMessage(_ content: String, to conversationID: UUID) {
        let message = ConversationMessage(
            conversationID: conversationID,
            role: .assistant,
            content: content
        )
        var current = messagesByConversationID[conversationID] ?? []
        current.append(message)
        messagesByConversationID[conversationID] = current
        persist(conversationID: conversationID)
    }

    private func removeMessage(id: UUID, conversationID: UUID) {
        guard var messages = messagesByConversationID[conversationID] else { return }
        messages.removeAll { $0.id == id }
        messagesByConversationID[conversationID] = messages
    }
}
