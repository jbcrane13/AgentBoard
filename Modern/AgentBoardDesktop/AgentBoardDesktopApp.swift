import AgentBoardCore
import SwiftUI

@main
struct AgentBoardDesktopApp: App {
    @State private var appModel = AgentBoardBootstrap.makeLiveAppModel()

    var body: some Scene {
        WindowGroup {
            DesktopRootView()
                .environment(appModel)
                .task {
                    await appModel.bootstrap()
                }
        }
        .defaultSize(width: 1440, height: 920)
    }
}
