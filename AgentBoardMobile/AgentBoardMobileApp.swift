import AgentBoardCore
import OSLog
import SwiftUI

@main
struct AgentBoardMobileApp: App {
    private static let logger = Logger(subsystem: "com.agentboard.modern", category: "Bootstrap")
    @State private var appModel = AgentBoardBootstrap.makeLiveAppModel()

    init() {
        Self.logRuntimeConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environment(appModel)
                .task {
                    await appModel.bootstrap()
                }
        }
    }

    private static func logRuntimeConfiguration() {
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let executablePath = Bundle.main.executableURL?.path ?? "unknown"
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity")
            .map { "\($0)" } ?? "missing"

        logger.info("AgentBoardMobile runtime bundle=\(bundleID, privacy: .public) executable=\(executablePath, privacy: .public) ATS=\(ats, privacy: .public)")
    }
}
