import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Renders chat messages cleanly, hiding raw tool calls from users.
/// Shows human-readable summaries instead of raw terminal(command: ...) syntax.
struct MessageRenderer: View {
    let message: ChatMessage
    
    var body: some View {
        if isToolCall(message.content) {
            toolCallSummary
        } else if isCodeBlock(message.content) {
            codeBlockView
        } else {
            regularMessage
        }
    }
    
    // MARK: - Tool Call Detection
    
    private func isToolCall(_ content: String) -> Bool {
        content.contains("terminal(") || 
        content.contains("web_search(") ||
        content.contains("read_file(") ||
        content.contains("write_file(")
    }
    
    private func isCodeBlock(_ content: String) -> Bool {
        content.contains("```")
    }
    
    // MARK: - Tool Call Summary
    
    @ViewBuilder
    private var toolCallSummary: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            
            Text(parseToolCallSummary(message.content))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private func parseToolCallSummary(_ rawCall: String) -> String {
        if rawCall.contains("gh issue") || rawCall.contains("GitHub") {
            return "🔍 Checking GitHub issues..."
        } else if rawCall.contains("xcodebuild") || rawCall.contains("swift build") {
            return "🔨 Building project..."
        } else if rawCall.contains("git commit") || rawCall.contains("git push") {
            return "📝 Working with git..."
        } else if rawCall.contains("brew install") {
            return "📦 Installing dependencies..."
        } else if rawCall.contains("ls") || rawCall.contains("find") {
            return "📁 Browsing files..."
        }
        return "⚙️ Working..."
    }
    
    // MARK: - Code Block View
    
    @ViewBuilder
    private var codeBlockView: some View {
        let segments = parseMessageSegments(message.content)
        let isFromUser = message.role == .user
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let text):
                    Text(text)
                        .textSelection(.enabled)
                case .code(let code, let language):
                    CodeBlock(code: code, language: language)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isFromUser ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(12)
    }
    
    // MARK: - Regular Message
    
    @ViewBuilder
    private var regularMessage: some View {
        let isFromUser = message.role == .user
        
        Text(message.content)
            .textSelection(.enabled)
            .padding(12)
            .background(isFromUser ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundStyle(isFromUser ? .white : .primary)
            .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private enum MessageSegment {
        case text(String)
        case code(code: String, language: String?)
    }
    
    private func parseMessageSegments(_ content: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(content)]
        }
        
        let nsString = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
        
        var lastIndex = 0
        for match in matches {
            if match.range.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let text = nsString.substring(with: textRange)
                if !text.isEmpty {
                    segments.append(.text(text))
                }
            }
            
            let language = match.range(at: 1).location != NSNotFound ? nsString.substring(with: match.range(at: 1)) : nil
            let code = nsString.substring(with: match.range(at: 2))
            segments.append(.code(code: code, language: language))
            
            lastIndex = match.range.location + match.range.length
        }
        
        if lastIndex < nsString.length {
            let text = nsString.substring(from: lastIndex)
            if !text.isEmpty {
                segments.append(.text(text))
            }
        }
        
        return segments.isEmpty ? [.text(content)] : segments
    }
}

// MARK: - Code Block Component

struct CodeBlock: View {
    let code: String
    let language: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = language {
                HStack {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy") {
                        copyCodeToClipboard()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
            }
            
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func copyCodeToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = code
        #endif
    }
}
