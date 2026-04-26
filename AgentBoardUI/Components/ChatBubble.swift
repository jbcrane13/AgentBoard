import AgentBoardCore
import SwiftUI

// MARK: - NeuChatBubble

struct NeuChatBubble: View {
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
                            .attachmentContextMenu(for: attachment)
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

// MARK: - AnyViewModifier

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
