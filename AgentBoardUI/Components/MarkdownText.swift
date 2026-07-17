import AgentBoardCore
import SwiftUI

struct MarkdownText: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MarkdownBlockParser.parse(content).enumerated()), id: \.offset) { _, block in
                MarkdownBlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Renders one block. A nominal type (not a `@ViewBuilder` function) so
/// blockquotes can recurse without producing a self-referential opaque type.
private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        blockView(block)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .paragraph(text):
            proseText(text)

        case let .heading(level, text):
            Text(text)
                .font(.system(size: max(22 - CGFloat(level) * 2, 13), weight: .bold))
                .textSelection(.enabled)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

        case let .code(code, language):
            codeBlock(code, language: language)

        case let .list(items, ordered):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(ordered && item.depth == 0 ? "\(orderedIndex(items, upTo: index))." : "•")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.55))
                        proseText(item.text)
                    }
                    .padding(.leading, CGFloat(item.depth) * 16)
                }
            }

        case let .blockquote(inner):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(inner.enumerated()), id: \.offset) { _, innerBlock in
                        MarkdownBlockView(block: innerBlock)
                    }
                }
                .opacity(0.8)
            }

        case let .table(headers, rows):
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                            Text(header)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    Divider().overlay(Color.white.opacity(0.2))
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                Text(cell)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                }
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.24))
            )

        case .thematicBreak:
            Divider().overlay(Color.white.opacity(0.2))
        }
    }

    private func proseText(_ text: AttributedString) -> some View {
        Text(text)
            .textSelection(.enabled)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Ordinal for top-level ordered-list rows, skipping nested rows that are
    /// flattened into the same item array.
    private func orderedIndex(_ items: [MarkdownBlock.ListItem], upTo index: Int) -> Int {
        items[...index].filter { $0.depth == 0 }.count
    }

    private func codeBlock(_ code: String, language: String?) -> some View {
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
