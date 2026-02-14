import SwiftUI

struct ChatPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            messageList

            contextBar

            chatInput
        }
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(appState.chatMessages) { message in
                    ChatMessageBubble(message: message)
                }
            }
            .padding(16)
        }
        .defaultScrollAnchor(.bottom)
    }

    private var contextBar: some View {
        HStack(spacing: 6) {
            contextChip(icon: "circle.fill", label: "NM-096", color: .teal)
            contextChip(icon: "circle.fill", label: "2 sessions", color: .teal)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func contextChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private var chatInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message your agents...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...5)

            Button(action: {
                inputText = ""
            }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.886, green: 0.878, blue: 0.847), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1.5, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 20) }

            VStack(alignment: .leading, spacing: 3) {
                if message.role == .assistant {
                    Text("AgentBoard")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                Text(message.content)
                    .font(.system(size: 13))
                    .lineSpacing(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground, in: bubbleShape)
            .foregroundStyle(message.role == .user ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))

            if message.role == .assistant { Spacer(minLength: 20) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        message.role == .user
            ? AnyShapeStyle(Color(red: 0, green: 0.478, blue: 1.0))
            : AnyShapeStyle(Color.white)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.role == .user {
            UnevenRoundedRectangle(
                topLeadingRadius: 14, bottomLeadingRadius: 14,
                bottomTrailingRadius: 4, topTrailingRadius: 14
            )
        } else {
            UnevenRoundedRectangle(
                topLeadingRadius: 14, bottomLeadingRadius: 4,
                bottomTrailingRadius: 14, topTrailingRadius: 14
            )
        }
    }
}
