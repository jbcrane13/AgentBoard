import AgentBoardCore
import SwiftUI

struct ChatComposeBar: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Binding var showAttachmentPicker: Bool
    @Bindable var audioRecorder: AudioRecorderService

    let isCompact: Bool
    let isTextFieldFocused: FocusState<Bool>.Binding
    let dismissKeyboard: () -> Void

    var body: some View {
        @Bindable var chatStore = appModel.chatStore

        return VStack(spacing: 0) {
            statusText(chatStore)

            if !chatStore.pendingAttachments.isEmpty {
                AttachmentPreviewStrip(attachments: $chatStore.pendingAttachments)
            }

            slashCommandSuggestions
            composeRow(chatStore)
        }
        .padding(.horizontal, isCompact ? 0 : 8)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(AppTheme.background.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func statusText(_ chatStore: ChatStore) -> some View {
        if let err = chatStore.errorMessage {
            Text(err)
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)
        } else if let status = chatStore.statusMessage {
            Text(status)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)
        }
    }

    private func composeRow(_ chatStore: ChatStore) -> some View {
        HStack(spacing: 8) {
            Button { showAttachmentPicker = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.accentCyan)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
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

            draftField(chatStore)
            sendButton(chatStore)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // Floating chrome per the native redesign: the compose bar is one of
        // the two surfaces that gets real glass (the other is the session
        // terminal header) — legibility here holds up fine against chat
        // content scrolling behind it.
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private func draftField(_ chatStore: ChatStore) -> some View {
        @Bindable var chatStore = chatStore

        return TextField(" Message Hermes...", text: $chatStore.draft, axis: .vertical)
            .lineLimit(1 ... 6)
            .focused(isTextFieldFocused)
            .foregroundStyle(AppTheme.textPrimary)
            .textFieldStyle(.plain)
            .submitLabel(.send)
            .accessibilityIdentifier("chat_textfield_draft")
            .onSubmit { sendIfPossible(chatStore) }
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.shift) { return .ignored }
                guard chatStore.canSendDraft else { return .ignored }
                sendIfPossible(chatStore)
                return .handled
            }
    }

    private func sendButton(_ chatStore: ChatStore) -> some View {
        Button {
            sendIfPossible(chatStore)
        } label: {
            Image(systemName: chatStore.isStreaming ? "stop.fill" : "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(canSend ? sendButtonForeground : AppTheme.textDisabled)
                .frame(width: 22, height: 22)
                .background(canSend ? sendButtonBackground : Color.clear)
                .clipShape(Circle())
        }
        .disabled(!canSend)
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_button_send")
    }

    @ViewBuilder
    private var slashCommandSuggestions: some View {
        let matches = matchingSlashCommands
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(matches) { cmd in
                    Button {
                        appModel.chatStore.draft = cmd.name + " "
                    } label: {
                        slashCommandRow(cmd)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat_button_slashcmd_\(cmd.name.dropFirst())")
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.background)
                    .shadow(color: AppTheme.shadowDark, radius: 4, y: 2)
            )
            .padding(.horizontal, isCompact ? 16 : 24)
        }
    }

    private func slashCommandRow(_ cmd: SlashCommand) -> some View {
        HStack(spacing: 8) {
            Text(cmd.name)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.accentCyan)
            Text(cmd.description)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Spacer()
            Text(cmd.category.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(AppTheme.surface))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func sendIfPossible(_ chatStore: ChatStore) {
        guard chatStore.canSendDraft else { return }
        isTextFieldFocused.wrappedValue = false
        dismissKeyboard()
        AgentBoardKeyboard.dismiss()
        Task { await chatStore.sendDraftWithRetry() }
    }

    private var matchingSlashCommands: [SlashCommand] {
        let draft = appModel.chatStore.draft
        guard draft.hasPrefix("/"), draft.count > 1 else {
            return draft.hasPrefix("/") ? Array(SlashCommandHandler.builtInCommands.prefix(8)) : []
        }
        return Array(SlashCommandHandler.commands(matching: draft).prefix(6))
    }

    private var canSend: Bool {
        let chatStore = appModel.chatStore
        return chatStore.isStreaming || chatStore.canSendDraft
    }

    private var sendButtonForeground: Color {
        let chatStore = appModel.chatStore
        // Justified: icon drawn on the solid `.red` stop-button fill below.
        if chatStore.isStreaming { return .white }
        return canSend ? AppTheme.accentForeground : AppTheme.textSecondary
    }

    private var sendButtonBackground: Color {
        let chatStore = appModel.chatStore
        if chatStore.isStreaming { return .red }
        return canSend ? AppTheme.accentCyan : AppTheme.surface
    }
}
