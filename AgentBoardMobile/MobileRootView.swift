import AgentBoardCore
import SwiftUI

struct MobileRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        TabView(selection: $appModel.selectedDestination) {
            Tab(value: AppDestination.dashboard) {
                NavigationStack {
                    DashboardScreen()
                        .navigationTitle(AppDestination.dashboard.title)
                }
                .accessibilityIdentifier("mobile_tab_dashboard")
            } label: {
                Label(AppDestination.dashboard.title, systemImage: AppDestination.dashboard.systemImage)
            }

            Tab(value: AppDestination.chat) {
                NavigationStack {
                    ChatScreen()
                        .navigationTitle(AppDestination.chat.title)
                }
                .accessibilityIdentifier("mobile_tab_chat")
            } label: {
                Label(AppDestination.chat.title, systemImage: AppDestination.chat.systemImage)
            }

            Tab(value: AppDestination.work) {
                NavigationStack {
                    WorkScreen()
                        .navigationTitle(AppDestination.work.title)
                }
                .accessibilityIdentifier("mobile_tab_work")
            } label: {
                Label(AppDestination.work.title, systemImage: AppDestination.work.systemImage)
            }

            Tab(value: AppDestination.agents) {
                NavigationStack {
                    AgentsScreen()
                        .navigationTitle(AppDestination.agents.title)
                }
                .accessibilityIdentifier("mobile_tab_agents")
            } label: {
                Label(AppDestination.agents.title, systemImage: AppDestination.agents.systemImage)
            }

            Tab(value: AppDestination.sessions) {
                NavigationStack {
                    SessionsScreen()
                        .navigationTitle(AppDestination.sessions.title)
                }
                .accessibilityIdentifier("mobile_tab_sessions")
            } label: {
                Label(AppDestination.sessions.title, systemImage: AppDestination.sessions.systemImage)
            }

            Tab(value: AppDestination.settings) {
                NavigationStack {
                    SettingsScreen()
                        .navigationTitle(AppDestination.settings.title)
                }
                .accessibilityIdentifier("mobile_tab_settings")
            } label: {
                Label(AppDestination.settings.title, systemImage: AppDestination.settings.systemImage)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.accentColor)
        .accessibilityIdentifier("screen_mobileRoot")
    }
}
