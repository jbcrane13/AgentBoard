import AgentBoardCore
import SwiftUI

private enum DesktopTab: String, CaseIterable, Identifiable {
    case work
    case agents
    case sessions
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .work: "Work"
        case .agents: "Agents"
        case .sessions: "Sessions"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .work: "square.grid.2x2"
        case .agents: "person.3.sequence"
        case .sessions: "bolt.horizontal.circle"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct DesktopRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var activeTab: DesktopTab? = .work
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 196, ideal: 220, max: 260)
        } content: {
            centerPanel
                .navigationSplitViewColumnWidth(min: 400, ideal: 640)
        } detail: {
            ChatScreen()
                .navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 480)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .status) {
                connectionStatusChip
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task<Void, Never> { await appModel.refreshAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("desktop_button_refresh")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $activeTab) {
            Section("Views") {
                ForEach(DesktopTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                        .accessibilityIdentifier("desktop_sidebar_tab_\(tab.rawValue)")
                }
            }

            Section("Projects") {
                if appModel.settingsStore.repositories.isEmpty {
                    Text("No repositories — add in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.settingsStore.repositories) { repo in
                        Label(repo.shortName, systemImage: "folder")
                            .font(.subheadline)
                    }
                }
            }

            Section("Sessions") {
                if appModel.sessionsStore.sessions.isEmpty {
                    Text("No active sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.sessionsStore.sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("AgentBoard")
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("screen_desktop_sidebar")
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sessionStatusColor(session.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.source)
                    .font(.subheadline)
                    .lineLimit(1)
                if let item = session.workItem {
                    Text(item.issueReference)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("desktop_sidebar_session_\(session.id)")
    }

    private func sessionStatusColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .running: BoardPalette.mint
        case .idle: BoardPalette.gold
        case .stopped: .secondary
        case .error: BoardPalette.coral
        }
    }

    // MARK: - Center Panel

    @ViewBuilder
    private var centerPanel: some View {
        switch activeTab ?? .work {
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

    // MARK: - Connection Status

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
}
