import AgentBoardCore
import OSLog
import SwiftUI

@main
struct AgentBoardApp: App {
    private static let logger = Logger(subsystem: "com.agentboard.modern", category: "Bootstrap")
    @State private var appModel = AgentBoardBootstrap.makeLiveAppModel()
    @State private var appliedTheme: AgentBoardDesignTheme = .blue

    init() {
        Self.logRuntimeConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            DesktopRootView()
                .id(appliedTheme)
                .environment(appModel)
                .onAppear {
                    applyTheme(appModel.settingsStore.designTheme)
                    hideTitleBar()
                }
                .onChange(of: appModel.settingsStore.designTheme) {
                    applyTheme(appModel.settingsStore.designTheme)
                }
                .task {
                    await appModel.bootstrap()
                    applyTheme(appModel.settingsStore.designTheme)
                }
        }
        .defaultSize(width: 1440, height: 920)
    }

    private func applyTheme(_ designTheme: AgentBoardDesignTheme) {
        NeuPalette.apply(designTheme)
        appliedTheme = designTheme
    }

    #if os(macOS)
        private func hideTitleBar() {
            guard let window = NSApplication.shared.windows.first else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
        }
    #endif

    private static func logRuntimeConfiguration() {
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let executablePath = Bundle.main.executableURL?.path ?? "unknown"
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity")
            .map { "\($0)" } ?? "missing"

        logger
            .info(
                "AgentBoard runtime bundle=\(bundleID, privacy: .public) executable=\(executablePath, privacy: .public) ATS=\(ats, privacy: .public)"
            )
    }
}
