import AgentBoardCore
import SwiftUI

struct MobileRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    init() {
        Self.applyTabBarAppearance(.blue)
    }

    static func applyTabBarAppearance(_ designTheme: AgentBoardDesignTheme) {
        let backgroundColor: UIColor
        let selectedColor: UIColor
        switch designTheme {
        case .blue:
            backgroundColor = UIColor(red: 0.086, green: 0.110, blue: 0.153, alpha: 1.0)
            selectedColor = UIColor(red: 0.310, green: 0.851, blue: 0.773, alpha: 1.0)
        case .grey:
            backgroundColor = UIColor(red: 0.169, green: 0.180, blue: 0.196, alpha: 1.0)
            selectedColor = UIColor(red: 0.910, green: 0.647, blue: 0.455, alpha: 1.0)
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(red: 0.494, green: 0.522, blue: 0.584, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(
            red: 0.494,
            green: 0.522,
            blue: 0.584,
            alpha: 1.0
        )]

        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

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
