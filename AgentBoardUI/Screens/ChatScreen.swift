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
            BoardBackground()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
                    header

                    if !chatStore.conversations.isEmpty {
                        conversationRail
                    }
                }
                .padding(.horizontal, isCompact ? 16 : 24)
                .padding(.top, isCompact ? 16 : 24)
                .padding(.bottom, 12)

                messageList
                    .padding(.horizontal, isCompact ? 16 : 24)

                composeArea
                    .padding(.horizontal, isCompact ? 16 : 24)
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle("Chat")
    }

    @ViewBuilder
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                headerTitle
                Spacer(minLength: 16)
                headerControls
            }
            VStack(alignment: .leading, spacing: 16) {
                headerTitle
                headerControls
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CHAT".uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(BoardPalette.gold)
            Text("Hermes AI")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
        }
    }

    private var headerControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    connectionChip
                    modelPickerMenu
                }
                VStack(alignment: .leading, spacing: 8) {
                    connectionChip
                    modelPickerMenu
                }
            }

            HStack(spacing: 8) {
                Button("Refresh") {
                    Task {
                        await appModel.chatStore.refreshConnection()
                        await appModel.chatStore.refreshModels()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button("New") {
                    appModel.chatStore.startNewConversation()
                }
                .buttonStyle(.borderedProminent)
                .tint(BoardPalette.cobalt)
            }
        }
    }

    private var connectionChip: some View {
        BoardChip(
            label: appModel.chatStore.connectionState.title,
            systemImage: "dot.radiowaves.left.and.right",
            tint: chipTint(for: appModel.chatStore.connectionState)
        )
        .layoutPriority(1)
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
            BoardChip(
                label: appModel.settingsStore.hermesModelID.trimmedOrNil ?? "model",
                systemImage: "cpu",
                tint: BoardPalette.gold
            )
            .frame(maxWidth: 180, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var conversationRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(appModel.chatStore.conversations) { conversation in
                    conversationRailItem(conversation)
                }
            }
        }
    }

    private func conversationRailItem(_ conversation: ChatConversation) -> some View {
        let isSelected = conversation.id == appModel.chatStore.selectedConversationID

        return Group {
            if editingConversationID == conversation.id {
                HStack(spacing: 6) {
                    TextField("Name", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .font(.headline)
                        .frame(width: 160)
                        .onSubmit {
                            appModel.chatStore.renameConversation(id: conversation.id, title: editingTitle)
                            editingConversationID = nil
                        }
                    Button {
                        appModel.chatStore.renameConversation(id: conversation.id, title: editingTitle)
                        editingConversationID = nil
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(BoardPalette.mint)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 220, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(BoardPalette.cobalt.opacity(0.32))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(BoardPalette.cobalt.opacity(0.5), lineWidth: 1)
                )
            } else {
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
                            .fill(isSelected ? BoardPalette.cobalt.opacity(0.32) : Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
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
        BoardSurface {
            if appModel.chatStore.messages.isEmpty {
                EmptyStateCard(
                    title: "Start a conversation",
                    message: "Your messages stream live from the Hermes gateway and are saved locally.",
                    systemImage: "sparkles"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(appModel.chatStore.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    }
                    .refreshable {
                        await appModel.chatStore.refreshConnection()
                    }
                    .onChange(of: appModel.chatStore.messages.count) {
                        if let last = appModel.chatStore.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var composeArea: some View {
        @Bindable var chatStore = appModel.chatStore

        return BoardSurface {
            VStack(alignment: .leading, spacing: 10) {
                if let err = chatStore.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(BoardPalette.coral)
                } else if let status = chatStore.statusMessage {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(BoardPalette.paper.opacity(0.75))
                }

                TextEditor(text: $chatStore.draft)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 160)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.22))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .foregroundStyle(.white)

                HStack {
                    Spacer()
                    Button(chatStore.isStreaming ? "Stop" : "Send") {
                        Task { await chatStore.sendDraft() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(chatStore.isStreaming ? BoardPalette.coral : BoardPalette.cobalt)
                    .disabled(chatStore.draft.trimmedOrNil == nil && !chatStore.isStreaming)
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
        HStack(alignment: .top) {
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

            if message.isStreaming && message.content.isEmpty {
                Text("Streaming response…")
                    .foregroundStyle(BoardPalette.paper.opacity(0.6))
            } else {
                MarkdownText(content: message.content)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    message.role == .assistant
                        ? Color.white.opacity(0.09)
                        : BoardPalette.coral.opacity(0.28)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: 680, alignment: .leading)
    }
}
