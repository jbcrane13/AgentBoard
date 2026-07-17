import Foundation
import os

struct ChatStreamRequest: Sendable {
    let conversationID: UUID
    let text: String
    let attachments: [ChatAttachment]
    let conversation: ChatConversation
    let currentMessages: [ConversationMessage]
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

        let requestMessages = request.currentMessages + [userMessage]
        callbacks.replaceMessages(requestMessages + [assistantMessage])

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
            let stream = try await hermesClient.streamReply(for: requestMessages)
            callbacks.setConnectionState(.connected)

            for try await event in stream {
                if case let .text(chunk) = event {
                    assistantMessage.content += chunk
                    callbacks.replaceMessages(requestMessages + [assistantMessage])
                }
            }

            assistantMessage.isStreaming = false
            callbacks.replaceMessages(requestMessages + [assistantMessage])
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
                callbacks.replaceMessages(requestMessages)
            } else {
                assistantMessage.isStreaming = false
                callbacks.replaceMessages(requestMessages + [assistantMessage])
            }
            await callbacks.persist()

            return ChatStreamOutcome(
                statusMessage: nil,
                errorMessage: error.localizedDescription,
                connectionState: .failed
            )
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
