import SwiftUI

struct MarkdownText: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case let .prose(text):
                    if let attributed = try? AttributedString(
                        markdown: text,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    ) {
                        Text(attributed)
                            .textSelection(.enabled)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(text)
                            .textSelection(.enabled)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                case let .code(code, language):
                    VStack(alignment: .leading, spacing: 4) {
                        if let language, !language.isEmpty {
                            Text(language.uppercased())
                                .font(.caption2.weight(.semibold))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(code)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(.green)
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.32))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Segment {
        case prose(String)
        case code(String, String?)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var remaining = content

        while !remaining.isEmpty {
            if let fenceRange = remaining.range(of: "```") {
                let before = String(remaining[remaining.startIndex ..< fenceRange.lowerBound])
                if !before.isEmpty {
                    result.append(.prose(before))
                }
                remaining = String(remaining[fenceRange.upperBound...])

                let firstLine = remaining.prefix(while: { $0 != "\n" })
                let language = String(firstLine).trimmingCharacters(in: .whitespaces).isEmpty
                    ? nil
                    : String(firstLine).trimmingCharacters(in: .whitespaces)

                if !firstLine.isEmpty {
                    remaining = String(remaining.dropFirst(firstLine.count))
                }
                if remaining.first == "\n" {
                    remaining = String(remaining.dropFirst())
                }

                if let closingRange = remaining.range(of: "```") {
                    let code = String(remaining[remaining.startIndex ..< closingRange.lowerBound])
                        .trimmingCharacters(in: .newlines)
                    result.append(.code(code, language))
                    remaining = String(remaining[closingRange.upperBound...])
                    if remaining.first == "\n" {
                        remaining = String(remaining.dropFirst())
                    }
                } else {
                    result.append(.code(remaining.trimmingCharacters(in: .newlines), language))
                    remaining = ""
                }
            } else {
                result.append(.prose(remaining))
                remaining = ""
            }
        }

        return result
    }
}
