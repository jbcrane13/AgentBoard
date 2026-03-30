import SwiftUI
import UniformTypeIdentifiers
import WebKit
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

struct CanvasPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var showingFileImporter = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvasBody
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                            .padding(10)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.panelBackground)
        .dropDestination(for: URL.self) { droppedURLs, _ in
            guard !droppedURLs.isEmpty else { return false }
            Task {
                for url in droppedURLs {
                    await appState.openCanvasFile(url)
                }
            }
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image, .plainText, .html, .data],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                Task {
                    await appState.openCanvasFile(url)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text(contentTypeLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

            Spacer()

            Button {
                appState.goCanvasBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .disabled(!appState.canGoCanvasBack)
            .accessibilityIdentifier("canvas_button_back")

            Button {
                appState.goCanvasForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(!appState.canGoCanvasForward)
            .accessibilityIdentifier("canvas_button_forward")

            Divider()
                .frame(height: 14)

            Button {
                appState.adjustCanvasZoom(by: -0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("canvas_button_zoom_out")

            Button {
                appState.resetCanvasZoom()
            } label: {
                Text("\(Int(appState.canvasZoom * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(minWidth: 40)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("canvas_button_zoom_reset")

            Button {
                appState.adjustCanvasZoom(by: 0.1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("canvas_button_zoom_in")

            Divider()
                .frame(height: 14)

            Button("Open") {
                showingFileImporter = true
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("canvas_button_open")

            Button("Paste Image") {
                pasteImageFromClipboard()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("canvas_button_paste_image")

            Button("Export") {
                exportCanvasContent()
            }
            .buttonStyle(.plain)
            .disabled(appState.currentCanvasContent == nil)
            .accessibilityIdentifier("canvas_button_export")

            Button("Clear") {
                appState.clearCanvasHistory()
            }
            .buttonStyle(.plain)
            .disabled(appState.currentCanvasContent == nil)
            .accessibilityIdentifier("canvas_button_clear")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var canvasBody: some View {
        if let content = appState.currentCanvasContent {
            ZStack {
                CanvasWebView(
                    content: content,
                    zoom: appState.canvasZoom,
                    isLoading: Binding(
                        get: { appState.isCanvasLoading },
                        set: { appState.isCanvasLoading = $0 }
                    )
                )

                if appState.isCanvasLoading {
                    ProgressView("Rendering diagram...")
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary.opacity(0.4))
                Text("No Canvas Content")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Chat with your agent or drop a file here to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var contentTypeLabel: String {
        guard let content = appState.currentCanvasContent else {
            return "Empty"
        }
        switch content {
        case .markdown:
            return "Markdown"
        case .html:
            return "HTML"
        case .image:
            return "Image"
        case .diff:
            return "Diff"
        case .diagram:
            return "Mermaid"
        case .terminal:
            return "Terminal"
        }
    }

    private func pasteImageFromClipboard() {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            guard let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
                  let firstImage = images.first,
                  let temporaryURL = persistImageToTemporaryLocation(firstImage) else {
                appState.errorMessage = "No image found in clipboard."
                return
            }

            Task {
                await appState.openCanvasFile(temporaryURL)
            }
        #else
            guard let image = UIPasteboard.general.image,
                  let data = image.pngData() else {
                appState.errorMessage = "No image found in clipboard."
                return
            }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("agentboard-canvas-\(UUID().uuidString).png")
            do {
                try data.write(to: tempURL, options: .atomic)
                Task {
                    await appState.openCanvasFile(tempURL)
                }
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        #endif
    }

    #if os(macOS)
        private func persistImageToTemporaryLocation(_ image: NSImage) -> URL? {
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("agentboard-canvas-\(UUID().uuidString).png")
            do {
                try pngData.write(to: tempURL, options: .atomic)
                return tempURL
            } catch {
                appState.errorMessage = error.localizedDescription
                return nil
            }
        }
    #endif

    private func exportCanvasContent() {
        guard let content = appState.currentCanvasContent else { return }
        #if os(macOS)
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = defaultExportFilename(for: content)

            guard panel.runModal() == .OK, let url = panel.url else { return }

            do {
                switch content {
                case let .image(_, _, imageURL):
                    let data = try Data(contentsOf: imageURL)
                    try data.write(to: url, options: .atomic)

                case let .html(_, _, html):
                    try html.write(to: url, atomically: true, encoding: .utf8)

                case let .markdown(_, _, markdown):
                    try markdown.write(to: url, atomically: true, encoding: .utf8)

                case let .terminal(_, _, output):
                    try output.write(to: url, atomically: true, encoding: .utf8)

                case let .diagram(_, _, mermaid):
                    try mermaid.write(to: url, atomically: true, encoding: .utf8)

                case let .diff(_, _, before, after, filename):
                    let payload = "file: \(filename)\n\n\(before)\n---\n\(after)"
                    try payload.write(to: url, atomically: true, encoding: .utf8)
                }
                appState.statusMessage = "Exported canvas content."
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        #else
            // Export not available on iOS v1
        #endif
    }

    private func defaultExportFilename(for content: CanvasContent) -> String {
        switch content {
        case let .markdown(_, title, _):
            return sanitizedFilename(title, fallbackExtension: "md")
        case let .html(_, title, _):
            return sanitizedFilename(title, fallbackExtension: "html")
        case let .image(_, title, _):
            return sanitizedFilename(title, fallbackExtension: "png")
        case let .diff(_, title, _, _, _):
            return sanitizedFilename(title, fallbackExtension: "diff")
        case let .diagram(_, title, _):
            return sanitizedFilename(title, fallbackExtension: "mmd")
        case let .terminal(_, title, _):
            return sanitizedFilename(title, fallbackExtension: "txt")
        }
    }

    private func sanitizedFilename(_ title: String, fallbackExtension: String) -> String {
        let slug = title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = slug.isEmpty ? "canvas-content" : slug
        return "\(base).\(fallbackExtension)"
    }
}

#if os(macOS)
    private struct CanvasWebView: NSViewRepresentable {
        let content: CanvasContent
        let zoom: Double
        @Binding var isLoading: Bool

        func makeCoordinator() -> Coordinator {
            Coordinator(renderer: CanvasRenderer(), isLoading: _isLoading)
        }

        func makeNSView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.setValue(false, forKey: "drawsBackground")
            webView.navigationDelegate = context.coordinator
            return webView
        }

        func updateNSView(_ webView: WKWebView, context: Context) {
            webView.pageZoom = zoom
            if context.coordinator.lastRenderedID != content.id {
                if case .diagram = content {
                    isLoading = true
                } else {
                    isLoading = false
                }
                context.coordinator.renderer.render(content, in: webView)
                context.coordinator.lastRenderedID = content.id
            }
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
            let renderer: CanvasRenderer
            var isLoading: Binding<Bool>
            var lastRenderedID: UUID?

            init(renderer: CanvasRenderer, isLoading: Binding<Bool>) {
                self.renderer = renderer
                self.isLoading = isLoading
                lastRenderedID = nil
            }

            func webView(_: WKWebView, didFinish _: WKNavigation!) {
                isLoading.wrappedValue = false
            }

            func webView(
                _: WKWebView,
                didFail _: WKNavigation!,
                withError _: Error
            ) {
                isLoading.wrappedValue = false
            }

            func webView(
                _: WKWebView,
                didFailProvisionalNavigation _: WKNavigation!,
                withError _: Error
            ) {
                isLoading.wrappedValue = false
            }
        }
    }
#else
    private struct CanvasWebView: UIViewRepresentable {
        let content: CanvasContent
        let zoom: Double
        @Binding var isLoading: Bool

        func makeCoordinator() -> Coordinator {
            Coordinator(renderer: CanvasRenderer(), isLoading: _isLoading)
        }

        func makeUIView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.navigationDelegate = context.coordinator
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {
            if context.coordinator.lastRenderedID != content.id {
                if case .diagram = content {
                    isLoading = true
                } else {
                    isLoading = false
                }
                context.coordinator.renderer.render(content, in: webView)
                context.coordinator.lastRenderedID = content.id
            }
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
            let renderer: CanvasRenderer
            var isLoading: Binding<Bool>
            var lastRenderedID: UUID?

            init(renderer: CanvasRenderer, isLoading: Binding<Bool>) {
                self.renderer = renderer
                self.isLoading = isLoading
                lastRenderedID = nil
            }

            func webView(_: WKWebView, didFinish _: WKNavigation!) {
                isLoading.wrappedValue = false
            }

            func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
                isLoading.wrappedValue = false
            }

            func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
                isLoading.wrappedValue = false
            }
        }
    }
#endif
