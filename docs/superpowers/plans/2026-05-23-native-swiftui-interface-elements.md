# Native SwiftUI Interface Elements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the AgentBoard macOS and iOS app shells to native SwiftUI interface elements while keeping the existing Hermes-first screens and stores intact.

**Architecture:** Replace bespoke app chrome at the shell boundary, not the product data layer. macOS moves to `NavigationSplitView`, source-list `List` sections, toolbar actions, and an inspector chat panel; iOS keeps `TabView` and `NavigationStack` but removes UIKit tab-bar appearance overrides. Source-level Swift Testing coverage guards the intended native SwiftUI shell choices.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XcodeGen-managed Xcode project, GitHub Issues #97-#100.

---

## File Structure

- Modify: `AgentBoard/DesktopRootView.swift` - owns the macOS native split-view shell, toolbar actions, quick-launch sheet, terminal-detail routing, and chat inspector visibility.
- Modify: `AgentBoardUI/Components/DesktopSidebar.swift` - replaces the custom gradient sidebar with a native source-list `List(selection:)` organized into SwiftUI `Section`s.
- Modify: `AgentBoard/AgentBoardApp.swift` - removes custom title-bar hiding so the window keeps native macOS chrome.
- Modify: `AgentBoardMobile/MobileRootView.swift` - removes UIKit tab-bar appearance work and adds a tagged SwiftUI `TabView(selection:)`.
- Modify: `AgentBoardMobile/AgentBoardMobileApp.swift` - stops calling the removed UIKit appearance hook.
- Create: `AgentBoardTests/NativeSwiftUIInterfaceTests.swift` - source-level regression tests for the native shell contracts.
- Modify: `docs/ADR.md` - records the native SwiftUI shell decision.
- Modify: `AGENTS.md` - adds the session activity entry after the work lands.

## GitHub Tickets

- #97 Convert AgentBoard to native SwiftUI interface elements
- #98 Use native SwiftUI navigation for the macOS shell
- #99 Use native SwiftUI tab navigation for iOS
- #100 Guard native SwiftUI shell with tests and docs

### Task 1: Add Native Shell Regression Tests

**Files:**
- Create: `AgentBoardTests/NativeSwiftUIInterfaceTests.swift`

- [x] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing

struct NativeSwiftUIInterfaceTests {
    @Test func macShellUsesNativeSplitViewToolbarAndInspector() throws {
        let source = try Self.source("AgentBoard/DesktopRootView.swift")

        #expect(source.contains("NavigationSplitView"))
        #expect(source.contains(".toolbar"))
        #expect(source.contains(".inspector("))
        #expect(!source.contains("NeuBackground()"))
        #expect(!source.contains("isChatOnlyMode"))
    }

    @Test func desktopSidebarUsesNativeListSections() throws {
        let source = try Self.source("AgentBoardUI/Components/DesktopSidebar.swift")

        #expect(source.contains("List(selection:"))
        #expect(source.contains(".listStyle(.sidebar)"))
        #expect(source.contains("Section(\"Views\")"))
        #expect(source.contains("Section(\"Projects\")"))
        #expect(source.contains("Section(\"Live Sessions\")"))
        #expect(!source.contains("LinearGradient"))
        #expect(!source.contains("NeuPalette"))
    }

    @Test func iosRootUsesNativeTabViewWithoutUIKitAppearanceOverrides() throws {
        let rootSource = try Self.source("AgentBoardMobile/MobileRootView.swift")
        let appSource = try Self.source("AgentBoardMobile/AgentBoardMobileApp.swift")

        #expect(rootSource.contains("TabView(selection:"))
        #expect(rootSource.contains(".tag(AppDestination.chat)"))
        #expect(rootSource.contains(".tag(AppDestination.settings)"))
        #expect(!rootSource.contains("UITabBarAppearance"))
        #expect(!rootSource.contains("UITabBar.appearance()"))
        #expect(!appSource.contains("applyTabBarAppearance"))
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot.appending(path: relativePath), encoding: .utf8)
    }

    private static var repositoryRoot: URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appending(path: "project.yml").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }

        Issue.record("Unable to locate repository root from \\(#filePath)")
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }
}
```

- [x] **Step 2: Run the focused test and verify red**

Run:

```bash
xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' -only-testing:AgentBoardTests/NativeSwiftUIInterfaceTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the current desktop shell still uses custom chrome and the iOS root still contains `UITabBarAppearance`.

### Task 2: Convert The macOS Shell To Native SwiftUI Navigation

**Files:**
- Modify: `AgentBoard/DesktopRootView.swift`
- Modify: `AgentBoardUI/Components/DesktopSidebar.swift`
- Modify: `AgentBoard/AgentBoardApp.swift`

- [x] **Step 1: Implement the native macOS shell**

Replace the manual root `HStack`, hidden-titlebar behavior, and custom desktop sidebar with:

- `NavigationSplitView(columnVisibility:)` in `DesktopRootView`.
- `DesktopSidebar(selection:onSessionTap:onQuickLaunch:)` as the sidebar column.
- Detail content in the split-view detail column.
- `.toolbar` actions for quick launch and chat visibility.
- `.inspector(isPresented:)` hosting `ChatScreen`.
- Native `List(selection:)`, `Section`, `Label`, and `.badge` in `DesktopSidebar`.

- [x] **Step 2: Run the focused native shell test**

Run:

```bash
xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' -only-testing:AgentBoardTests/NativeSwiftUIInterfaceTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: macOS assertions pass; iOS root assertions still fail until Task 3.

### Task 3: Convert The iOS Shell To Native SwiftUI Tabs

**Files:**
- Modify: `AgentBoardMobile/MobileRootView.swift`
- Modify: `AgentBoardMobile/AgentBoardMobileApp.swift`

- [x] **Step 1: Remove UIKit tab-bar styling**

Delete `MobileRootView.applyTabBarAppearance(_:)`, remove the custom `init`, and stop calling that hook from `AgentBoardMobileApp.applyTheme(_:)`.

- [x] **Step 2: Add stable native tab selection**

Use `@State private var selectedDestination: AppDestination = .chat` and `TabView(selection: $selectedDestination)`, keeping each destination wrapped in its existing `NavigationStack`, `.tabItem`, `.tag(AppDestination.<case>)`, and accessibility identifier.

- [x] **Step 3: Run the focused native shell test**

Run:

```bash
xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' -only-testing:AgentBoardTests/NativeSwiftUIInterfaceTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

### Task 4: Document And Verify The Conversion

**Files:**
- Modify: `docs/ADR.md`
- Modify: `AGENTS.md`

- [x] **Step 1: Record the decision**

Add an ADR entry explaining that AgentBoard app shells use platform-native SwiftUI navigation controls and reserve custom visual styling for feature content.

- [x] **Step 2: Add activity context**

Add a 2026-05-23 activity entry to `AGENTS.md` with the issue numbers and summary of the native shell migration.

- [x] **Step 3: Run quality gates**

Run:

```bash
swiftlint lint --strict
xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoardMobile -destination 'generic/platform=iOS Simulator' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoardCompanion -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: all commands exit 0. If any Xcode command stalls without producing build output, record it as unverified rather than treating it as success.

- [ ] **Step 4: Commit, push, and update GitHub**

Run:

```bash
git status --short
git add AgentBoard/DesktopRootView.swift AgentBoard/AgentBoardApp.swift AgentBoardMobile/MobileRootView.swift AgentBoardMobile/AgentBoardMobileApp.swift AgentBoardUI/Components/DesktopSidebar.swift AgentBoardTests/NativeSwiftUIInterfaceTests.swift docs/ADR.md AGENTS.md docs/superpowers/plans/2026-05-23-native-swiftui-interface-elements.md
git commit -m "feat: use native SwiftUI app shells"
git push -u origin codex/native-swiftui-elements
```

Then close #98, #99, and #100 with verification notes, and update #97 with the branch and completion summary.
