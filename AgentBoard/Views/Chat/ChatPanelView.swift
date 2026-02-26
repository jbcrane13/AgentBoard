import SwiftUI

struct ChatPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var handledFocusRequestID = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            connectionErrorBanner
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

    // MARK: - Chat Header

    private var chatHeader: some View {
        HStack(spacing: 8) {
            // Connection indicator
            Circle()
                .fill(connectionIndicatorColor)
                .frame(width: 7, height: 7)

            // Session picker
            Menu {
                Button("main") {
                    Task { await appState.switchSession(to: "main") }
                }
                if !appState.gatewaySessions.isEmpty {
                    Divider()
                    ForEach(appState.gatewaySessions.filter { $0.key != "main" }) { session in
                        Button(session.label ?? session.key) {
                            Task { await appState.switchSession(to: session.key) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(appState.currentSessionKey)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Thinking level control
            Menu {
                Button("Default") {
                    Task { await appState.setThinkingLevel(nil) }
                }
                Button("Off") {
                    Task { await appState.setThinkingLevel("off") }
                }
                Button("Low") {
                    Task { await appState.setThinkingLevel("low") }
                }
                Button("Medium") {
                    Task { await appState.setThinkingLevel("medium") }
                }
                Button("High") {
                    Task { await appState.setThinkingLevel("high") }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "brain")
                        .font(.system(size: 10))
                    Text(thinkingLevelLabel)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(appState.chatThinkingLevel != nil ? Color.accentColor : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    appState.chatThinkingLevel != nil
                        ? Color.accentColor.opacity(0.1)
                        : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 4)
                )
            }
            .menuStyle(.borderlessButton)
            .help("Set session thinking level")

            // Connection status text
            Text(connectionStatusLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(connectionIndicatorColor)
                .help(connectionStatusTooltip)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Connection Error Banner

    @ViewBuilder
    private var connectionErrorBanner: some View {
        if let error = appState.connectionErrorDetail,
           appState.chatConnectionState != .connected {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                Text(error.userMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(error.indicatorColor.opacity(0.85))
        }
    }

    /// Returns the active connection error when not connected, or nil when healthy.
    private var activeConnectionError: ConnectionError? {
        guard appState.chatConnectionState != .connected else { return nil }
        return appState.connectionErrorDetail
    }

    private var connectionIndicatorColor: Color {
        activeConnectionError?.indicatorColor ?? appState.chatConnectionState.color
    }

    private var connectionStatusLabel: String {
        activeConnectionError?.briefLabel ?? appState.chatConnectionState.label
    }

    private var connectionStatusTooltip: String {
        activeConnectionError?.userMessage ?? appState.chatConnectionState.label
    }

    private var thinkingLevelLabel: String {
        guard let level = appState.chatThinkingLevel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !level.isEmpty else {
            return "Default"
        }
        switch level.lowercased() {
        case "off":
            return "Off"
        case "low":
            return "Low"
        case "medium":
            return "Medium"
        case "high":
            return "High"
        case "minimal":
            return "Minimal"
        default:
            return level.capitalized
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(appState.chatMessages) { message in
                        ChatMessageBubble(
                            message: message,
                            agentName: appState.agentName,
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
                Text(appState.agentName)
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

    // MARK: - Context Bar

    private var contextBar: some View {
        HStack(spacing: 6) {
            if let beadID = appState.selectedBeadID {
                contextChip(label: beadID, color: .teal)
            }
            contextChip(
                label: "\(appState.gatewaySessions.count) sessions",
                color: .teal
            )
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

    // MARK: - Chat Input

    private var chatInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $inputText)
                .font(.system(size: 13))
                .frame(minHeight: 40, maxHeight: 110)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .focused($isInputFocused)
                .onKeyPress(keys: [.return], phases: .down) { keyPress in
                    if keyPress.modifiers.contains(.shift) {
                        return .ignored // Shift+Enter inserts newline
                    }
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sendMessage()
                    }
                    return .handled // Enter sends (or suppresses empty send)
                }
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

            if appState.isChatStreaming {
                // Abort button
                Button(action: {
                    Task { await appState.abortChat() }
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Stop generation")
            } else {
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(10)
        .cardStyle()
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

// MARK: - Chat Message Bubble

struct ChatMessageBubble: View {
    let message: ChatMessage
    let agentName: String
    let onIssueTap: (String) -> Void
    let onOpenInCanvas: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 20) }

            VStack(alignment: .leading, spacing: 6) {
                if message.role == .assistant {
                    Text(agentName)
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

// MARK: - Markdown Segment Parser

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
