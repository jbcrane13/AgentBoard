import Foundation
import os

struct ChatStreamRequest: Sendable {
    let conversationID: UUID
    let text: String
    let attachments: [ChatAttachment]
    let conversation: ChatConversation
    let currentMessages: [ConversationMessage]
    let capabilities: Set<ChatCapability>
}

struct ChatStreamCallbacks: Sendable {
    let setStatusMessage: @MainActor @Sendable (String?) -> Void
    let setConnectionState: @MainActor @Sendable (ChatConnectionState) -> Void
    let setIsStreaming: @MainActor @Sendable (Bool) -> Void
    let replaceMessages: @MainActor @Sendable ([ConversationMessage]) -> Void
    let upsertConversation: @MainActor @Sendable (ChatConversation) -> Void
    let persist: @MainActor @Sendable () async -> Void
}

struct ChatStreamOutcome: Sendable {
    let statusMessage: String?
    let errorMessage: String?
    let connectionState: ChatConnectionState
}

@MainActor
final class ChatStreamCoordinator {
    private let hermesClient: HermesGatewayClient
    private let settingsStore: SettingsStore
    private let uploadService: AttachmentUploadService
    private let linkPreviewService: LinkPreviewService
    private let endpointValidator: ChatEndpointValidator
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "ChatStream")

    init(
        hermesClient: HermesGatewayClient,
        settingsStore: SettingsStore,
        uploadService: AttachmentUploadService,
        linkPreviewService: LinkPreviewService,
        endpointValidator: ChatEndpointValidator
    ) {
        self.hermesClient = hermesClient
        self.settingsStore = settingsStore
        self.uploadService = uploadService
        self.linkPreviewService = linkPreviewService
        self.endpointValidator = endpointValidator
    }

    func send(
        request: ChatStreamRequest,
        callbacks: ChatStreamCallbacks
    ) async -> ChatStreamOutcome {
        var conversation = request.conversation
        var allAttachments = request.attachments
        let linkPreviews = await linkPreviewService.buildPreviews(for: request.text)
        allAttachments.append(contentsOf: linkPreviews)
        let uploadedAttachments = await uploadAttachments(allAttachments, callbacks: callbacks)

        let userMessage = ConversationMessage(
            conversationID: request.conversationID,
            role: .user,
            content: request.text,
            attachments: uploadedAttachments
        )
        var assistantMessage = ConversationMessage(
            conversationID: request.conversationID,
            role: .assistant,
            content: "",
            isStreaming: true
        )

        let displayMessages = request.currentMessages + [userMessage]
        callbacks.replaceMessages(displayMessages + [assistantMessage])

        if conversation.title == "New Conversation" {
            conversation.title = String(request.text.prefix(48))
        }
        conversation.updatedAt = .now
        callbacks.upsertConversation(conversation)
        await callbacks.persist()

        callbacks.setIsStreaming(true)
        callbacks.setConnectionState(.connecting)

        do {
            try await configureClient()
            let outboundMessages = Self.buildOutboundMessages(
                displayMessages: displayMessages,
                capabilities: request.capabilities,
                conversationID: request.conversationID
            )
            let stream = try await hermesClient.streamReply(for: outboundMessages)
            callbacks.setConnectionState(.connected)

            for try await event in stream {
                switch event {
                case let .text(chunk):
                    assistantMessage.content += chunk
                case let .toolProgress(progress):
                    Self.apply(progress, to: &assistantMessage.toolActivities)
                }
                callbacks.replaceMessages(displayMessages + [assistantMessage])
            }

            assistantMessage.isStreaming = false
            callbacks.replaceMessages(displayMessages + [assistantMessage])
            callbacks.setIsStreaming(false)

            conversation.updatedAt = .now
            conversation.modelID = settingsStore.hermesModelID.trimmedOrNil
            callbacks.upsertConversation(conversation)
            await callbacks.persist()

            return ChatStreamOutcome(
                statusMessage: "Reply streamed from Hermes.",
                errorMessage: nil,
                connectionState: .connected
            )
        } catch {
            logger.error("Streaming reply failed: \(error.localizedDescription, privacy: .public)")
            callbacks.setConnectionState(.failed)
            callbacks.setIsStreaming(false)

            if assistantMessage.content.isEmpty {
                callbacks.replaceMessages(displayMessages)
            } else {
                assistantMessage.isStreaming = false
                callbacks.replaceMessages(displayMessages + [assistantMessage])
            }
            await callbacks.persist()

            return ChatStreamOutcome(
                statusMessage: nil,
                errorMessage: error.localizedDescription,
                connectionState: .failed
            )
        }
    }

    /// Builds the message list actually sent to Hermes. When capabilities are active, a
    /// synthetic system message carrying their prompt instructions is prepended — but only
    /// for this outbound call. It must never be persisted or displayed, so callers must use
    /// `displayMessages` (not this function's result) for `replaceMessages`/persistence.
    nonisolated static func buildOutboundMessages(
        displayMessages: [ConversationMessage],
        capabilities: Set<ChatCapability>,
        conversationID: UUID
    ) -> [ConversationMessage] {
        guard !capabilities.isEmpty else { return displayMessages }

        let instructions = capabilities
            .map(\.promptInstruction)
            .sorted()
            .joined(separator: " ")
        let syntheticSystemMessage = ConversationMessage(
            conversationID: conversationID,
            role: .system,
            content: "Capability overrides (client-side): " + instructions
        )
        return [syntheticSystemMessage] + displayMessages
    }

    nonisolated static func apply(_ progress: HermesToolProgress, to activities: inout [ToolActivity]) {
        let isComplete = progress.status == "completed"
        if let index = activities.firstIndex(where: { $0.id == progress.toolCallId }) {
            if let emoji = progress.emoji { activities[index].emoji = emoji }
            if let label = progress.label { activities[index].label = label }
            activities[index].isComplete = isComplete
        } else {
            activities.append(ToolActivity(
                id: progress.toolCallId,
                tool: progress.tool,
                emoji: progress.emoji,
                label: progress.label,
                isComplete: isComplete
            ))
        }
    }

    private func uploadAttachments(
        _ attachments: [ChatAttachment],
        callbacks: ChatStreamCallbacks
    ) async -> [ChatAttachment] {
        var results: [ChatAttachment] = []
        for var attachment in attachments {
            if attachment.payload.localURL != nil, attachment.state == .pendingUpload {
                callbacks.setStatusMessage("Uploading \(attachment.type.rawValue)...")
                do {
                    let remoteURL = try await uploadService.upload(
                        attachment: attachment,
                        to: endpointValidator.uploadEndpointURL(hermesGatewayURL: settingsStore.hermesGatewayURL),
                        apiKey: settingsStore.hermesAPIKey.trimmedOrNil
                    ) { progress in
                        Task { @MainActor in
                            callbacks.setStatusMessage("Uploading... \(Int(progress * 100))%")
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
        callbacks.setStatusMessage(nil)
        return results
    }

    private func configureClient() async throws {
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
}
