import AgentBoardCore
import SwiftUI

struct ChatScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var editingConversationID: UUID?
    @State private var editingTitle = ""

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        @Bindable var chatStore = appModel.chatStore

        ZStack {
            NeuBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, isCompact ? 16 : 24)
                    .padding(.top, isCompact ? 16 : 24)
                    .padding(.bottom, 16)

                if !chatStore.conversations.isEmpty {
                    conversationRail
                        .padding(.vertical, 8)
                }

                messageList

                composeArea
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("HERMES AI")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(NeuPalette.accentCyan)
                Text("Live Link")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(NeuPalette.textPrimary)
            }
            Spacer()
            Button {
                appModel.chatStore.startNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(NeuButtonTarget(isAccent: false))
        }
    }

    private var conversationRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(appModel.chatStore.conversations) { conversation in
                    conversationRailItem(conversation)
                }
            }
            .padding(.horizontal, isCompact ? 16 : 24)
        }
    }

    private func conversationRailItem(_ conversation: ChatConversation) -> some View {
        let isSelected = conversation.id == appModel.chatStore.selectedConversationID

        return Group {
            if editingConversationID == conversation.id {
                HStack(spacing: 6) {
                    TextField("Name", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .foregroundStyle(NeuPalette.textPrimary)
                        .frame(width: 120)
                        .onSubmit {
                            appModel.chatStore.renameConversation(id: conversation.id, title: editingTitle)
                            editingConversationID = nil
                        }

                    Button {
                        appModel.chatStore.renameConversation(id: conversation.id, title: editingTitle)
                        editingConversationID = nil
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(NeuPalette.accentCyan)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .neuRecessed(cornerRadius: 20, depth: 4)
            } else {
                Button {
                    appModel.chatStore.selectConversation(conversation.id)
                } label: {
                    Text(conversation.title)
                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? NeuPalette.accentCyan : NeuPalette.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .modifier(isSelected ? NeuExtrudedModifier(cornerRadius: 20, elevation: 6) :
                            NeuExtrudedModifier(
                                cornerRadius: 20,
                                elevation: 2
                            ))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        editingTitle = conversation.title
                        editingConversationID = conversation.id
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        appModel.chatStore.deleteConversation(id: conversation.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if appModel.chatStore.messages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundStyle(NeuPalette.accentCyan)
                        Text("Start a conversation")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(NeuPalette.textPrimary)
                        Text("Your messages stream live from the Hermes gateway and are saved locally.")
                            .font(.subheadline)
                            .foregroundStyle(NeuPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .neuExtruded(cornerRadius: 32, elevation: 12)
                    .padding(32)
                } else {
                    LazyVStack(spacing: 24) {
                        ForEach(appModel.chatStore.messages) { message in
                            NeuChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(isCompact ? 16 : 24)
                }
            }
            .onChange(of: appModel.chatStore.messages.count) {
                if let last = appModel.chatStore.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var composeArea: some View {
        @Bindable var chatStore = appModel.chatStore

        return VStack(spacing: 0) {
            if let err = chatStore.errorMessage {
                Text(err)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, isCompact ? 16 : 24)
                    .padding(.bottom, 8)
            } else if let status = chatStore.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(NeuPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, isCompact ? 16 : 24)
                    .padding(.bottom, 8)
            }

            HStack(alignment: .bottom, spacing: 16) {
                ZStack(alignment: .topLeading) {
                    if chatStore.draft.isEmpty {
                        Text("Message Hermes...")
                            .foregroundStyle(NeuPalette.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $chatStore.draft)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(NeuPalette.textPrimary)
                        .frame(minHeight: 48, maxHeight: 120)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .neuRecessed(cornerRadius: 16, depth: 6)

                Button {
                    Task { await chatStore.sendDraft() }
                } label: {
                    Image(systemName: chatStore.isStreaming ? "stop.fill" : "paperplane.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(NeuButtonTarget(isAccent: !chatStore.draft.isEmpty && !chatStore.isStreaming))
                .disabled(chatStore.draft.trimmedOrNil == nil && !chatStore.isStreaming)
            }
            .padding(isCompact ? 16 : 24)
            .background(NeuPalette.surface.ignoresSafeArea(edges: .bottom))
        }
    }
}

private struct NeuChatBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(message.role == .assistant ? "Hermes" : "You")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(message.role == .assistant ? NeuPalette.accentCyan : NeuPalette.accentOrange)
                    .tracking(1)

                if message.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(NeuPalette.accentCyan)
                }
            }

            if message.isStreaming, message.content.isEmpty {
                Text("typing...")
                    .foregroundStyle(NeuPalette.textSecondary)
            } else {
                MarkdownText(content: message.content)
                    .foregroundStyle(NeuPalette.textPrimary)
            }
        }
        .padding(16)
        .modifier(
            message.role == .assistant
                ? AnyViewModifier(NeuExtrudedModifier(cornerRadius: 20, elevation: 8))
                : AnyViewModifier(NeuRecessedModifier(cornerRadius: 20, depth: 6))
        )
    }
}

/// Helper to bridge ViewModifier types
struct AnyViewModifier: ViewModifier {
    let modifier: Any

    init<M: ViewModifier>(_ modifier: M) {
        self.modifier = modifier
    }

    func body(content: Content) -> some View {
        if let neuromod = modifier as? NeuExtrudedModifier {
            content.modifier(neuromod)
        } else if let neuromod = modifier as? NeuRecessedModifier {
            content.modifier(neuromod)
        } else {
            content
        }
    }
}
