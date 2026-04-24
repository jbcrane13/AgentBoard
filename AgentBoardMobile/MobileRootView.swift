import AgentBoardCore
import SwiftUI

struct MobileRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.14, green: 0.15, blue: 0.21, alpha: 1.0)

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(red: 0.44, green: 0.46, blue: 0.56, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(
            red: 0.44,
            green: 0.46,
            blue: 0.56,
            alpha: 1.0
        )]

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.16, green: 0.77, blue: 0.82, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(
            red: 0.16,
            green: 0.77,
            blue: 0.82,
            alpha: 1.0
        )]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            NavigationStack {
                ChatScreen()
            }
            .tabItem {
                Label(AppDestination.chat.title, systemImage: AppDestination.chat.systemImage)
            }

            NavigationStack {
                WorkScreen()
            }
            .tabItem {
                Label(AppDestination.work.title, systemImage: AppDestination.work.systemImage)
            }

            NavigationStack {
                AgentsScreen()
            }
            .tabItem {
                Label(AppDestination.agents.title, systemImage: AppDestination.agents.systemImage)
            }

            NavigationStack {
                SessionsScreen()
            }
            .tabItem {
                Label(AppDestination.sessions.title, systemImage: AppDestination.sessions.systemImage)
            }

            NavigationStack {
                SettingsScreen()
            }
            .tabItem {
                Label(AppDestination.settings.title, systemImage: AppDestination.settings.systemImage)
            }
        }
        .tint(NeuPalette.accentCyan)
    }
}
