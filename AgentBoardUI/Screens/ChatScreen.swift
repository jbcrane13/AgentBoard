import AgentBoardCore
import SwiftUI

struct ChatScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @FocusState private var isTextFieldFocused: Bool
    @State private var editingConversationID: UUID?
    @State private var editingTitle = ""

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        @Bindable var chatStore = appModel.chatStore

        ZStack(alignment: .top) {
            NeuBackground()

            VStack(spacing: 0) {
                // Main Header pinned at the top
                header
                    .padding(.horizontal, isCompact ? 16 : 24)
                    .padding(.top, isCompact ? 16 : 24)
                    .padding(.bottom, 16)
                    .background(NeuPalette.background.ignoresSafeArea())

                if !chatStore.conversations.isEmpty {
                    conversationRail
                        .padding(.bottom, 4)
                        .background(NeuPalette.background)
                }

                // The shrinking center body
                messageList

                // The pinned base
                composeArea
            }
        }
        .agentBoardNavigationBarHidden(true)
        .agentBoardKeyboardDismissToolbar()
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
            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(appModel.chatStore.conversations) { conversation in
                            Button {
                                appModel.chatStore.selectConversation(conversation.id)
                            } label: {
                                Label(
                                    conversation.title,
                                    systemImage: conversation.id == appModel.chatStore.selectedConversationID
                                        ? "checkmark.circle.fill" : "bubble.left"
                                )
                            }
                        }

                        Divider()

                        Button {
                            appModel.chatStore.startNewConversation()
                        } label: {
                            Label("New Session", systemImage: "square.and.pencil")
                        }
                    } label: {
                        headerCapsule(
                            title: "Session",
                            value: appModel.chatStore.selectedConversation?.title ?? "New Conversation",
                            systemImage: "bubble.left.and.bubble.right.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    Menu {
                        ForEach(appModel.settingsStore.availableHermesProfiles) { profile in
                            Button {
                                Task {
                                    if profile.id != "current" {
                                        appModel.settingsStore.selectHermesProfile(id: profile.id)
                                    }
                                    await appModel.chatStore.refreshConnection()
                                    await appModel.chatStore.refreshModels()
                                }
                            } label: {
                                Label(
                                    profile.name,
                                    systemImage: appModel.settingsStore.selectedHermesProfileID == profile.id
                                        ? "checkmark.circle.fill" : "network"
                                )
                            }
                        }
                    } label: {
                        headerCapsule(
                            title: "Profile",
                            value: appModel.settingsStore.activeHermesProfile?.name ?? portLabel,
                            systemImage: "server.rack"
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Menu {
                        ForEach(appModel.chatStore.availableModels, id: \.self) { model in
                            Button {
                                appModel.chatStore.selectModel(model)
                            } label: {
                                Label(
                                    model,
                                    systemImage: model == appModel.settingsStore.hermesModelID
                                        ? "checkmark.circle.fill" : "person.crop.rectangle.stack"
                                )
                            }
                        }
                    } label: {
                        headerCapsule(
                            title: "Model",
                            value: appModel.settingsStore.hermesModelID,
                            systemImage: "cpu.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    statusCapsule

                    Button {
                        Task {
                            await appModel.chatStore.refreshConnection()
                            await appModel.chatStore.refreshModels()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(NeuButtonTarget(isAccent: false))
                }
            }
        }
    }

    private var statusCapsule: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectionTint)
                .frame(width: 10, height: 10)
            Text(appModel.chatStore.connectionState.title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(NeuPalette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .neuRecessed(cornerRadius: 18, depth: 4)
    }

    private func headerCapsule(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(NeuPalette.accentCyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(NeuPalette.textSecondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(NeuPalette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 220, alignment: .leading)
        .neuExtruded(cornerRadius: 18, elevation: 4)
    }

    private var connectionTint: Color {
        switch appModel.chatStore.connectionState {
        case .connected:
            NeuPalette.accentCyan
        case .connecting, .reconnecting:
            NeuPalette.accentOrange
        case .failed:
            .red
        case .disconnected:
            NeuPalette.textSecondary
        }
    }

    private var portLabel: String {
        if let url = URL(string: appModel.settingsStore.hermesGatewayURL),
           let port = url.port {
            return "Port \(port)"
        }
        return "Current"
    }

    private var conversationRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(appModel.chatStore.conversations) { conversation in
                    conversationRailItem(conversation)
                }
            }
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.vertical, 12)
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
            .onTapGesture {
                isTextFieldFocused = false
                AgentBoardKeyboard.dismiss()
            }
            .agentBoardScrollDismissesKeyboard()
        }
    }

    private var composeArea: some View {
        @Bindable var chatStore = appModel.chatStore

        return VStack(spacing: 0) {
            if let err = chatStore.errorMessage {
                Text(err)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            } else if let status = chatStore.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(NeuPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }

            ZStack(alignment: .bottomTrailing) {
                // Centering the text inside the bounds natively
                TextField("", text: $chatStore.draft, axis: .vertical)
                    .lineLimit(1 ... 6)
                    .focused($isTextFieldFocused)
                    .foregroundStyle(NeuPalette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 64) // Large margins side-to-side ensures clear bounding away from Send button
                    .padding(.vertical, 24)
                    .overlay(
                        Text("Message Hermes...")
                            .foregroundStyle(NeuPalette.textSecondary)
                            .opacity(chatStore.draft.isEmpty ? 1 : 0)
                            .allowsHitTesting(false)
                    )

                Button {
                    isTextFieldFocused = false
                    AgentBoardKeyboard.dismiss()
                    Task { await chatStore.sendDraft() }
                } label: {
                    Image(systemName: chatStore.isStreaming ? "stop.fill" : "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(chatStore
                            .isStreaming ? .white :
                            (chatStore.draft.isEmpty ? NeuPalette.textSecondary : NeuPalette.background))
                        .frame(width: 48, height: 48) // More robust tap target
                        .background(
                            Circle()
                                .fill(chatStore
                                    .isStreaming ? .red :
                                    (chatStore.draft.isEmpty ? NeuPalette.surface : NeuPalette.accentCyan))
                        )
                }
                .disabled(chatStore.draft.trimmedOrNil == nil && !chatStore.isStreaming)
                .padding(12) // Exactly inset into the bottom corner
            }
            .neuRecessed(cornerRadius: 36, depth: 6)
        }
        .padding(.horizontal, isCompact ? 16 : 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            NeuPalette.background
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: NeuPalette.shadowDark, radius: 10, y: -4)
        )
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

            // Render attachments
            if !message.attachments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(message.attachments) { attachment in
                        AttachmentContainerView(attachment: attachment)
                    }
                }
            }
        }
        .padding(20)
        .modifier(
            message.role == .assistant
                ? AnyViewModifier(NeuExtrudedModifier(cornerRadius: 24, elevation: 8))
                : AnyViewModifier(NeuRecessedModifier(cornerRadius: 24, depth: 6))
        )
    }
}

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
