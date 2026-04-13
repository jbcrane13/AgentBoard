#if os(iOS)
    import SwiftUI

    struct iOSRootView: View {
        @Environment(AppState.self) private var appState

        var body: some View {
            TabView {
                Tab("Board", systemImage: "square.grid.2x2") {
                    iOSBoardView()
                }
                .accessibilityIdentifier("ios_tab_board")

                Tab("Chat", systemImage: "bubble.left.and.bubble.right") {
                    iOSChatView()
                }
                .badge(appState.unreadChatCount)
                .accessibilityIdentifier("ios_tab_chat")

                Tab("Sessions", systemImage: "terminal") {
                    iOSSessionsView()
                }
                .accessibilityIdentifier("ios_tab_sessions")

                Tab("Tasks", systemImage: "checklist") {
                    IOSTasksView()
                }
                .accessibilityIdentifier("ios_tab_tasks")

                Tab("Agents", systemImage: "cpu") {
                    iOSAgentsView()
                }
                .accessibilityIdentifier("ios_tab_agents")

                Tab("More", systemImage: "ellipsis") {
                    iOSMoreView()
                }
                .accessibilityIdentifier("ios_tab_more")
            }
        }
    }

    // swiftlint:disable:next type_name
    struct IOSTasksView: View {
        var body: some View {
            NavigationStack {
                AgentBoardDailyView()
                    .navigationTitle("Tasks")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
#endif
