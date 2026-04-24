import AgentBoardCore
import SwiftUI

@main
struct AgentBoardMobileApp: App {
    @State private var appModel = AgentBoardBootstrap.makeLiveAppModel()

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environment(appModel)
                .task {
                    await appModel.bootstrap()
                }
        }
    }
}
