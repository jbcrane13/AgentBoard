import SwiftUI

@main
struct AgentBoardApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("AgentBoard") {
            ContentView()
                .environment(appState)
        }
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentSize)
    }
}
