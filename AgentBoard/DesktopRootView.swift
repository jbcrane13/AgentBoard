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
        case .work: "square.grid.3x3"
        case .agents: "person.3.sequence.fill"
        case .sessions: "bolt.horizontal.circle.fill"
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
                .navigationSplitViewColumnWidth(min: 600, ideal: 800)
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
                .buttonStyle(NeuButtonTarget(isAccent: false))
                .accessibilityIdentifier("desktop_button_refresh")
            }
        }
        .background(NeuBackground())
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ZStack {
            NeuBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VIEWS")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(NeuPalette.textSecondary)
                            .padding(.horizontal, 8)

                        ForEach(DesktopTab.allCases) { tab in
                            Button {
                                activeTab = tab
                            } label: {
                                HStack {
                                    Image(systemName: tab.systemImage)
                                        .frame(width: 24)
                                    Text(tab.title)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                }
                                .foregroundStyle(activeTab == tab ? NeuPalette.accentCyan : NeuPalette.textSecondary)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(activeTab == tab ? Color.white.opacity(0.05) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("desktop_sidebar_tab_\(tab.rawValue)")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("PROJECTS")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(NeuPalette.textSecondary)
                            .padding(.horizontal, 8)

                        if appModel.settingsStore.repositories.isEmpty {
                            Text("No repositories")
                                .font(.caption)
                                .foregroundStyle(NeuPalette.textSecondary)
                                .padding(.horizontal, 8)
                        } else {
                            ForEach(appModel.settingsStore.repositories) { repo in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(NeuPalette.accentOrange)
                                    Text(repo.shortName)
                                        .font(.subheadline)
                                        .foregroundStyle(NeuPalette.textPrimary)
                                    Spacer()
                                }
                                .padding(12)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("SESSIONS")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(NeuPalette.textSecondary)
                            .padding(.horizontal, 8)

                        if appModel.sessionsStore.sessions.isEmpty {
                            Text("No active sessions")
                                .font(.caption)
                                .foregroundStyle(NeuPalette.textSecondary)
                                .padding(.horizontal, 8)
                        } else {
                            ForEach(appModel.sessionsStore.sessions) { session in
                                sessionRow(session)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("AgentBoard")
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sessionStatusColor(session.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.source)
                    .font(.subheadline)
                    .foregroundStyle(NeuPalette.textPrimary)
                    .lineLimit(1)
                if let item = session.workItem {
                    Text(item.issueReference)
                        .font(.caption)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .accessibilityIdentifier("desktop_sidebar_session_\(session.id)")
    }

    private func sessionStatusColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .running: .green
        case .idle: .blue
        case .stopped: NeuPalette.textSecondary
        case .error: .red
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
                .font(.caption.weight(.bold))
                .foregroundStyle(NeuPalette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .neuRecessed(cornerRadius: 12, depth: 3)
    }

    private var connectionDotColor: Color {
        switch appModel.chatStore.connectionState {
        case .connected: .green
        case .connecting, .reconnecting: NeuPalette.accentOrange
        case .failed: .red
        case .disconnected: NeuPalette.textSecondary
        }
    }
}
