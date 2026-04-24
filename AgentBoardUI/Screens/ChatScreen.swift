import AgentBoardCore
import SwiftUI

struct ChatScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    var body: some View {
        @Bindable var chatStore = appModel.chatStore

        ZStack {
            BoardBackground()

            VStack(alignment: .leading, spacing: 18) {
                header

                if !chatStore.conversations.isEmpty {
                    conversationRail
                }

                BoardSurface {
                    if chatStore.messages.isEmpty {
                        EmptyStateCard(
                            title: "Start the Hermes conversation",
                            message:
                            "The new chat surface is shared across macOS and iOS, streams assistant output in place, and keeps local history in SwiftData.",
                            systemImage: "sparkles"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(chatStore.messages) { message in
                                    ChatBubble(message: message)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BoardSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prompt")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextEditor(text: $chatStore.draft)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.black.opacity(0.22))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .foregroundStyle(.white)

                        HStack {
                            Text(chatStore.errorMessage ?? chatStore
                                .statusMessage ?? "Hermes-first streaming is ready.")
                                .font(.footnote)
                                .foregroundStyle(chatStore.errorMessage == nil ? BoardPalette.paper
                                    .opacity(0.75) : BoardPalette.coral)

                            Spacer()

                            Button("Send") {
                                Task {
                                    await chatStore.sendDraft()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BoardPalette.coral)
                            .disabled(chatStore.draft.trimmedOrNil == nil || chatStore.isStreaming)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            BoardHeader(
                eyebrow: "Hermes Chat",
                title: "A fresh client for gateway-native conversations",
                subtitle: "Streaming, reconnect state, and conversation history all live in the new shared core instead of the legacy AppState."
            )

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 8) {
                    BoardChip(
                        label: appModel.chatStore.connectionState.title,
                        systemImage: "dot.radiowaves.left.and.right",
                        tint: chipTint(for: appModel.chatStore.connectionState)
                    )
                    BoardChip(
                        label: appModel.settingsStore.hermesModelID.trimmedOrNil ?? "hermes-agent",
                        systemImage: "cpu",
                        tint: BoardPalette.gold
                    )
                }

                HStack(spacing: 10) {
                    Button("Refresh") {
                        Task {
                            await appModel.chatStore.refreshConnection()
                            await appModel.chatStore.refreshModels()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button("New Conversation") {
                        appModel.chatStore.startNewConversation()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BoardPalette.cobalt)
                }
            }
        }
    }

    private var conversationRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(appModel.chatStore.conversations) { conversation in
                    Button {
                        appModel.chatStore.selectConversation(conversation.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(.headline)
                                .lineLimit(1)
                                .foregroundStyle(.white)

                            Text(conversation.updatedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(BoardPalette.paper.opacity(0.7))
                        }
                        .frame(width: 220, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    conversation.id == appModel.chatStore.selectedConversationID
                                        ? BoardPalette.cobalt.opacity(0.32)
                                        : Color.white.opacity(0.08)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chipTint(for state: ChatConnectionState) -> Color {
        switch state {
        case .connected: BoardPalette.mint
        case .connecting, .reconnecting: BoardPalette.gold
        case .failed: BoardPalette.coral
        case .disconnected: BoardPalette.cobalt
        }
    }
}

private struct ChatBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 48)
            } else {
                Spacer(minLength: 48)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(message.role == .assistant ? "Hermes" : "You")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))

                if message.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .tint(BoardPalette.gold)
                }
            }

            Text(message.content.isEmpty && message.isStreaming ? "Streaming response..." : message.content)
                .textSelection(.enabled)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(message.role == .assistant ? Color.white.opacity(0.09) : BoardPalette.coral.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: 720, alignment: .leading)
    }
}
