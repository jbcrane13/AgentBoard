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
        #expect(rootSource.contains("Tab(value: AppDestination.chat)"))
        #expect(rootSource.contains("Tab(value: AppDestination.settings)"))
        #expect(rootSource.contains(".tabViewStyle(.sidebarAdaptable)"))
        #expect(!rootSource.contains(".tabItem"))
        #expect(!rootSource.contains(".tag(AppDestination"))
        #expect(!rootSource.contains("UITabBarAppearance"))
        #expect(!rootSource.contains("UITabBar.appearance()"))
        #expect(!appSource.contains("applyTabBarAppearance"))
    }

    @Test func cacheReplacesCollectionsWithoutDeleteAllWriteAmplification() throws {
        let source = try Self.source("AgentBoardCore/Persistence/AgentBoardCache.swift")

        #expect(source.contains("func update(from item: WorkItem"))
        #expect(source.contains("func update(from session: AgentSession"))
        #expect(source.contains("func update(from agent: AgentSummary"))
        #expect(!source.contains("replaceAll(CachedWorkItemRecord.self)"))
        #expect(!source.contains("replaceAll(CachedSessionRecord.self)"))
        #expect(!source.contains("replaceAll(CachedAgentRecord.self)"))
    }

    @Test func attachmentUploadRetainsProgressObservationUntilTaskCleanup() throws {
        let source = try Self.source("AgentBoardCore/Services/AttachmentUploadService.swift")

        #expect(source.contains("progressObservations: [Int: NSKeyValueObservation]"))
        #expect(source.contains("progressObservations[task.taskIdentifier] = observation"))
        #expect(source.contains("finishUpload(attachmentID:"))
        #expect(!source.contains("_ = observation"))
    }

    @Test func desktopTabSelectionUsesAppModelAsSingleSourceOfTruth() throws {
        let rootSource = try Self.source("AgentBoard/DesktopRootView.swift")
        let appModelSource = try Self.source("AgentBoardCore/Stores/AgentBoardAppModel.swift")

        #expect(appModelSource.contains("selectedDestination"))
        #expect(rootSource.contains("appModel.selectedDestination"))
        #expect(!rootSource.contains("activeTab"))
    }

    @Test func workBoardDragAndDropUsesTransferableAPI() throws {
        let source = try Self.source("AgentBoardUI/Screens/WorkScreen.swift")

        #expect(source.contains("Transferable"))
        #expect(source.contains(".draggable(WorkItemID(item.id))"))
        #expect(source.contains(".dropDestination(for: WorkItemID.self)"))
        #expect(!source.contains("WorkColumnDropDelegate"))
        #expect(!source.contains("loadItem(forTypeIdentifier:"))
    }

    @Test func workBoardPersistsSelectedRepositoryAndSeedsCreateIssueSheet() throws {
        let workSource = try Self.source("AgentBoardUI/Screens/WorkScreen.swift")
        let createSource = try Self.source("AgentBoardUI/Screens/CreateIssueSheet.swift")

        #expect(workSource.contains(#"@SceneStorage("work.selectedRepository")"#))
        #expect(workSource.contains("CreateIssueSheet(initialRepository: selectedCreateRepository)"))
        #expect(workSource.contains("private var selectedCreateRepository: ConfiguredRepository?"))
        #expect(createSource.contains("init(initialRepository: ConfiguredRepository? = nil)"))
        #expect(createSource.contains("_selectedRepository = State(initialValue: initialRepository)"))
    }

    @Test func launchedSessionsOpenTerminalInDesktopShell() throws {
        let source = try Self.source("AgentBoard/DesktopRootView.swift")

        #expect(source.contains("onChange(of: appModel.sessionLauncher.activeSessions.map(\\.id))"))
        #expect(source.contains("activeSessionTerminal = session"))
    }

    @Test func companionSessionDetailOffersTerminalWhenTmuxSessionExists() throws {
        let source = try Self.source("AgentBoardUI/Screens/SessionDetailSheet.swift")

        #expect(source.contains("session.tmuxSession"))
        #expect(source.contains(#"Text("Terminal").tag(2)"#))
        #expect(source.contains("SessionLauncher.attachCommand(for: tmuxSession)"))
        #expect(source.contains("EmbeddedTerminalView("))
    }

    @Test func nilIfEmptyHasSingleSharedDefinition() throws {
        let coreURL = Self.repositoryRoot.appending(path: "AgentBoardCore")
        let fileURLs = try FileManager.default.subpathsOfDirectory(atPath: coreURL.path)
            .filter { $0.hasSuffix(".swift") }
            .map { coreURL.appending(path: $0) }
        let sources = try fileURLs.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")

        #expect(sources.components(separatedBy: "var nilIfEmpty: String?").count - 1 == 1)
    }

    @Test func chatStoreDelegatesLargeResponsibilitiesToCoordinators() throws {
        let source = try Self.source("AgentBoardCore/Stores/ChatStore.swift")
        let lineCount = source.split(separator: "\n").count

        #expect(lineCount < 300)
        #expect(!source.contains("swiftlint:disable file_length"))
        #expect(!source.contains("type_body_length"))
        #expect(source.contains("ChatEndpointValidator"))
        #expect(source.contains("ChatConversationSyncCoordinator"))
        #expect(source.contains("ChatStreamCoordinator"))
    }

    @Test func chatScreenIsSplitIntoFocusedSubviews() throws {
        let source = try Self.source("AgentBoardUI/Screens/ChatScreen.swift")
        let composeSource = try Self.source("AgentBoardUI/Screens/ChatComposeBar.swift")
        let messageListSource = try Self.source("AgentBoardUI/Screens/ChatMessageList.swift")

        #expect(source.split(separator: "\n").count < 250)
        #expect(!source.contains("swiftlint:disable"))
        #expect(!source.contains(".onReceive("))
        #expect(source.contains("notifications("))
        #expect(composeSource.contains("@ViewBuilder"))
        #expect(!composeSource.contains("AnyView"))
        #expect(messageListSource.contains(".scrollPosition(id:"))
        #expect(messageListSource.contains(".defaultScrollAnchor(.bottom)"))
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
