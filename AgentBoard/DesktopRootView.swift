import AgentBoardCore
import SwiftUI

struct DesktopRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    var body: some View {
        NavigationSplitView {
            List(selection: Bindable(appModel).selectedDestination) {
                Section("Workspace") {
                    Label(AppDestination.chat.title, systemImage: AppDestination.chat.systemImage)
                        .tag(AppDestination.chat)
                    Label(AppDestination.work.title, systemImage: AppDestination.work.systemImage)
                        .tag(AppDestination.work)
                }

                Section("Runtime") {
                    Label(AppDestination.agents.title, systemImage: AppDestination.agents.systemImage)
                        .tag(AppDestination.agents)
                    Label(AppDestination.sessions.title, systemImage: AppDestination.sessions.systemImage)
                        .tag(AppDestination.sessions)
                }

                Section {
                    Label(AppDestination.settings.title, systemImage: AppDestination.settings.systemImage)
                        .tag(AppDestination.settings)
                }
            }
            .navigationTitle("AgentBoard")
            .scrollContentBackground(.hidden)
        } detail: {
            destinationView(for: appModel.selectedDestination)
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                connectionStatusChip
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appModel.refreshAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var connectionStatusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionDotColor)
                .frame(width: 8, height: 8)
            Text(appModel.chatStore.connectionState.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var connectionDotColor: Color {
        switch appModel.chatStore.connectionState {
        case .connected: BoardPalette.mint
        case .connecting, .reconnecting: BoardPalette.gold
        case .failed: BoardPalette.coral
        case .disconnected: BoardPalette.cobalt
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
