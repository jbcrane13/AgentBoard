import SwiftUI

/// Renders chat messages with clean, user-friendly display.
/// Hides raw tool calls from users and shows human-readable summaries instead.
struct MessageRenderer: View {
    let message: ChatMessage
    var agentName: String = "Agent"
    var onIssueTap: ((String) -> Void)?
    var onOpenInCanvas: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 20) }

            VStack(alignment: .leading, spacing: 6) {
                if message.role == .assistant {
                    Text(agentName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                renderedContent

                if message.role == .assistant && !message.referencedIssueIDs.isEmpty {
                    issueChips
                }

                if message.role == .assistant && message.sentToCanvas {
                    Text("Sent to canvas")
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
                        onOpenInCanvas?()
                    }
                }
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.content, forType: .string)
                }
            }

            if message.role == .assistant { Spacer(minLength: 20) }
        }
    }

    // MARK: - Content Rendering

    @ViewBuilder
    private var renderedContent: some View {
        let processed = MessageRenderer.processContent(message.content)
        let segments = MessageSegment.parse(processed)

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    Text(.init(content))
                        .font(.system(size: 13))
                        .lineSpacing(2)

                case .code(let language, let code):
                    codeBlock(language: language, code: code)

                case .toolSummary(let summary):
                    toolSummaryChip(summary)
                }
            }
        }
    }

    private func codeBlock(language: String, code: String) -> some View {
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

    private func toolSummaryChip(_ summary: String) -> some View {
        HStack(spacing: 6) {
            Text(summary)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var issueChips: some View {
        HStack(spacing: 6) {
            ForEach(message.referencedIssueIDs, id: \.self) { issueID in
                Button(issueID) {
                    onIssueTap?(issueID)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    // MARK: - Styling

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

// MARK: - Content Processing

extension MessageRenderer {
    /// Process raw message content to replace tool calls with summaries.
    static func processContent(_ content: String) -> String {
        var result = content

        // Pattern: terminal(command: "...") or terminal(command: "...")
        let terminalPattern = #"terminal\s*\(\s*command\s*:\s*"([^"]+)"\s*\)"#
        result = replacePattern(result, pattern: terminalPattern) { match in
            let command = match
            return summarizeCommand(command)
        }

        // Pattern: tool_call(name: "...", ...) or function_call(...)
        let toolCallPattern = #"(?:tool_call|function_call)\s*\([^)]+\)"#
        result = replacePattern(result, pattern: toolCallPattern) { _ in
            nil // Remove generic tool calls
        }

        return result
    }

    private static func replacePattern(
        _ input: String,
        pattern: String,
        transform: (String) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return input
        }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, options: [], range: nsRange)

        var result = input
        // Process in reverse order to maintain string indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let captureRange = Range(match.range(at: 1), in: result) else {
                continue
            }

            let captured = String(result[captureRange])
            if let replacement = transform(captured) {
                result.replaceSubrange(range, with: replacement)
            } else {
                // Remove the match entirely if nil is returned
                result.replaceSubrange(range, with: "")
            }
        }

        return result
    }

    /// Summarize terminal commands into human-readable descriptions.
    static func summarizeCommand(_ command: String) -> String {
        let cmd = command.lowercased()

        // GitHub CLI commands
        if cmd.contains("gh issue") {
            if cmd.contains("list") {
                return "Checking GitHub issues..."
            } else if cmd.contains("create") {
                return "Creating a new issue..."
            } else if cmd.contains("edit") || cmd.contains("update") {
                return "Updating issue..."
            } else if cmd.contains("close") {
                return "Closing issue..."
            } else if cmd.contains("view") || cmd.contains("show") {
                return "Viewing issue details..."
            }
            return "Working with GitHub issues..."
        }

        if cmd.contains("gh pr") {
            if cmd.contains("list") {
                return "Checking pull requests..."
            } else if cmd.contains("create") {
                return "Creating pull request..."
            } else if cmd.contains("merge") {
                return "Merging pull request..."
            }
            return "Working with pull requests..."
        }

        // Build commands
        if cmd.contains("xcodebuild") || cmd.contains("swift build") {
            return "Building project..."
        }

        if cmd.contains("swift test") || cmd.contains("xcodebuild test") {
            return "Running tests..."
        }

        // Git commands
        if cmd.contains("git") {
            if cmd.contains("git status") {
                return "Checking repository status..."
            } else if cmd.contains("git diff") {
                return "Viewing changes..."
            } else if cmd.contains("git log") {
                return "Viewing commit history..."
            } else if cmd.contains("git commit") {
                return "Committing changes..."
            } else if cmd.contains("git push") {
                return "Pushing changes..."
            } else if cmd.contains("git pull") {
                return "Pulling latest changes..."
            } else if cmd.contains("git checkout") || cmd.contains("git switch") {
                return "Switching branches..."
            } else if cmd.contains("git branch") {
                return "Working with branches..."
            }
            return "Working with git..."
        }

        // File operations
        if cmd.contains("ls") || cmd.contains("find") {
            return "Browsing files..."
        }
        if cmd.contains("cat") || cmd.contains("head") || cmd.contains("tail") {
            return "Reading file contents..."
        }
        if cmd.contains("mkdir") || cmd.contains("touch") {
            return "Creating files..."
        }
        if cmd.contains("rm") || cmd.contains("mv") {
            return "Modifying files..."
        }
        if cmd.contains("cp") {
            return "Copying files..."
        }

        // Package managers
        if cmd.contains("brew install") || cmd.contains("brew upgrade") {
            return "Installing dependencies..."
        }
        if cmd.contains("npm install") || cmd.contains("yarn add") || cmd.contains("pnpm add") {
            return "Installing packages..."
        }
        if cmd.contains("pod install") || cmd.contains("pod update") {
            return "Updating CocoaPods..."
        }

        // Default
        return "Working..."
    }
}

// MARK: - Message Segment Parser

enum MessageSegment: Equatable {
    case text(String)
    case code(language: String, content: String)
    case toolSummary(String)

    static func parse(_ content: String) -> [MessageSegment] {
        guard !content.isEmpty else { return [.text("")] }

        var segments: [MessageSegment] = []
        var remaining = content[...]

        while let fenceStart = remaining.range(of: "```") {
            let before = String(remaining[..<fenceStart.lowerBound])
            if !before.isEmpty {
                // Check for tool summary markers in the text before code block
                segments.append(contentsOf: parseTextForToolSummaries(before))
            }

            let afterFence = remaining[fenceStart.upperBound...]
            guard let fenceEnd = afterFence.range(of: "```") else {
                segments.append(.text(String(remaining[fenceStart.lowerBound...])))
                return segments
            }

            let codeBlockRaw = String(afterFence[..<fenceEnd.lowerBound])
            let lines = codeBlockRaw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            let language = lines.first.map(String.init) ?? ""
            let codeBody = lines.dropFirst().joined(separator: "\n")
            segments.append(.code(
                language: language.trimmingCharacters(in: .whitespacesAndNewlines),
                content: codeBody
            ))

            remaining = afterFence[fenceEnd.upperBound...]
        }

        let tail = String(remaining)
        if !tail.isEmpty {
            segments.append(contentsOf: parseTextForToolSummaries(tail))
        }

        return segments.isEmpty ? [.text(content)] : segments
    }

    /// Parse text for tool summary markers (e.g., [TOOL_SUMMARY:Working with git...])
    private static func parseTextForToolSummaries(_ text: String) -> [MessageSegment] {
        let pattern = #"\[TOOL_SUMMARY:([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        guard !matches.isEmpty else {
            return [.text(text)]
        }

        var segments: [MessageSegment] = []
        var lastEnd = text.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: text),
                  let captureRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            // Add text before this match
            let beforeText = String(text[lastEnd..<matchRange.lowerBound])
            if !beforeText.isEmpty {
                segments.append(.text(beforeText))
            }

            // Add the tool summary
            let summary = String(text[captureRange])
            segments.append(.toolSummary(summary))

            lastEnd = matchRange.upperBound
        }

        // Add remaining text after last match
        let remainingText = String(text[lastEnd...])
        if !remainingText.isEmpty {
            segments.append(.text(remainingText))
        }

        return segments.isEmpty ? [.text(text)] : segments
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        MessageRenderer(
            message: ChatMessage(
                role: .assistant,
                content: "I'll check the GitHub issues for you.\n\nterminal(command: \"gh issue list --repo owner/repo\")\n\nFound 4 open issues."
            ),
            agentName: "Hermes"
        )

        MessageRenderer(
            message: ChatMessage(
                role: .user,
                content: "Can you build the project?"
            )
        )

        MessageRenderer(
            message: ChatMessage(
                role: .assistant,
                content: "Building the project now.\n\nterminal(command: \"xcodebuild -scheme AgentBoard build\")\n\nBuild succeeded!"
            ),
            agentName: "Hermes"
        )
    }
    .padding()
    .frame(width: 400)
}
