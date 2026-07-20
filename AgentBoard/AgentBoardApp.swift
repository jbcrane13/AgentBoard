import AgentBoardCore
import OSLog
import SwiftUI

@main
struct AgentBoardApp: App {
    private static let logger = Logger(subsystem: "com.agentboard.modern", category: "Bootstrap")
    @State private var appModel = AgentBoardBootstrap.makeLiveAppModel()
    @State private var audioPlaybackService = AudioPlaybackService()

    init() {
        Self.logRuntimeConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            DesktopRootView()
                .environment(appModel)
                .environment(audioPlaybackService)
                .task {
                    await appModel.bootstrap()
                }
        }
        .defaultSize(width: 1440, height: 920)
    }

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
