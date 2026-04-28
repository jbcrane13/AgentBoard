import AgentBoardCore
import SwiftUI

// swiftlint:disable:next type_body_length
struct ChatScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @FocusState private var isTextFieldFocused: Bool
    @State private var editingConversationID: UUID?
    @State private var editingTitle = ""
    @State private var showAttachmentPicker = false
    @StateObject private var audioRecorder = AudioRecorderService()

    /// When set, ChatScreen renders a "chat-only" toggle in its header.
    /// The hosting view manages the actual hide/show and window-resize logic.
    var onToggleChatOnly: (() -> Void)?
    var isChatOnlyMode: Bool = false

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
                    .padding(.horizontal, isCompact ? 16 : 16)
                    .padding(.top, isCompact ? 16 : 14)
                    .padding(.bottom, 12)
                    .background(NeuPalette.surface.ignoresSafeArea())
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(NeuPalette.borderSoft)
                            .frame(height: 1)
                    }

                // The shrinking center body
                messageList

                // The pinned base
                composeArea
            }
        }
        .agentBoardNavigationBarHidden(true)
        .agentBoardKeyboardDismissToolbar()
        #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await appModel.chatStore.autoReconnectIfNeeded() }
            }
        #endif
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            if let onToggleChatOnly, !isCompact {
                Button {
                    onToggleChatOnly()
                } label: {
                    Image(systemName: isChatOnlyMode ? "rectangle.split.3x1" : "rectangle.righthalf.inset.filled")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(NeuButtonTarget(isAccent: isChatOnlyMode))
                .accessibilityLabel(isChatOnlyMode
                    ? "Restore the sidebar and board"
                    : "Hide the sidebar and board, shrink the window to chat-only")
                .accessibilityIdentifier("chat_button_toggle_chat_only")
            }

            VStack(alignment: .leading, spacing: 4) {
                AgentBoardEyebrow(text: "HERMES AI")
                Text("Live Link")
                    .font(.system(size: isCompact ? 28 : 18, weight: .bold))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .tracking(-0.4)
            }

            Spacer()

            HStack(spacing: 8) {
                if isCompact {
                    sessionMenu
                    profileMenu
                } else {
                    desktopSessionMenu
                    desktopProfileMenu
                }

                // Status dot + refresh
                Circle()
                    .fill(connectionTint)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Connection status")
                    .accessibilityValue(appModel.chatStore.connectionState.title)

                Button {
                    Task {
                        await appModel.chatStore.refreshConnection()
                        await appModel.chatStore.refreshModels()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .accessibilityLabel("Refresh Hermes connection and models")
                .accessibilityHint("Reconnects to Hermes and reloads the available models.")
                .buttonStyle(NeuButtonTarget(isAccent: false))
            }
        }
    }

    @ViewBuilder
    private var sessionMenuItems: some View {
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
            .accessibilityIdentifier("chat_menuitem_session_\(conversation.id.uuidString)")
        }
        if !appModel.chatStore.conversations.isEmpty {
            Divider()
        }
        Button {
            appModel.chatStore.startNewConversation()
        } label: {
            Label("New Session", systemImage: "square.and.pencil")
        }
        .accessibilityIdentifier("chat_menuitem_session_new")
    }

    private var profileMenuItems: some View {
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
            .accessibilityIdentifier("chat_menuitem_profile_\(profile.id)")
        }
    }

    private var sessionMenu: some View {
        Menu {
            sessionMenuItems
        } label: {
            compactMenuButton(
                icon: "bubble.left.and.bubble.right.fill",
                text: appModel.chatStore.selectedConversation?.title ?? "Session"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_menu_session")
    }

    private var profileMenu: some View {
        Menu {
            profileMenuItems
        } label: {
            compactMenuButton(
                icon: "server.rack",
                text: appModel.settingsStore.activeHermesProfile?.name ?? portLabel
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_menu_profile")
    }

    private var desktopSessionMenu: some View {
        Menu {
            sessionMenuItems
        } label: {
            Text(appModel.chatStore.selectedConversation?.title.prefix(10) ?? "session")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(NeuPalette.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(NeuPalette.inset)
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Switch session")
        .accessibilityIdentifier("chat_menu_session_desktop")
    }

    private var desktopProfileMenu: some View {
        Menu {
            profileMenuItems
        } label: {
            Text(appModel.settingsStore.activeHermesProfile?.name ?? portLabel)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(NeuPalette.accentCyanBright)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(NeuPalette.accentCyan.opacity(0.08))
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Switch Hermes profile")
        .accessibilityIdentifier("chat_menu_profile_desktop")
    }

    private func compactMenuButton(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(NeuPalette.accentCyan)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(NeuPalette.textPrimary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(NeuPalette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .neuExtruded(cornerRadius: 12, elevation: 2)
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

    private var canSend: Bool {
        let chatStore = appModel.chatStore
        return chatStore.isStreaming
            || chatStore.draft.trimmedOrNil != nil
            || !chatStore.pendingAttachments.isEmpty
    }

    private var sendButtonForeground: Color {
        let chatStore = appModel.chatStore
        if chatStore.isStreaming { return .white }
        return canSend ? NeuPalette.accentForeground : NeuPalette.textSecondary
    }

    private var sendButtonBackground: Color {
        let chatStore = appModel.chatStore
        if chatStore.isStreaming { return .red }
        return canSend ? NeuPalette.accentCyan : NeuPalette.surface
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

            if !chatStore.pendingAttachments.isEmpty {
                AttachmentPreviewStrip(attachments: $chatStore.pendingAttachments)
            }

            // Slash command autocomplete overlay
            slashCommandSuggestions

            VStack(spacing: 8) {
                // Secondary toolbar: attach + mic ABOVE the text field
                HStack(spacing: 4) {
                    Button { showAttachmentPicker = true } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(NeuPalette.accentCyan)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat_button_attach")
                    .sheet(isPresented: $showAttachmentPicker) {
                        AttachmentPickerSheet { attachment in
                            chatStore.addAttachment(attachment)
                        }
                    }

                    VoiceRecordingButton(
                        recorder: audioRecorder,
                        onRecorded: { result in chatStore.addAttachment(result.toAttachment()) },
                        onCancel: {}
                    )

                    Spacer()
                }
                .padding(.horizontal, 4)

                // Primary row: text field + send
                HStack(spacing: 12) {
                    TextField(" Message Hermes...", text: $chatStore.draft, axis: .vertical)
                        .lineLimit(1 ... 6)
                        .focused($isTextFieldFocused)
                        .foregroundStyle(NeuPalette.textPrimary)
                        .textFieldStyle(.plain)
                        .onKeyPress(.return, phases: .down) { press in
                            if press.modifiers.contains(.shift) { return .ignored }
                            guard chatStore.canSendDraft else { return .ignored }
                            isTextFieldFocused = false
                            AgentBoardKeyboard.dismiss()
                            Task { await chatStore.sendDraftWithRetry() }
                            return .handled
                        }

                    Button {
                        isTextFieldFocused = false
                        AgentBoardKeyboard.dismiss()
                        Task { await chatStore.sendDraftWithRetry() }
                    } label: {
                        Image(systemName: chatStore.isStreaming ? "stop.fill" : "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(sendButtonForeground)
                            .frame(width: 32, height: 32)
                            .background(NeuPalette.surfaceRaised.clipShape(Circle()))
                            .shadow(color: NeuPalette.shadowDark, radius: 4, x: 2, y: 2)
                    }
                    .disabled(!canSend)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat_button_send")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(NeuPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(NeuPalette.borderSoft, lineWidth: 1)
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
            // Remove the neuromorphic recessed background from the entire stack since the textfield has its own
            // background now
        }
        .padding(.horizontal, isCompact ? 0 : 8)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            NeuPalette.background
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Slash Command Autocomplete

    private var matchingSlashCommands: [SlashCommand] {
        let draft = appModel.chatStore.draft
        guard draft.hasPrefix("/"), draft.count > 1 else {
            return draft.hasPrefix("/") ? Array(SlashCommandHandler.builtInCommands.prefix(8)) : []
        }
        let matches = SlashCommandHandler.commands(matching: draft)
        return Array(matches.prefix(6))
    }

    private var slashCommandSuggestions: some View {
        let matches = matchingSlashCommands
        guard !matches.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                ForEach(matches) { cmd in
                    Button {
                        appModel.chatStore.draft = cmd.name + " "
                    } label: {
                        HStack(spacing: 8) {
                            Text(cmd.name)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(NeuPalette.accentCyan)
                            Text(cmd.description)
                                .font(.system(size: 12))
                                .foregroundStyle(NeuPalette.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(cmd.category.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(NeuPalette.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(NeuPalette.surface)
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat_button_slashcmd_\(cmd.name.dropFirst())")
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(NeuPalette.background)
                    .shadow(color: NeuPalette.shadowDark, radius: 4, y: 2)
            )
            .padding(.horizontal, isCompact ? 16 : 24)
        )
    }
}
