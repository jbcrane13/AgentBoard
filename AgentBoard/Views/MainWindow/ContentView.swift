import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 220)
        } detail: {
            HSplitView {
                centerPanel
                    .frame(minWidth: 400)

                RightPanelView()
                    .frame(minWidth: 280, idealWidth: 340, maxWidth: 500)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group.bubble.left.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("AgentBoard")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private var centerPanel: some View {
        VStack(spacing: 0) {
            if let project = appState.selectedProject {
                ProjectHeaderView(project: project)
            }

            tabBar

            tabContent
        }
        .background(Color(red: 0.961, green: 0.961, blue: 0.941))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CenterTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color(red: 0.961, green: 0.961, blue: 0.941))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func tabButton(_ tab: CenterTab) -> some View {
        Button(action: { appState.selectedTab = tab }) {
            Text(tab.rawValue)
                .font(.system(size: 13, weight: appState.selectedTab == tab ? .semibold : .medium))
                .foregroundStyle(appState.selectedTab == tab
                                 ? Color(red: 0.1, green: 0.1, blue: 0.1)
                                 : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if appState.selectedTab == tab {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appState.selectedTab {
        case .board:
            BoardView()
        case .epics:
            EpicsView()
        case .agents:
            AgentsView()
        case .history:
            HistoryView()
        }
    }
}
