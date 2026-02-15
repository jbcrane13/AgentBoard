import Foundation
import Markdown
import WebKit

@MainActor
final class CanvasRenderer {
    func render(_ content: CanvasContent, in webView: WKWebView) {
        webView.loadHTMLString(htmlDocument(for: content), baseURL: nil)
    }

    func clear(in webView: WKWebView) {
        webView.loadHTMLString(emptyDocument, baseURL: nil)
    }

    private func htmlDocument(for content: CanvasContent) -> String {
        switch content {
        case .markdown(_, let title, let markdown):
            let renderedHTML = HTMLFormatter.format(markdown)
            return shell(title: title, body: "<article class=\"markdown-body\">\(renderedHTML)</article>", includeMermaid: false)

        case .html(_, let title, let html):
            return shell(title: title, body: "<article class=\"html-body\">\(html)</article>", includeMermaid: false)

        case .image(_, let title, let url):
            let escapedURL = escapeHTML(url.absoluteString)
            let body = """
            <section class="media-wrap">
              <img alt="Canvas image" src="\(escapedURL)" />
            </section>
            """
            return shell(title: title, body: body, includeMermaid: false)

        case .diff(_, let title, let before, let after, let filename):
            let body = """
            <section class="diff-wrap">
              <div class="diff-header">\(escapeHTML(filename))</div>
              <div class="diff-columns">
                <div class="diff-column">
                  <div class="diff-column-title">Before</div>
                  <pre><code>\(escapeHTML(before))</code></pre>
                </div>
                <div class="diff-column">
                  <div class="diff-column-title">After</div>
                  <pre><code>\(escapeHTML(after))</code></pre>
                </div>
              </div>
            </section>
            """
            return shell(title: title, body: body, includeMermaid: false)

        case .diagram(_, let title, let mermaid):
            let body = """
            <section class="diagram-wrap">
              <div class="mermaid">\(escapeHTML(mermaid))</div>
            </section>
            """
            return shell(title: title, body: body, includeMermaid: true)

        case .terminal(_, let title, let output):
            let body = """
            <section class="terminal-wrap">
              <pre><code>\(escapeHTML(output))</code></pre>
            </section>
            """
            return shell(title: title, body: body, includeMermaid: false)
        }
    }

    private func shell(title: String, body: String, includeMermaid: Bool) -> String {
        let mermaidScript: String
        if includeMermaid {
            mermaidScript = """
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
            <script>
            mermaid.initialize({ startOnLoad: true, securityLevel: "loose", theme: "default" });
            </script>
            """
        } else {
            mermaidScript = ""
        }

        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <title>\(escapeHTML(title))</title>
            <style>
              :root {
                color-scheme: light dark;
                --bg: #f8f7ef;
                --card: #ffffff;
                --text: #1a1a1a;
                --muted: #61646b;
                --border: #dfdbc8;
              }
              @media (prefers-color-scheme: dark) {
                :root {
                  --bg: #1b1b1c;
                  --card: #272729;
                  --text: #f2f2f2;
                  --muted: #b1b5be;
                  --border: #3a3a3d;
                }
              }
              html, body {
                margin: 0;
                padding: 0;
                background: var(--bg);
                color: var(--text);
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              }
              main {
                padding: 16px;
              }
              h1, h2, h3 {
                margin: 0 0 12px 0;
              }
              .title {
                margin-bottom: 12px;
                font-size: 14px;
                font-weight: 700;
              }
              .markdown-body, .html-body, .diagram-wrap, .terminal-wrap, .diff-wrap, .media-wrap {
                background: var(--card);
                border: 1px solid var(--border);
                border-radius: 10px;
                padding: 14px;
                box-sizing: border-box;
              }
              .markdown-body pre,
              .terminal-wrap pre,
              .diff-wrap pre {
                overflow-x: auto;
                padding: 12px;
                border-radius: 8px;
                background: color-mix(in oklab, var(--card) 75%, black 25%);
                color: #f2f2f2;
              }
              .markdown-body code,
              .terminal-wrap code,
              .diff-wrap code {
                font-family: "JetBrains Mono", "SF Mono", Menlo, monospace;
                font-size: 12px;
              }
              .media-wrap {
                display: flex;
                justify-content: center;
              }
              .media-wrap img {
                max-width: 100%;
                height: auto;
                border-radius: 8px;
              }
              .diff-header {
                font-weight: 700;
                font-size: 13px;
                margin-bottom: 12px;
                color: var(--muted);
              }
              .diff-columns {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 12px;
              }
              .diff-column-title {
                font-size: 12px;
                font-weight: 600;
                color: var(--muted);
                margin-bottom: 6px;
              }
              .diagram-wrap .mermaid {
                display: flex;
                justify-content: center;
              }
            </style>
            \(mermaidScript)
          </head>
          <body>
            <main>
              <div class="title">\(escapeHTML(title))</div>
              \(body)
            </main>
          </body>
        </html>
        """
    }

    private var emptyDocument: String {
        """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <style>
              body {
                margin: 0;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                display: flex;
                align-items: center;
                justify-content: center;
                height: 100vh;
                color: #8a8a8a;
                background: #f8f7ef;
              }
            </style>
          </head>
          <body>Canvas is empty.</body>
        </html>
        """
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
