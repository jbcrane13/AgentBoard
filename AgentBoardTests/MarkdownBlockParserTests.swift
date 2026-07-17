import AgentBoardCore
import Foundation
import Testing

@Suite("Markdown block parser")
struct MarkdownBlockParserTests {
    @Test
    func headingParsesWithLevel() {
        let blocks = MarkdownBlockParser.parse("# Title")
        guard case let .heading(level, text) = blocks.first else {
            Issue.record("Expected heading, got \(blocks)")
            return
        }
        #expect(level == 1)
        #expect(String(text.characters) == "Title")
    }

    @Test
    func paragraphPreservesInlineBold() {
        let blocks = MarkdownBlockParser.parse("Hello **world**")
        guard case let .paragraph(text) = blocks.first else {
            Issue.record("Expected paragraph, got \(blocks)")
            return
        }
        let hasBoldRun = text.runs.contains { run in
            run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        }
        #expect(hasBoldRun)
        #expect(String(text.characters) == "Hello world")
    }

    @Test
    func fencedCodeBlockKeepsLanguageAndBody() {
        let blocks = MarkdownBlockParser.parse("```swift\nlet x = 1\n```")
        guard case let .code(body, language) = blocks.first else {
            Issue.record("Expected code block, got \(blocks)")
            return
        }
        #expect(language == "swift")
        #expect(body == "let x = 1")
    }

    @Test
    func unorderedListYieldsItems() {
        let blocks = MarkdownBlockParser.parse("- alpha\n- beta")
        guard case let .list(items, ordered) = blocks.first else {
            Issue.record("Expected list, got \(blocks)")
            return
        }
        #expect(ordered == false)
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.depth == 0 })
    }

    @Test
    func orderedListIsOrdered() {
        let blocks = MarkdownBlockParser.parse("1. first\n2. second")
        guard case let .list(_, ordered) = blocks.first else {
            Issue.record("Expected list, got \(blocks)")
            return
        }
        #expect(ordered == true)
    }

    @Test
    func nestedListItemCarriesDepth() {
        let blocks = MarkdownBlockParser.parse("- outer\n  - inner")
        guard case let .list(items, _) = blocks.first else {
            Issue.record("Expected list, got \(blocks)")
            return
        }
        #expect(items.contains { $0.depth == 1 })
    }

    @Test
    func blockquoteParses() {
        let blocks = MarkdownBlockParser.parse("> quoted wisdom")
        guard case let .blockquote(inner) = blocks.first else {
            Issue.record("Expected blockquote, got \(blocks)")
            return
        }
        guard case let .paragraph(text) = inner.first else {
            Issue.record("Expected inner paragraph, got \(inner)")
            return
        }
        #expect(String(text.characters) == "quoted wisdom")
    }

    @Test
    func pipeTableParsesHeadersAndRows() {
        let markdown = """
        | Name | Role |
        | ---- | ---- |
        | Ada  | Eng  |
        """
        let blocks = MarkdownBlockParser.parse(markdown)
        guard case let .table(headers, rows) = blocks.first else {
            Issue.record("Expected table, got \(blocks)")
            return
        }
        #expect(headers.map { String($0.characters) } == ["Name", "Role"])
        #expect(rows.count == 1)
        #expect(rows.first?.map { String($0.characters) } == ["Ada", "Eng"])
    }

    @Test
    func thematicBreakParses() {
        let blocks = MarkdownBlockParser.parse("above\n\n---\n\nbelow")
        #expect(blocks.contains { block in
            if case .thematicBreak = block { return true }
            return false
        })
    }

    @Test
    func emptyInputYieldsNoBlocks() {
        #expect(MarkdownBlockParser.parse("").isEmpty)
    }

    @Test
    func mixedDocumentKeepsBlockOrder() {
        let markdown = "# Head\n\nBody text\n\n```\ncode\n```"
        let blocks = MarkdownBlockParser.parse(markdown)
        #expect(blocks.count == 3)
        if case .heading = blocks[0] {} else { Issue.record("blocks[0] should be heading") }
        if case .paragraph = blocks[1] {} else { Issue.record("blocks[1] should be paragraph") }
        if case .code = blocks[2] {} else { Issue.record("blocks[2] should be code") }
    }
}
