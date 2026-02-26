import Foundation
import Testing
@testable import AgentBoard

@MainActor
@Suite("CanvasRenderer HTML Generation")
struct CanvasRendererHTMLTests {

    // MARK: - escapeHTML

    @Test("escapeHTML replaces ampersand")
    func escapeHTMLHandlesAmpersand() {
        let renderer = CanvasRenderer()
        #expect(renderer.escapeHTML("a & b") == "a &amp; b")
    }

    @Test("escapeHTML replaces less-than")
    func escapeHTMLHandlesLessThan() {
        let renderer = CanvasRenderer()
        #expect(renderer.escapeHTML("<b>") == "&lt;b&gt;")
    }

    @Test("escapeHTML replaces greater-than")
    func escapeHTMLHandlesGreaterThan() {
        let renderer = CanvasRenderer()
        #expect(renderer.escapeHTML("x > y") == "x &gt; y")
    }

    @Test("escapeHTML replaces double quote")
    func escapeHTMLHandlesDoubleQuote() {
        let renderer = CanvasRenderer()
        #expect(renderer.escapeHTML("say \"hi\"") == "say &quot;hi&quot;")
    }

    @Test("escapeHTML replaces single quote")
    func escapeHTMLHandlesSingleQuote() {
        let renderer = CanvasRenderer()
        #expect(renderer.escapeHTML("it's") == "it&#39;s")
    }

    @Test("escapeHTML handles empty string")
    func escapeHTMLHandlesEmptyString() {
        let renderer = CanvasRenderer()
        #expect(renderer.escapeHTML("") == "")
    }

    @Test("escapeHTML fully escapes XSS payload")
    func escapeHTMLCombinedXSSPayload() {
        let renderer = CanvasRenderer()
        let input = "<script>alert('xss')&</script>"
        let output = renderer.escapeHTML(input)
        #expect(!output.contains("<"))
        #expect(!output.contains(">"))
        #expect(!output.contains("'"))
        #expect(!output.contains("&alert"))
        #expect(output.contains("&lt;"))
        #expect(output.contains("&gt;"))
        #expect(output.contains("&#39;"))
        #expect(output.contains("&amp;"))
    }

    // MARK: - htmlDocument per content type

    @Test("htmlDocument for markdown contains article.markdown-body")
    func htmlDocumentMarkdownContainsArticleBody() {
        let renderer = CanvasRenderer()
        let content = CanvasContent.markdown(id: UUID(), title: "Title", content: "# Hello")
        let output = renderer.htmlDocument(for: content)
        #expect(output.contains("<article class=\"markdown-body\">"))
    }

    @Test("htmlDocument for html contains article.html-body")
    func htmlDocumentHTMLContainsHtmlBody() {
        let renderer = CanvasRenderer()
        let content = CanvasContent.html(id: UUID(), title: "Title", content: "<p>hi</p>")
        let output = renderer.htmlDocument(for: content)
        #expect(output.contains("<article class=\"html-body\">"))
    }

    @Test("htmlDocument for diff escapes filename containing angle brackets")
    func htmlDocumentDiffEscapesFilenameAndCode() {
        let renderer = CanvasRenderer()
        let content = CanvasContent.diff(
            id: UUID(),
            title: "Title",
            before: "before",
            after: "after",
            filename: "file<name>.swift"
        )
        let output = renderer.htmlDocument(for: content)
        #expect(output.contains("file&lt;name&gt;.swift"))
        #expect(!output.contains("file<name>.swift"))
    }

    @Test("htmlDocument for diagram contains mermaid div")
    func htmlDocumentDiagramContainsMermaidDiv() {
        let renderer = CanvasRenderer()
        let content = CanvasContent.diagram(id: UUID(), title: "Title", mermaid: "graph TD\nA-->B")
        let output = renderer.htmlDocument(for: content)
        #expect(output.contains("<div class=\"mermaid\">"))
    }

    @Test("htmlDocument for terminal escapes output")
    func htmlDocumentTerminalEscapesOutput() {
        let renderer = CanvasRenderer()
        let content = CanvasContent.terminal(id: UUID(), title: "Title", output: "<error>")
        let output = renderer.htmlDocument(for: content)
        #expect(output.contains("&lt;error&gt;"))
        #expect(!output.contains("<error>"))
    }

    @Test("htmlDocument for image escapes URL ampersand")
    func htmlDocumentImageEscapesURL() {
        let renderer = CanvasRenderer()
        let url = URL(string: "https://example.com/img?a=1&b=2")!
        let content = CanvasContent.image(id: UUID(), title: "Title", url: url)
        let output = renderer.htmlDocument(for: content)
        #expect(output.contains("a=1&amp;b=2"))
    }
}
