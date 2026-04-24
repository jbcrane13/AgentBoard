import AgentBoardCore
import SwiftUI

struct DesktopRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    var body: some View {
        NavigationSplitView {
            List(AppDestination.allCases, selection: Bindable(appModel).selectedDestination) { destination in
                Label(destination.title, systemImage: destination.systemImage)
                    .tag(destination)
            }
            .navigationTitle("AgentBoard")
            .scrollContentBackground(.hidden)
        } detail: {
            destinationView(for: appModel.selectedDestination)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appModel.refreshAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .chat:
            ChatScreen()
        case .work:
            WorkScreen()
        case .agents:
            AgentsScreen()
        case .sessions:
            SessionsScreen()
        case .settings:
            SettingsScreen()
        }
    }
}
