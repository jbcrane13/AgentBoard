import SwiftUI

struct ChatPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var handledFocusRequestID = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            contextBar
            chatInput
        }
        .onAppear {
            appState.clearUnreadChatCount()
            handleFocusRequestIfNeeded()
        }
        .onChange(of: appState.chatInputFocusRequestID) { _, _ in
            handleFocusRequestIfNeeded()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(appState.chatMessages) { message in
                        ChatMessageBubble(
                            message: message,
                            onIssueTap: { issueID in
                                appState.openIssueFromChat(issueID: issueID)
                            },
                            onOpenInCanvas: {
                                appState.openMessageInCanvas(message)
                            }
                        )
                    }

                    if appState.isChatStreaming {
                        typingIndicator
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom")
                }
                .padding(16)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: appState.chatMessages) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: appState.isChatStreaming) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var typingIndicator: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AgentBoard")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                HStack(spacing: 4) {
                    Circle().frame(width: 6, height: 6)
                    Circle().frame(width: 6, height: 6)
                    Circle().frame(width: 6, height: 6)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground, in: UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 14,
                topTrailingRadius: 14
            ))
            Spacer(minLength: 20)
        }
    }

    private var contextBar: some View {
        HStack(spacing: 6) {
            if let beadID = appState.selectedBeadContextID {
                contextChip(label: beadID, color: .teal)
            }
            contextChip(label: "\(appState.remoteChatSessions.count) sessions", color: .teal)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func contextChip(label: String, color: Color) -> some View {
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
            TextEditor(text: $inputText)
                .font(.system(size: 13))
                .frame(minHeight: 40, maxHeight: 110)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .focused($isInputFocused)
                .overlay(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Message your agents...")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isChatStreaming)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 1.5, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sendMessage() {
        let message = inputText
        inputText = ""
        Task {
            await appState.sendChatMessage(message)
        }
    }

    private func handleFocusRequestIfNeeded() {
        guard appState.chatInputFocusRequestID != handledFocusRequestID else { return }
        handledFocusRequestID = appState.chatInputFocusRequestID
        isInputFocused = true
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo("chat-bottom", anchor: .bottom)
        }
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    let onIssueTap: (String) -> Void
    let onOpenInCanvas: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 20) }

            VStack(alignment: .leading, spacing: 6) {
                if message.role == .assistant {
                    Text("AgentBoard")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                messageContent

                if message.role == .assistant && !message.referencedIssueIDs.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.referencedIssueIDs, id: \.self) { issueID in
                            Button(issueID) {
                                onIssueTap(issueID)
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }

                if message.role == .assistant && message.sentToCanvas {
                    Text("📋 Sent to canvas")
                        .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground, in: bubbleShape)
            .foregroundStyle(message.role == .user ? .white : .primary)
            .contextMenu {
                if message.hasCodeBlock {
                    Button("Open in Canvas") {
                        onOpenInCanvas()
                    }
                }
            }

            if message.role == .assistant { Spacer(minLength: 20) }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        let segments = MarkdownSegment.parse(message.content)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .markdown(let content):
                    Text(.init(content))
                        .font(.system(size: 13))
                        .lineSpacing(2)
                case .code(let language, let code):
                    VStack(alignment: .leading, spacing: 4) {
                        if !language.isEmpty {
                            Text(language.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(code)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        message.role == .user
            ? AnyShapeStyle(Color(red: 0, green: 0.478, blue: 1.0))
            : AnyShapeStyle(AppTheme.cardBackground)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.role == .user {
            return UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 4,
                topTrailingRadius: 14
            )
        }
        return UnevenRoundedRectangle(
            topLeadingRadius: 14,
            bottomLeadingRadius: 4,
            bottomTrailingRadius: 14,
            topTrailingRadius: 14
        )
    }
}

private enum MarkdownSegment {
    case markdown(String)
    case code(language: String, content: String)

    static func parse(_ content: String) -> [MarkdownSegment] {
        guard !content.isEmpty else { return [.markdown("")] }

        var segments: [MarkdownSegment] = []
        var remaining = content[...]

        while let fenceStart = remaining.range(of: "```") {
            let before = String(remaining[..<fenceStart.lowerBound])
            if !before.isEmpty {
                segments.append(.markdown(before))
            }

            let afterFence = remaining[fenceStart.upperBound...]
            guard let fenceEnd = afterFence.range(of: "```") else {
                segments.append(.markdown(String(remaining[fenceStart.lowerBound...])))
                return segments
            }

            let codeBlockRaw = String(afterFence[..<fenceEnd.lowerBound])
            let lines = codeBlockRaw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            let language = lines.first.map(String.init) ?? ""
            let codeBody = lines.dropFirst().joined(separator: "\n")
            segments.append(.code(language: language.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), content: codeBody))

            remaining = afterFence[fenceEnd.upperBound...]
        }

        let tail = String(remaining)
        if !tail.isEmpty {
            segments.append(.markdown(tail))
        }

        return segments.isEmpty ? [.markdown(content)] : segments
    }
}
