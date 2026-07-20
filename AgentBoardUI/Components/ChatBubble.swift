import AgentBoardCore
import SwiftUI

// MARK: - ChatBubbleView

struct ChatBubbleView: View {
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

    private var senderLabel: String {
        switch message.role {
        case .assistant: "Hermes"
        case .user: "You"
        case .system: "System"
        }
    }

    /// Bubble text color, threaded down through `MarkdownText` (which inherits
    /// this ambient color rather than hardcoding its own): white is justified
    /// here as text drawn directly on the user bubble's accent-tinted fill.
    private var bubbleTextColor: Color {
        switch message.role {
        case .assistant: AppTheme.textPrimary
        case .user: .white
        case .system: AppTheme.textSecondary
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(senderLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(message.role == .assistant ? AppTheme.accentCyan : AppTheme.accentOrange)
                    .tracking(1)

                if message.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(AppTheme.accentCyan)
                }
            }

            if message.role == .assistant, !message.toolActivities.isEmpty {
                toolActivityChips
            }

            if message.isStreaming, message.content.isEmpty {
                Text("typing...")
                    .foregroundStyle(bubbleTextColor)
            } else {
                MarkdownText(content: message.content)
                    .foregroundStyle(bubbleTextColor)
            }

            // Render attachments
            if !message.attachments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(message.attachments) { attachment in
                        AttachmentContainerView(attachment: attachment)
                            .attachmentContextMenu(for: attachment)
                            .accessibilityIdentifier("chat_bubble_attachment_\(attachment.id)")
                    }
                }
            }
        }
        .padding(20)
        .background(bubbleBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.borderSoft, lineWidth: message.role == .user ? 0 : 1)
        )
    }

    /// Assistant = material surface with a hairline stroke; user = accent-
    /// tinted fill; system/info = a quiet tertiary fill.
    @ViewBuilder
    private var bubbleBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        switch message.role {
        case .assistant:
            shape.fill(.regularMaterial)
        case .user:
            shape.fill(AppTheme.accentCyan)
        case .system:
            shape.fill(.tertiary)
        }
    }

    private var toolActivityChips: some View {
        HStack(spacing: 8) {
            ForEach(message.toolActivities) { activity in
                ToolActivityChip(activity: activity)
            }
        }
    }
}

// MARK: - ToolActivityChip

private struct ToolActivityChip: View {
    let activity: ToolActivity

    var body: some View {
        HStack(spacing: 5) {
            if let emoji = activity.emoji {
                Text(emoji)
            } else {
                Image(systemName: "wrench.and.screwdriver")
            }

            Text(activity.label ?? activity.tool)
                .lineLimit(1)

            if activity.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .semibold))
            } else {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .font(.caption)
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(AppTheme.surfaceHover)
        )
        .opacity(activity.isComplete ? 0.65 : 1.0)
        .accessibilityIdentifier("chat_chip_tool_\(activity.id)")
    }
}
