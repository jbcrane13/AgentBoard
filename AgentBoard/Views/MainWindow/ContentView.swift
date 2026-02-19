import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            if appState.sidebarVisible {
                SidebarView()
                    .frame(width: 220)
                    .transition(.move(edge: .leading))
            }

            if appState.boardVisible {
                if appState.sidebarVisible {
                    Divider()
                }
                centerPanel
                    .frame(minWidth: 400, maxWidth: .infinity)
                    .transition(.move(edge: .leading))
            }

            Divider()

            RightPanelView()
                .frame(width: 380)
        }
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: appState.sidebarVisible)
        .animation(.easeInOut(duration: 0.25), value: appState.boardVisible)
        .frame(minWidth: minWindowWidth, minHeight: 600)
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
        .overlay(alignment: .top) {
            connectionErrorToast
        }
    }

    // MARK: - Connection Error Toast

    @ViewBuilder
    private var connectionErrorToast: some View {
        if appState.showConnectionErrorToast, let error = appState.connectionErrorDetail {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                Text(error.userMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        appState.dismissConnectionErrorToast()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(error.indicatorColor, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: appState.showConnectionErrorToast)
        }
    }

    private var minWindowWidth: CGFloat {
        var width: CGFloat = 380
        if appState.sidebarVisible { width += 220 }
        if appState.boardVisible { width += 400 }
        return max(width, 400)
    }

    private var centerPanel: some View {
        Group {
            if appState.sidebarNavSelection == .settings {
                SettingsView()
            } else if let activeSession = appState.activeSession {
                TerminalView(session: activeSession)
            } else {
                VStack(spacing: 0) {
                    if let project = appState.selectedProject {
                        ProjectHeaderView(project: project)
                    }

                    tabBar

                    tabContent
                }
            }
        }
        .background(AppTheme.appBackground)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CenterTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(AppTheme.appBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func tabButton(_ tab: CenterTab) -> some View {
        Button(action: {
            appState.switchToTab(tab)
        }) {
            Text(tab.rawValue)
                .font(.system(size: 13, weight: appState.selectedTab == tab ? .semibold : .medium))
                .foregroundStyle(appState.selectedTab == tab
                                 ? Color.primary
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
