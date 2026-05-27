import AgentBoardCore
import Foundation
import Testing

struct LifeOpsInterfaceTests {
    @Test func appDestinationExposesLifeOpsInDesktopTabs() {
        #expect(AppDestination.allCases.contains(.lifeOps))
        #expect(AppDestination.desktopTabs.contains(.lifeOps))
        #expect(AppDestination.lifeOps.title == "LifeOps")
        #expect(!AppDestination.lifeOps.systemImage.isEmpty)
    }

    @Test func appModelOwnsFixtureBackedLifeOpsStore() throws {
        let source = try Self.source("AgentBoardCore/Stores/AgentBoardAppModel.swift")

        #expect(source.contains("public let lifeOpsStore: LifeOpsStore"))
        #expect(source.contains("let lifeOpsStore = LifeOpsStore()"))
        #expect(source.contains("lifeOpsStore: lifeOpsStore"))
    }

    @Test func macShellRoutesLifeOpsToSharedScreen() throws {
        let source = try Self.source("AgentBoard/DesktopRootView.swift")

        #expect(source.contains("case .lifeOps:"))
        #expect(source.contains("LifeOpsScreen(store: appModel.lifeOpsStore, mode: .dashboard)"))
    }

    @Test func mobileShellIncludesLifeOpsTab() throws {
        let source = try Self.source("AgentBoardMobile/MobileRootView.swift")

        #expect(source.contains("Tab(value: AppDestination.lifeOps)"))
        #expect(source.contains("LifeOpsScreen(store: appModel.lifeOpsStore, mode: .compact)"))
        #expect(source.contains(#".accessibilityIdentifier("mobile_tab_lifeOps")"#))
    }

    @Test func lifeOpsScreenExposesSectionAccessibilityContracts() throws {
        let source = try Self.source("AgentBoardUI/Screens/LifeOpsScreen.swift")

        #expect(source.contains(#".accessibilityIdentifier("screen_lifeops")"#))
        #expect(source.contains(#""lifeops.section.now""#))
        #expect(source.contains(#""lifeops.section.today""#))
        #expect(source.contains(#""lifeops.section.approvals""#))
        #expect(source.contains(#""lifeops.section.family""#))
        #expect(source.contains(#""lifeops.section.jobSearch""#))
        #expect(source.contains("Array(store.nowTasks.prefix(3))"))
    }

    @Test func lifeOpsComponentsExposeInteractiveAccessibilityIdentifiers() throws {
        let priority = try Self.source("AgentBoardUI/Components/LifeOpsPriorityBadge.swift")
        let row = try Self.source("AgentBoardUI/Components/LifeOpsTaskRow.swift")
        let capture = try Self.source("AgentBoardUI/Components/LifeOpsQuickCaptureView.swift")

        #expect(priority.contains(#".accessibilityIdentifier("lifeops.priority.badge")"#))
        #expect(row.contains(#".accessibilityIdentifier("lifeops.task.row")"#))
        #expect(capture.contains(#".accessibilityIdentifier("lifeops.quickCapture.field")"#))
        #expect(capture.contains(#".accessibilityIdentifier("lifeops.quickCapture.submit")"#))
    }

    @MainActor
    @Test func lifeOpsScreenIsStoreBackedAndFixtureRenderable() throws {
        let source = try Self.source("AgentBoardUI/Screens/LifeOpsScreen.swift")
        let fixtures = LifeOpsFixtures.makeSeedData()
        let store = LifeOpsStore(seedData: fixtures)

        #expect(source.contains("let store: LifeOpsStore"))
        #expect(!store.nowTasks.isEmpty)
        #expect(!store.pendingApprovals.isEmpty)
        #expect(!store.familyTasks.isEmpty)
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
