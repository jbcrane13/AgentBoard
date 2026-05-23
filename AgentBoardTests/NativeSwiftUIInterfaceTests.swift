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

        Issue.record("Unable to locate repository root from \(#filePath)")
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }
}
