import Foundation
import Markdown

/// A block-level chunk of a rendered chat message. `MarkdownText` (UI) maps
/// each case to a SwiftUI view; parsing lives here in Core so it is unit
/// testable.
public enum MarkdownBlock: Equatable, Sendable {
    public struct ListItem: Equatable, Sendable {
        public let text: AttributedString
        public let depth: Int

        public init(text: AttributedString, depth: Int) {
            self.text = text
            self.depth = depth
        }
    }

    case paragraph(AttributedString)
    case heading(level: Int, text: AttributedString)
    case code(String, language: String?)
    case list(items: [ListItem], ordered: Bool)
    case blockquote([MarkdownBlock])
    case table(headers: [AttributedString], rows: [[AttributedString]])
    case thematicBreak
}

public enum MarkdownBlockParser {
    public static func parse(_ content: String) -> [MarkdownBlock] {
        let document = Document(parsing: content)
        return document.children.flatMap { block(from: $0) }
    }

    // MARK: - Block mapping

    private static func block(from markup: Markup) -> [MarkdownBlock] {
        switch markup {
        case let heading as Heading:
            return [.heading(level: min(max(heading.level, 1), 6), text: inlineText(of: heading))]
        case let code as CodeBlock:
            return [.code(
                code.code.trimmingCharacters(in: .newlines),
                language: code.language?.trimmedOrNil
            )]
        case let list as UnorderedList:
            return [.list(items: listItems(of: list, depth: 0), ordered: false)]
        case let list as OrderedList:
            return [.list(items: listItems(of: list, depth: 0), ordered: true)]
        case let quote as BlockQuote:
            return [.blockquote(quote.children.flatMap { block(from: $0) })]
        case let table as Markdown.Table:
            return [tableBlock(from: table)]
        case is ThematicBreak:
            return [.thematicBreak]
        default:
            // Paragraphs and any unhandled block type degrade to styled prose.
            let text = inlineText(of: markup)
            return text.characters.isEmpty ? [] : [.paragraph(text)]
        }
    }

    private static func listItems(of list: Markup, depth: Int) -> [MarkdownBlock.ListItem] {
        list.children.compactMap { $0 as? Markdown.ListItem }.flatMap { item -> [MarkdownBlock.ListItem] in
            var rows: [MarkdownBlock.ListItem] = []
            var nested: [MarkdownBlock.ListItem] = []
            var ownText = AttributedString()

            for child in item.children {
                switch child {
                case let sublist as UnorderedList:
                    nested.append(contentsOf: listItems(of: sublist, depth: depth + 1))
                case let sublist as OrderedList:
                    nested.append(contentsOf: listItems(of: sublist, depth: depth + 1))
                default:
                    if !ownText.characters.isEmpty {
                        ownText += AttributedString(" ")
                    }
                    ownText += inlineText(of: child)
                }
            }

            if !ownText.characters.isEmpty {
                rows.append(MarkdownBlock.ListItem(text: ownText, depth: depth))
            }
            rows.append(contentsOf: nested)
            return rows
        }
    }

    private static func tableBlock(from table: Markdown.Table) -> MarkdownBlock {
        let headers = table.head.cells.map { inlineText(of: $0) } as [AttributedString]
        let rows = table.body.rows.map { row in
            row.cells.map { inlineText(of: $0) } as [AttributedString]
        } as [[AttributedString]]
        return .table(headers: headers, rows: rows)
    }

    // MARK: - Inline styling

    /// Re-serialize a block's inline content to markdown and let Foundation
    /// apply inline styling (bold/italic/links/inline code). Falls back to
    /// plain text when Foundation rejects the fragment.
    private static func inlineText(of markup: Markup) -> AttributedString {
        let source = inlineMarkdownSource(of: markup)
        if let attributed = try? AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(markup.format().trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func inlineMarkdownSource(of markup: Markup) -> String {
        // Detach before formatting — format() on an attached node re-applies
        // ancestor block prefixes (e.g. "> " inside blockquotes).
        let detached = markup.detachedFromParent
        if detached is InlineMarkup {
            return detached.format()
        }
        return detached.children
            .map { $0.detachedFromParent.format() }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
