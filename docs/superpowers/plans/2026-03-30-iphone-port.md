# GH-22: iPhone Port of AgentBoard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add iOS (iPhone) as a second platform target to AgentBoard, reusing all models, services, and most views from the macOS app.

**Architecture:** Single multiPlatform XcodeGen target that compiles for both macOS 15+ and iOS 18+. Platform-specific code gated with `#if os(macOS)` / `#if os(iOS)`. iOS uses a 5-tab TabView (Board, Chat, Sessions, Agents, More) instead of the macOS 3-panel layout. SwiftTerm (macOS-only) is excluded from iOS; terminal is replaced by a read-only session log viewer.

**Tech Stack:** Swift 6, SwiftUI, XcodeGen (multiPlatform target), WebKit, SwiftTerm (macOS only), swift-markdown

---

## File Map

### Files to Modify (platform guards)

| File | What changes |
|------|-------------|
| `project.yml` | Convert to `multiPlatform` target with macOS + iOS platforms |
| `AgentBoard/Utilities/AppTheme.swift` | Replace `NSColor`/`AppKit` with cross-platform `#if os()` |
| `AgentBoard/App/AgentBoardApp.swift` | Guard macOS window commands; add iOS entry point |
| `AgentBoard/Views/MainWindow/ContentView.swift` | Guard `NSCursor`; keep macOS-only |
| `AgentBoard/Views/Canvas/CanvasPanelView.swift` | Guard `NSPasteboard`, `NSSavePanel`, `NSViewRepresentable`→`UIViewRepresentable` |
| `AgentBoard/Views/RightPanel/RightPanelView.swift` | Guard `NSApplication.shared.keyWindow` |
| `AgentBoard/Views/Board/TaskDetailSheet.swift` | Guard `NSPasteboard`/`NSImage`/`NSBitmapImageRep` |
| `AgentBoard/Views/Settings/PairingGuideView.swift` | Guard `NSPasteboard` |
| `AgentBoard/Views/Terminal/TerminalView.swift` | Guard entire file macOS-only (uses InteractiveTerminalView) |
| `AgentBoard/Views/Terminal/InteractiveTerminalView.swift` | Guard entire file macOS-only (SwiftTerm) |
| `AgentBoard/Utilities/TerminalLauncher.swift` | Guard entire file macOS-only (NSWorkspace, AppleScript) |
| `AgentBoard/Utilities/ShellCommand.swift` | Guard `Process()` as macOS-only |
| `AgentBoard/Services/SessionMonitor.swift` | Guard tmux/process methods macOS-only; provide iOS stubs |

### New Files (iOS)

| File | Purpose |
|------|---------|
| `AgentBoard/Views/iOS/iOSRootView.swift` | 5-tab TabView root for iPhone |
| `AgentBoard/Views/iOS/iOSBoardView.swift` | Board tab — NavigationStack wrapping BoardView |
| `AgentBoard/Views/iOS/iOSChatView.swift` | Chat tab — full-screen ChatPanelView |
| `AgentBoard/Views/iOS/iOSSessionsView.swift` | Sessions tab — session list + project picker |
| `AgentBoard/Views/iOS/iOSAgentsView.swift` | Agents tab — wraps existing AgentsView |
| `AgentBoard/Views/iOS/iOSMoreView.swift` | More tab — Settings, Notes, History, Milestones, Epics |
| `AgentBoard/Views/iOS/iOSSessionDetailView.swift` | Session detail with log viewer (replaces terminal) |
| `AgentBoard/AgentBoard-iOS-Info.plist` | iOS-specific Info.plist with ATS config |

---

## Task 1: Convert project.yml to multiPlatform

**Files:**
- Modify: `project.yml`

This is the foundation — everything else depends on this compiling.

- [ ] **Step 1: Update project.yml to multiPlatform target**

Replace the current single-platform target structure with XcodeGen's `multiPlatform` support. Key changes:
- Move `deploymentTarget` to include both macOS 15.0 and iOS 18.0
- Change target `platform` from `macOS` to `[macOS, iOS]` (or use `supportedDestinations`)
- Make SwiftTerm dependency macOS-only
- Add iOS-specific Info.plist
- Add iOS entitlements (sandbox off, local networking)
- Disable `ENABLE_APP_SANDBOX` for iOS too
- Add `UILaunchScreen` to iOS info properties

The XcodeGen `supportedDestinations` approach for a single target:

```yaml
name: AgentBoard
options:
  bundleIdPrefix: com.agentboard
  deploymentTarget:
    macOS: "15.0"
    iOS: "18.0"
  xcodeVersion: "16.2"
  createIntermediateGroups: true
  defaultConfig: Debug

settings:
  base:
    SWIFT_VERSION: "6.0"
    MACOSX_DEPLOYMENT_TARGET: "15.0"
    IPHONEOS_DEPLOYMENT_TARGET: "18.0"

packages:
  SwiftTerm:
    url: https://github.com/migueldeicaza/SwiftTerm
    from: "1.0.0"
  swift-markdown:
    url: https://github.com/apple/swift-markdown
    from: "0.4.0"

targets:
  AgentBoard:
    type: application
    supportedDestinations: [macOS, iOS]
    info:
      path: AgentBoard/AgentBoard-Info.plist
      properties:
        NSHumanReadableCopyright: "Copyright © 2026 Blake Crane. All rights reserved."
        NSAppTransportSecurity:
          NSAllowsLocalNetworking: true
        UILaunchScreen:
          UIColorName: ""
    preBuildScripts:
      - script: |
          if which swiftlint > /dev/null; then
            swiftlint lint
          else
            echo "warning: SwiftLint not installed — run: brew install swiftlint"
          fi
        name: SwiftLint
        inputFiles: []
        outputFiles: []
    sources:
      - path: AgentBoard
        excludes:
          - Resources/Preview Content
    resources:
      - path: AgentBoard/Resources/Assets.xcassets
      - path: AgentBoard/Resources/Preview Content
        buildPhase: none
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.agentboard.AgentBoard
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: 1
        SWIFT_STRICT_CONCURRENCY: complete
        SWIFT_VERSION: "6.0"
        ENABLE_APP_SANDBOX: NO
        CODE_SIGN_ENTITLEMENTS: AgentBoard/AgentBoard.entitlements
        CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION: YES
        DEVELOPMENT_ASSET_PATHS: "\"AgentBoard/Resources/Preview Content\""
        ENABLE_PREVIEWS: YES
        COMBINE_HIDPI_IMAGES: YES
        SUPPORTS_MACCATALYST: NO
      configs:
        Debug:
          SWIFT_OPTIMIZATION_LEVEL: "-Onone"
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: "DEBUG $(inherited)"
          CODE_SIGN_IDENTITY: "Apple Development"
          DEVELOPMENT_TEAM: "32XZRDTGK3"
        Release:
          SWIFT_COMPILATION_MODE: wholemodule
          CODE_SIGN_IDENTITY: "Apple Development"
          DEVELOPMENT_TEAM: "32XZRDTGK3"
    dependencies:
      - package: SwiftTerm
        platforms: [macOS]
      - package: swift-markdown
        product: Markdown
    entitlements:
      path: AgentBoard/AgentBoard.entitlements
  AgentBoardTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: AgentBoardTests
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        SWIFT_VERSION: "6.0"
    dependencies:
      - target: AgentBoard
  AgentBoardUITests:
    type: bundle.ui-testing
    platform: macOS
    sources:
      - path: AgentBoardUITests
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        SWIFT_VERSION: "6.0"
    dependencies:
      - target: AgentBoard

schemes:
  AgentBoard:
    build:
      targets:
        AgentBoard: all
        AgentBoardTests: [test]
        AgentBoardUITests: [test]
    test:
      gatherCoverageData: true
      coverageTargets:
        - AgentBoard
      targets:
        - name: AgentBoardTests
          parallelizable: true
          randomExecutionOrder: true
        - name: AgentBoardUITests
          parallelizable: true
          randomExecutionOrder: true
```

- [ ] **Step 2: Create iOS Views directory**

```bash
mkdir -p AgentBoard/Views/iOS
```

- [ ] **Step 3: Regenerate Xcode project and verify**

```bash
cd /Users/blake/Projects/AgentBoard && xcodegen generate
```

This will fail to build until platform guards are added in subsequent tasks — that's expected. The goal here is just that XcodeGen accepts the config.

- [ ] **Step 4: Commit**

```bash
git add project.yml
git commit -m "feat(GH-22): convert project.yml to multiPlatform (macOS + iOS 18)"
```

---

## Task 2: Platform-guard macOS-only utilities

**Files:**
- Modify: `AgentBoard/Utilities/ShellCommand.swift`
- Modify: `AgentBoard/Utilities/TerminalLauncher.swift`
- Modify: `AgentBoard/Utilities/AppTheme.swift`

These three files import macOS-only APIs. Guard them so iOS compiles.

- [ ] **Step 1: Guard ShellCommand.swift**

Wrap the `Process()`-using methods in `#if os(macOS)`. On iOS, provide stubs that throw an error so callers compile but never execute process-based commands:

```swift
import Foundation

struct ShellCommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        let parts = [stdout, stderr].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: "\n")
    }
}

enum ShellCommandError: LocalizedError {
    case executableNotFound
    case failed(ShellCommandResult)
    case unavailableOnPlatform

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Unable to find shell executable."
        case let .failed(result):
            return result.combinedOutput.isEmpty
                ? "Command failed with exit code \(result.exitCode)."
                : result.combinedOutput
        case .unavailableOnPlatform:
            return "Shell commands are not available on this platform."
        }
    }
}

enum ShellCommand {
    #if os(macOS)
    static func run(arguments: [String], workingDirectory: URL? = nil) throws -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        var env = ProcessInfo.processInfo.environment
        let basePath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/.claude/bin"
        ]
        env["PATH"] = (extraPaths + [basePath]).joined(separator: ":")
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ShellCommandError.executableNotFound
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let result = ShellCommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)

        guard result.exitCode == 0 else {
            throw ShellCommandError.failed(result)
        }

        return result
    }

    static func runAsync(arguments: [String], workingDirectory: URL? = nil) async throws -> ShellCommandResult {
        try await Task.detached(priority: .userInitiated) {
            try run(arguments: arguments, workingDirectory: workingDirectory)
        }.value
    }
    #else
    static func run(arguments: [String], workingDirectory: URL? = nil) throws -> ShellCommandResult {
        throw ShellCommandError.unavailableOnPlatform
    }

    static func runAsync(arguments: [String], workingDirectory: URL? = nil) async throws -> ShellCommandResult {
        throw ShellCommandError.unavailableOnPlatform
    }
    #endif
}
```

- [ ] **Step 2: Guard TerminalLauncher.swift**

Wrap entire file contents in `#if os(macOS)`:

```swift
#if os(macOS)
import Foundation
import AppKit

enum TerminalApp {
    // ... existing code unchanged ...
}

enum TerminalLauncher {
    // ... existing code unchanged ...
}
#endif
```

- [ ] **Step 3: Make AppTheme cross-platform**

Replace `import AppKit` + `NSColor` with cross-platform code. The static sidebar colors use fixed values (no dynamic provider needed). The dynamic colors use `NSColor(name:dynamicProvider:)` on macOS — on iOS, use `UIColor(dynamicProvider:)` with trait collection:

```swift
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum AppTheme {
    static let sidebarBackground = Color(
        red: 0.173, green: 0.173, blue: 0.18
    )
    static let sidebarMutedText = Color(
        red: 0.557, green: 0.557, blue: 0.576
    )
    static let sidebarPrimaryText = Color(
        red: 0.878, green: 0.878, blue: 0.878
    )

    static let appBackground = dynamicColor(
        lightRed: 0.961, lightGreen: 0.961, lightBlue: 0.941,
        darkRed: 0.11, darkGreen: 0.11, darkBlue: 0.12
    )
    static let panelBackground = dynamicColor(
        lightRed: 0.98, lightGreen: 0.98, lightBlue: 0.965,
        darkRed: 0.13, darkGreen: 0.13, darkBlue: 0.14
    )
    static let cardBackground = dynamicColor(
        lightRed: 1.0, lightGreen: 1.0, lightBlue: 1.0,
        darkRed: 0.173, darkGreen: 0.173, darkBlue: 0.18
    )
    static let subtleBorder = dynamicColor(
        lightRed: 0.886, lightGreen: 0.878, lightBlue: 0.847,
        darkRed: 0.3, darkGreen: 0.3, darkBlue: 0.32
    )
    static let mutedText = dynamicColor(
        lightRed: 0.35, lightGreen: 0.35, lightBlue: 0.38,
        darkRed: 0.72, darkGreen: 0.72, darkBlue: 0.75
    )

    static func sessionColor(for status: SessionStatus) -> Color {
        switch status {
        case .running:
            return Color(red: 0.204, green: 0.78, blue: 0.349)
        case .idle:
            return Color(red: 0.91, green: 0.663, blue: 0)
        case .stopped:
            return Color(red: 0.557, green: 0.557, blue: 0.576)
        case .error:
            return Color(red: 1.0, green: 0.231, blue: 0.188)
        }
    }

    struct CardStyle: ViewModifier {
        var cornerRadius: CGFloat = 10

        func body(content: Content) -> some View {
            content
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppTheme.subtleBorder, lineWidth: 1)
                )
        }
    }

    private static func dynamicColor(
        lightRed: Double, lightGreen: Double, lightBlue: Double,
        darkRed: Double, darkGreen: Double, darkBlue: Double
    ) -> Color {
        #if os(macOS)
        let nsColor = NSColor(
            name: nil,
            dynamicProvider: { appearance in
                let best = appearance.bestMatch(from: [.darkAqua, .aqua])
                if best == .darkAqua {
                    return NSColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: 1)
                }
                return NSColor(red: lightRed, green: lightGreen, blue: lightBlue, alpha: 1)
            }
        )
        return Color(nsColor: nsColor)
        #else
        let uiColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: 1)
            }
            return UIColor(red: lightRed, green: lightGreen, blue: lightBlue, alpha: 1)
        }
        return Color(uiColor: uiColor)
        #endif
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 10) -> some View {
        modifier(AppTheme.CardStyle(cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add AgentBoard/Utilities/ShellCommand.swift AgentBoard/Utilities/TerminalLauncher.swift AgentBoard/Utilities/AppTheme.swift
git commit -m "feat(GH-22): platform-guard macOS-only utilities for iOS compilation"
```

---

## Task 3: Platform-guard macOS-only views

**Files:**
- Modify: `AgentBoard/Views/Terminal/InteractiveTerminalView.swift`
- Modify: `AgentBoard/Views/Terminal/TerminalView.swift`
- Modify: `AgentBoard/Views/MainWindow/ContentView.swift`
- Modify: `AgentBoard/Views/RightPanel/RightPanelView.swift`
- Modify: `AgentBoard/Views/Canvas/CanvasPanelView.swift`
- Modify: `AgentBoard/Views/Board/TaskDetailSheet.swift`
- Modify: `AgentBoard/Views/Settings/PairingGuideView.swift`

- [ ] **Step 1: Guard InteractiveTerminalView.swift**

Wrap entire file in `#if os(macOS)`:

```swift
#if os(macOS)
import SwiftTerm
import SwiftUI

struct InteractiveTerminalView: NSViewRepresentable {
    // ... entire existing code unchanged ...
}
#endif
```

- [ ] **Step 2: Guard TerminalView.swift**

Wrap entire file in `#if os(macOS)` (it depends on InteractiveTerminalView):

```swift
#if os(macOS)
import SwiftUI

struct TerminalView: View {
    // ... entire existing code unchanged ...
}
#endif
```

- [ ] **Step 3: Guard ContentView.swift NSCursor usage**

ContentView uses `NSCursor.resizeLeftRight.push()` and `NSCursor.pop()` in the divider `.onHover`. Wrap the onHover block:

Replace the `.onHover` in `rightPanelDivider`:
```swift
        .onHover { inside in
            #if os(macOS)
            if inside {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
```

Also, ContentView references `TerminalView` in `centerPanel`. Guard that reference:

```swift
    private var centerPanel: some View {
        Group {
            if appState.sidebarNavSelection == .settings {
                SettingsView()
            }
            #if os(macOS)
            else if let activeSession = appState.activeSession {
                TerminalView(session: activeSession)
            }
            #endif
            else {
                VStack(spacing: 0) {
                    if let project = appState.selectedProject {
                        ProjectHeaderView(project: project)
                    }
                    tabBar
                    tabContent
                }
            }
        }
        .background(AppTheme.appBackground)
    }
```

Note: ContentView itself is macOS-only (3-panel layout) but will still compile for iOS since it contains no macOS-only imports at the top level. The iOS app won't use it — it uses `iOSRootView` instead. But it needs to compile. If there are other compilation issues, wrap the entire file in `#if os(macOS)`.

- [ ] **Step 4: Guard RightPanelView.swift NSApplication usage**

The `NSApplication.shared.keyWindow` block is in the sidebar toggle button action. Wrap it:

```swift
                    // Resize window to fit when expanding panels
                    if !wasShowing {
                        #if os(macOS)
                        Task { @MainActor in
                            if let window = NSApplication.shared.keyWindow {
                                let neededWidth: CGFloat = 1280
                                if window.frame.width < neededWidth {
                                    var frame = window.frame
                                    let delta = neededWidth - frame.width
                                    frame.size.width = neededWidth
                                    frame.origin.x -= delta / 2
                                    if let screen = window.screen {
                                        frame.origin.x = max(frame.origin.x, screen.visibleFrame.minX)
                                        if frame.maxX > screen.visibleFrame.maxX {
                                            frame.origin.x = screen.visibleFrame.maxX - frame.width
                                        }
                                    }
                                    window.setFrame(frame, display: true, animate: true)
                                }
                            }
                        }
                        #endif
                    }
```

- [ ] **Step 5: Guard CanvasPanelView.swift macOS APIs**

This file has three macOS-specific areas:
1. `NSPasteboard` in `pasteImageFromClipboard()`
2. `NSImage`/`NSBitmapImageRep` in `persistImageToTemporaryLocation()`
3. `NSSavePanel` in `exportCanvasContent()`
4. `CanvasWebView` using `NSViewRepresentable`

For the paste/export functions, provide iOS alternatives:

```swift
// At top of file, replace:
// import AppKit
// with:
#if os(macOS)
import AppKit
#else
import UIKit
#endif
```

Guard `pasteImageFromClipboard()`:
```swift
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
```

Guard `persistImageToTemporaryLocation` (macOS only — iOS path is inline above):
```swift
    #if os(macOS)
    private func persistImageToTemporaryLocation(_ image: NSImage) -> URL? {
        // ... existing code unchanged ...
    }
    #endif
```

Guard `exportCanvasContent()` — on iOS, use share sheet instead of NSSavePanel:
```swift
    private func exportCanvasContent() {
        guard let content = appState.currentCanvasContent else { return }
        #if os(macOS)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultExportFilename(for: content)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            // ... existing switch/write code unchanged ...
            appState.statusMessage = "Exported canvas content."
        } catch {
            appState.errorMessage = error.localizedDescription
        }
        #else
        // On iOS, export is not yet implemented — canvas is read-only for v1
        #endif
    }
```

Make `CanvasWebView` cross-platform:
```swift
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
            self.lastRenderedID = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
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
            self.lastRenderedID = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }
    }
}
#endif
```

- [ ] **Step 6: Guard TaskDetailSheet.swift NSPasteboard usage**

The `attachFromClipboard()` method uses `NSPasteboard`, `NSImage`, `NSBitmapImageRep`. Wrap it:

```swift
    private func attachFromClipboard() {
        #if os(macOS)
        guard let pasteboard = NSPasteboard.general.pasteboardItems?.first else { return }
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for imageType in imageTypes {
            if let data = pasteboard.data(forType: imageType) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("clipboard-\(Int(Date().timeIntervalSince1970)).png")
                do {
                    let pngData: Data
                    if imageType == .tiff, let image = NSImage(data: data),
                       let tiffRep = image.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffRep),
                       let converted = bitmapRep.representation(using: .png, properties: [:]) {
                        pngData = converted
                    } else {
                        pngData = data
                    }
                    try pngData.write(to: tempURL)
                    attachFile(tempURL)
                } catch {
                    appState.setError("Failed to read clipboard: \(error.localizedDescription)")
                }
                return
            }
        }
        #else
        guard let image = UIPasteboard.general.image,
              let data = image.pngData() else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: tempURL)
            attachFile(tempURL)
        } catch {
            appState.setError("Failed to read clipboard: \(error.localizedDescription)")
        }
        #endif
    }
```

Also need to add the import at the top of TaskDetailSheet.swift — check if it imports AppKit. If not, the NSPasteboard types are accessed through Foundation/AppKit auto-import. Add explicit conditional import:
```swift
#if os(macOS)
import AppKit
#else
import UIKit
#endif
```

- [ ] **Step 7: Guard PairingGuideView.swift NSPasteboard usage**

Replace `NSPasteboard.general` with cross-platform clipboard:

```swift
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(approveCommand, forType: .string)
                        #else
                        UIPasteboard.general.string = approveCommand
                        #endif
                    } label: {
```

Add import at top:
```swift
#if os(macOS)
import AppKit
#else
import UIKit
#endif
```

- [ ] **Step 8: Commit**

```bash
git add AgentBoard/Views/
git commit -m "feat(GH-22): platform-guard all macOS-only view code for iOS compilation"
```

---

## Task 4: Guard SessionMonitor for iOS

**Files:**
- Modify: `AgentBoard/Services/SessionMonitor.swift`

SessionMonitor uses `ShellCommand.run()` for tmux interaction — which uses `Process()`. The actor needs to compile on iOS but tmux operations only work on macOS.

- [ ] **Step 1: Guard tmux-dependent methods**

The entire actor body depends on tmux/process management. The cleanest approach: keep the actor shell compilable on iOS, but guard the method bodies:

At the top of the actor, wrap the tmux-dependent implementation methods with `#if os(macOS)` and provide empty/no-op stubs for iOS:

```swift
actor SessionMonitor {
    // ... existing properties ...

    #if os(macOS)
    // ... all existing method implementations unchanged ...
    #else
    func listSessions() async -> [CodingSession] { [] }
    func launchSession(/* same params */) async throws -> String {
        throw ShellCommandError.unavailableOnPlatform
    }
    func killSession(sessionID: String) async throws {
        throw ShellCommandError.unavailableOnPlatform
    }
    func capturePane(sessionID: String) async -> String? { nil }
    func sendNudge(sessionID: String) async throws {
        throw ShellCommandError.unavailableOnPlatform
    }
    #endif
}
```

The exact method signatures need to match what exists. Read the full SessionMonitor to get exact signatures. The key principle: on iOS, `listSessions()` returns empty, everything else throws.

- [ ] **Step 2: Commit**

```bash
git add AgentBoard/Services/SessionMonitor.swift
git commit -m "feat(GH-22): guard SessionMonitor tmux methods for iOS (no-op stubs)"
```

---

## Task 5: Guard AgentBoardApp.swift and create iOS root

**Files:**
- Modify: `AgentBoard/App/AgentBoardApp.swift`
- Create: `AgentBoard/Views/iOS/iOSRootView.swift`

- [ ] **Step 1: Platform-split AgentBoardApp.swift**

The macOS version uses `.defaultSize`, `.windowResizability`, and `.commands {}` — all unavailable on iOS. The iOS version shows `iOSRootView`:

```swift
import SwiftUI

@main
struct AgentBoardApp: App {
    @State private var appState = AgentBoardApp.makeInitialState()

    private static func makeInitialState() -> AppState {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting-dashboard-fixtures") {
            let state = AppState(bootstrapOnInit: false, startBackgroundLoops: false)
            state.applyDashboardUITestFixtures(empty: arguments.contains("--uitesting-dashboard-empty"))
            return state
        }
        return AppState()
    }

    var body: some Scene {
        WindowGroup("AgentBoard", content: {
            #if os(iOS)
            iOSRootView()
                .environment(appState)
            #else
            ContentView()
                .environment(appState)
                .preferredColorScheme(nil)
            #endif
        })
        #if os(macOS)
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Bead") {
                    appState.requestCreateBeadSheet()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Coding Session") {
                    appState.requestNewSessionSheet()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .sidebar) {
                Button(appState.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    appState.toggleSidebar()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }

            CommandGroup(after: .sidebar) {
                Button(appState.boardVisible ? "Hide Board" : "Show Board") {
                    appState.toggleBoard()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button(appState.isFocusMode ? "Exit Focus Mode" : "Focus Mode") {
                    appState.toggleFocusMode()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Refresh Beads") {
                    Task { await appState.refreshBeads() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandMenu("Navigate") {
                Button("Board") { appState.switchToTab(.board) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Epics") { appState.switchToTab(.epics) }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Agents") { appState.switchToTab(.agents) }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("History") { appState.switchToTab(.history) }
                    .keyboardShortcut("4", modifiers: [.command])
            }

            CommandMenu("Canvas") {
                Button("Canvas Back") { appState.goCanvasBack() }
                    .keyboardShortcut("[", modifiers: [.command])
                    .disabled(!appState.canGoCanvasBack)
                Button("Canvas Forward") { appState.goCanvasForward() }
                    .keyboardShortcut("]", modifiers: [.command])
                    .disabled(!appState.canGoCanvasForward)
            }

            CommandMenu("Chat") {
                Button("Focus Chat Input") { appState.requestChatInputFocus() }
                    .keyboardShortcut("l", modifiers: [.command])
            }
        }
        #endif
    }
}
```

- [ ] **Step 2: Create iOSRootView.swift**

```swift
#if os(iOS)
import SwiftUI

struct iOSRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            Tab("Board", systemImage: "square.grid.2x2") {
                iOSBoardView()
            }
            .accessibilityIdentifier("ios_tab_board")

            Tab("Chat", systemImage: "bubble.left.and.bubble.right") {
                iOSChatView()
            }
            .badge(appState.unreadChatCount)
            .accessibilityIdentifier("ios_tab_chat")

            Tab("Sessions", systemImage: "terminal") {
                iOSSessionsView()
            }
            .accessibilityIdentifier("ios_tab_sessions")

            Tab("Agents", systemImage: "cpu") {
                iOSAgentsView()
            }
            .accessibilityIdentifier("ios_tab_agents")

            Tab("More", systemImage: "ellipsis") {
                iOSMoreView()
            }
            .accessibilityIdentifier("ios_tab_more")
        }
    }
}
#endif
```

- [ ] **Step 3: Commit**

```bash
git add AgentBoard/App/AgentBoardApp.swift AgentBoard/Views/iOS/iOSRootView.swift
git commit -m "feat(GH-22): platform-split app entry point, add iOS 5-tab root view"
```

---

## Task 6: Create iOS tab views — Board, Chat, Sessions

**Files:**
- Create: `AgentBoard/Views/iOS/iOSBoardView.swift`
- Create: `AgentBoard/Views/iOS/iOSChatView.swift`
- Create: `AgentBoard/Views/iOS/iOSSessionsView.swift`
- Create: `AgentBoard/Views/iOS/iOSSessionDetailView.swift`

- [ ] **Step 1: Create iOSBoardView.swift**

Wraps the existing `BoardView` in a NavigationStack with project header and pull-to-refresh:

```swift
#if os(iOS)
import SwiftUI

struct iOSBoardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                if let project = appState.selectedProject {
                    ProjectHeaderView(project: project)
                }
                BoardView()
            }
            .refreshable {
                await appState.refreshBeads()
            }
            .navigationTitle("Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.requestCreateBeadSheet()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("ios_board_button_add")
                }
                ToolbarItem(placement: .topBarLeading) {
                    projectPicker
                }
            }
        }
    }

    private var projectPicker: some View {
        Menu {
            ForEach(appState.projects) { project in
                Button(project.name) {
                    appState.selectProject(project)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(appState.selectedProject?.name ?? "Projects")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
        }
        .accessibilityIdentifier("ios_board_menu_project")
    }
}
#endif
```

- [ ] **Step 2: Create iOSChatView.swift**

Full-screen chat wrapping the existing ChatPanelView:

```swift
#if os(iOS)
import SwiftUI

struct iOSChatView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ChatPanelView()
                .navigationTitle(appState.agentName ?? "Agent Chat")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appState.chatConnectionState.color)
                                .frame(width: 6, height: 6)
                            Text(appState.chatConnectionState.label)
                                .font(.system(size: 11))
                                .foregroundStyle(appState.chatConnectionState.color)
                        }
                    }
                }
        }
        .onAppear {
            appState.clearUnreadChatCount()
        }
    }
}
#endif
```

- [ ] **Step 3: Create iOSSessionsView.swift**

Session list showing active coding sessions. On iOS, tapping a session shows a detail view with session info (no terminal — replaced by log viewer):

```swift
#if os(iOS)
import SwiftUI

struct iOSSessionsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Group {
                if appState.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Active Sessions",
                        systemImage: "terminal",
                        description: Text("Sessions from your macOS gateway will appear here.")
                    )
                } else {
                    List(appState.sessions) { session in
                        NavigationLink(value: session) {
                            sessionRow(session)
                        }
                        .accessibilityIdentifier("ios_sessions_cell_\(session.id)")
                    }
                    .listStyle(.insetGrouped)
                    .navigationDestination(for: CodingSession.self) { session in
                        iOSSessionDetailView(session: session)
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await appState.refreshSessions()
            }
        }
    }

    private func sessionRow(_ session: CodingSession) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.sessionColor(for: session.status))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(session.agentType.rawValue)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let model = session.model, !model.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(model)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(session.status.rawValue.capitalized)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.sessionColor(for: session.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.sessionColor(for: session.status).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.vertical, 4)
    }
}
#endif
```

- [ ] **Step 4: Create iOSSessionDetailView.swift**

Detail view for a session — shows session info and a read-only pane capture log:

```swift
#if os(iOS)
import SwiftUI

struct iOSSessionDetailView: View {
    @Environment(AppState.self) private var appState
    let session: CodingSession

    @State private var paneOutput: String = ""
    @State private var isLoadingOutput = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sessionInfoSection
                Divider()
                logSection
            }
            .padding()
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nudge") {
                    Task<Void, Never> {
                        await appState.nudgeSession(sessionID: session.id)
                    }
                }
                .accessibilityIdentifier("ios_session_detail_button_nudge")
            }
        }
        .task {
            await loadPaneOutput()
        }
        .refreshable {
            await loadPaneOutput()
        }
    }

    private var sessionInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.sessionColor(for: session.status))
                    .frame(width: 10, height: 10)
                Text(session.status.rawValue.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.sessionColor(for: session.status))
            }

            LabeledContent("Agent", value: session.agentType.rawValue)
                .font(.system(size: 13))

            if let model = session.model, !model.isEmpty {
                LabeledContent("Model", value: model)
                    .font(.system(size: 13))
            }

            if let issueNumber = session.linkedIssueNumber {
                LabeledContent("Issue", value: "#\(issueNumber)")
                    .font(.system(size: 13))
            }

            LabeledContent("Elapsed", value: elapsedLabel)
                .font(.system(size: 13))
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session Output")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if isLoadingOutput {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    Task<Void, Never> { await loadPaneOutput() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .accessibilityIdentifier("ios_session_detail_button_refresh_log")
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(paneOutput.isEmpty ? "No output captured." : paneOutput)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(paneOutput.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func loadPaneOutput() async {
        isLoadingOutput = true
        if let output = await appState.captureSessionPane(sessionID: session.id) {
            paneOutput = output
        }
        isLoadingOutput = false
    }

    private var elapsedLabel: String {
        let elapsed = max(0, Int(session.elapsed))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
#endif
```

- [ ] **Step 5: Commit**

```bash
git add AgentBoard/Views/iOS/
git commit -m "feat(GH-22): add iOS Board, Chat, Sessions tab views with session detail"
```

---

## Task 7: Create iOS tab views — Agents and More

**Files:**
- Create: `AgentBoard/Views/iOS/iOSAgentsView.swift`
- Create: `AgentBoard/Views/iOS/iOSMoreView.swift`

- [ ] **Step 1: Create iOSAgentsView.swift**

Wraps the existing `AgentsView` in a NavigationStack:

```swift
#if os(iOS)
import SwiftUI

struct iOSAgentsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            AgentsView()
                .navigationTitle("Agents")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
```

- [ ] **Step 2: Create iOSMoreView.swift**

Navigation list linking to Settings, Notes, History, Milestones, Epics, and Ready Queue:

```swift
#if os(iOS)
import SwiftUI

struct iOSMoreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Views") {
                    NavigationLink {
                        EpicsView()
                            .navigationTitle("Epics")
                    } label: {
                        Label("Epics", systemImage: "flag")
                    }
                    .accessibilityIdentifier("ios_more_link_epics")

                    NavigationLink {
                        MilestonesView()
                            .navigationTitle("Milestones")
                    } label: {
                        Label("Milestones", systemImage: "star")
                    }
                    .accessibilityIdentifier("ios_more_link_milestones")

                    NavigationLink {
                        ReadyQueueView()
                            .navigationTitle("Ready Queue")
                    } label: {
                        Label("Ready Queue", systemImage: "tray.full")
                    }
                    .accessibilityIdentifier("ios_more_link_ready")

                    NavigationLink {
                        NotesView()
                            .navigationTitle("Notes")
                    } label: {
                        Label("Notes", systemImage: "note.text")
                    }
                    .accessibilityIdentifier("ios_more_link_notes")

                    NavigationLink {
                        HistoryView()
                            .navigationTitle("History")
                    } label: {
                        Label("History", systemImage: "clock")
                    }
                    .accessibilityIdentifier("ios_more_link_history")

                    NavigationLink {
                        AllProjectsBoardView()
                            .navigationTitle("All Projects")
                    } label: {
                        Label("All Projects", systemImage: "rectangle.stack")
                    }
                    .accessibilityIdentifier("ios_more_link_all_projects")
                }

                Section("App") {
                    NavigationLink {
                        SettingsView()
                            .navigationTitle("Settings")
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .accessibilityIdentifier("ios_more_link_settings")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
```

- [ ] **Step 3: Commit**

```bash
git add AgentBoard/Views/iOS/
git commit -m "feat(GH-22): add iOS Agents and More tab views"
```

---

## Task 8: Build verification and fix compilation errors

**Files:**
- Potentially any file from above that needs adjustments

- [ ] **Step 1: Regenerate Xcode project**

```bash
cd /Users/blake/Projects/AgentBoard && xcodegen generate
```

- [ ] **Step 2: Build for macOS (must still work)**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Build for iOS Simulator**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED (or compilation errors to fix iteratively)

- [ ] **Step 4: Fix any compilation errors**

Iterate on any errors. Common issues to watch for:
- Missing `#if os(macOS)` guards on types used only in guarded code
- `AppState` methods that reference macOS-only types in their signatures
- Views that implicitly depend on macOS-only views without guards
- `CodingSession` needing `Hashable` conformance for `NavigationLink(value:)`

- [ ] **Step 5: Run macOS tests to verify no regressions**

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && git pull && xcodebuild test -scheme AgentBoard -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:AgentBoardTests"
```

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "feat(GH-22): fix compilation for both macOS and iOS targets"
```

---

## Task 9: Push and close issue

- [ ] **Step 1: Push to remote**

```bash
git push
```

- [ ] **Step 2: Close GH-22**

```bash
gh issue close 22 --repo jbcrane13/AgentBoard --comment "iPhone port complete: multiPlatform target compiles for macOS 15+ and iOS 18+. 5-tab iOS layout (Board, Chat, Sessions, Agents, More) with session log viewer replacing terminal."
```
