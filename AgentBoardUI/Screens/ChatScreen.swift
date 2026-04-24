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

        VStack(spacing: 0) {
            if !chatStore.conversations.isEmpty {
                conversationRail
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))
                Divider()
            }

            messageList
                .background(Color(.systemBackground))

            Divider()
            composeArea
                .background(Color(.secondarySystemBackground))
        }
        .navigationTitle("Hermes AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                connectionChip
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.chatStore.startNewConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                modelPickerMenu
            }
        }
    }

    private var connectionChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(chipTint(for: appModel.chatStore.connectionState))
                .frame(width: 8, height: 8)
            Text(appModel.chatStore.connectionState.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modelPickerMenu: some View {
        Menu {
            ForEach(appModel.chatStore.availableModels, id: \.self) { model in
                Button {
                    appModel.settingsStore.hermesModelID = model
                    Task { await appModel.chatStore.refreshModels() }
                } label: {
                    HStack {
                        Text(model)
                        if model == appModel.settingsStore.hermesModelID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(appModel.settingsStore.hermesModelID.trimmedOrNil ?? "model")
                    .font(.caption)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
        }
    }

    private var conversationRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appModel.chatStore.conversations) { conversation in
                    conversationRailItem(conversation)
                }
            }
            .padding(.horizontal, 16)
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
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemFill))
                .clipShape(Capsule())
            } else {
                Button {
                    appModel.chatStore.selectConversation(conversation.id)
                } label: {
                    Text(conversation.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                        .clipShape(Capsule())
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
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("Start a conversation")
                            .font(.headline)
                        Text("Your messages stream live from the Hermes gateway and are saved locally.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(appModel.chatStore.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
            }
            .onChange(of: appModel.chatStore.messages.count) {
                if let last = appModel.chatStore.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .refreshable {
            await appModel.chatStore.refreshConnection()
        }
    }

    private var composeArea: some View {
        @Bindable var chatStore = appModel.chatStore

        return VStack(spacing: 8) {
            if let err = chatStore.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let status = chatStore.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message Hermes...", text: $chatStore.draft, axis: .vertical)
                    .lineLimit(1 ... 8)
                    .padding(10)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                Button {
                    Task { await chatStore.sendDraft() }
                } label: {
                    Image(systemName: chatStore.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(chatStore.isStreaming ? Color
                            .red : (chatStore.draft.isEmpty ? Color(.tertiaryLabel) : Color.blue))
                }
                .disabled(chatStore.draft.trimmedOrNil == nil && !chatStore.isStreaming)
            }
        }
        .padding(12)
        .padding(.bottom, 8)
    }

    private func chipTint(for state: ChatConnectionState) -> Color {
        switch state {
        case .connected: Color.green
        case .connecting, .reconnecting: Color.orange
        case .failed: Color.red
        case .disconnected: Color.gray
        }
    }
}

private struct ChatBubble: View {
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(message.role == .assistant ? "Hermes" : "You")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                if message.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if message.isStreaming, message.content.isEmpty {
                Text("...")
                    .foregroundStyle(.secondary)
            } else {
                MarkdownText(content: message.content)
                    .foregroundStyle(message.role == .assistant ? Color.primary : Color.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(message.role == .assistant ? Color(.secondarySystemBackground) : Color.blue)
        )
    }
}
