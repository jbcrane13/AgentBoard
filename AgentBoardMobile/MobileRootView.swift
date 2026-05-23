import AgentBoardCore
import SwiftUI

struct MobileRootView: View {
    @State private var selectedDestination: AppDestination = .chat

    var body: some View {
        TabView(selection: $selectedDestination) {
            NavigationStack {
                ChatScreen()
                    .navigationTitle(AppDestination.chat.title)
            }
            .tabItem {
                Label(AppDestination.chat.title, systemImage: AppDestination.chat.systemImage)
            }
            .tag(AppDestination.chat)
            .accessibilityIdentifier("mobile_tab_chat")

            NavigationStack {
                WorkScreen()
                    .navigationTitle(AppDestination.work.title)
            }
            .tabItem {
                Label(AppDestination.work.title, systemImage: AppDestination.work.systemImage)
            }
            .tag(AppDestination.work)
            .accessibilityIdentifier("mobile_tab_work")

            NavigationStack {
                AgentsScreen()
                    .navigationTitle(AppDestination.agents.title)
            }
            .tabItem {
                Label(AppDestination.agents.title, systemImage: AppDestination.agents.systemImage)
            }
            .tag(AppDestination.agents)
            .accessibilityIdentifier("mobile_tab_agents")

            NavigationStack {
                SessionsScreen()
                    .navigationTitle(AppDestination.sessions.title)
            }
            .tabItem {
                Label(AppDestination.sessions.title, systemImage: AppDestination.sessions.systemImage)
            }
            .tag(AppDestination.sessions)
            .accessibilityIdentifier("mobile_tab_sessions")

            NavigationStack {
                SettingsScreen()
                    .navigationTitle(AppDestination.settings.title)
            }
            .tabItem {
                Label(AppDestination.settings.title, systemImage: AppDestination.settings.systemImage)
            }
            .tag(AppDestination.settings)
            .accessibilityIdentifier("mobile_tab_settings")
        }
        .tint(.accentColor)
        .accessibilityIdentifier("screen_mobileRoot")
    }
}
