import Foundation
import Testing
@testable import AgentBoard

// NOTE: CanvasRenderer uses WKWebView which requires a live run loop and causes
// hangs in the unit test environment. CanvasContent logic is tested via AppState
// (pushCanvasContent, clearCanvasHistory, openMessageInCanvas) in AppStateCoverageTests.
// The render() and clear() methods are fire-and-forget wrappers over loadHTMLString().
//
// This file is intentionally left with only a stub so the test target still compiles.

@Suite("CanvasRenderer Coverage")
struct CanvasRendererTests {
    @Test("CanvasContent types all have non-nil UUIDs")
    func canvasContentTypesHaveNonNilIDs() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/image.png")

        // Verify each CanvasContent case can be constructed and carries its id
        let md = CanvasContent.markdown(id: id, title: "T", content: "C")
        let html = CanvasContent.html(id: id, title: "T", content: "<p/>")
        let img = CanvasContent.image(id: id, title: "T", url: url)
        let diff = CanvasContent.diff(id: id, title: "T", before: "a", after: "b", filename: "f")
        let diag = CanvasContent.diagram(id: id, title: "T", mermaid: "graph TD;")
        let term = CanvasContent.terminal(id: id, title: "T", output: "out")

        for content in [md, html, img, diff, diag, term] {
            #expect(content.id == id)
        }
    }

    @Test("CanvasContent markdown carries title and content")
    func canvasContentMarkdownFields() {
        let content = CanvasContent.markdown(id: UUID(), title: "My Title", content: "# Hello")
        if case .markdown(_, let title, let body) = content {
            #expect(title == "My Title")
            #expect(body == "# Hello")
        } else {
            Issue.record("Expected markdown case")
        }
    }

    @Test("CanvasContent diff carries before, after, and filename")
    func canvasContentDiffFields() {
        let content = CanvasContent.diff(
            id: UUID(),
            title: "Diff",
            before: "old",
            after: "new",
            filename: "main.swift"
        )
        if case .diff(_, _, let before, let after, let filename) = content {
            #expect(before == "old")
            #expect(after == "new")
            #expect(filename == "main.swift")
        } else {
            Issue.record("Expected diff case")
        }
    }

    @Test("CanvasContent diagram carries mermaid source")
    func canvasContentDiagramFields() {
        let mermaid = "graph TD; A-->B"
        let content = CanvasContent.diagram(id: UUID(), title: "Flow", mermaid: mermaid)
        if case .diagram(_, _, let source) = content {
            #expect(source == mermaid)
        } else {
            Issue.record("Expected diagram case")
        }
    }
}
