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

    var body: some View {
        VStack(spacing: 0) {
            titleBar
                .frame(height: 40)

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 230)

                centerPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NeuPalette.background)

                ChatScreen()
                    .frame(width: 360)
                    .background(NeuPalette.surface)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(NeuPalette.borderSoft)
                            .frame(width: 1)
                    }
            }
        }
        .background(NeuBackground())
    }

    private var titleBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                #if os(macOS)
                    HStack(spacing: 6) {
                        Circle().fill(Color(red: 1.0, green: 0.38, blue: 0.35))
                        Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                        Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                    }
                    .frame(width: 48)
                #endif

                HStack(spacing: 6) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 11, weight: .bold))
                    Text("AB")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(NeuPalette.background)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [NeuPalette.accentCyanBright, NeuPalette.accentCyan.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NeuPalette.textTertiary)
            }
            .frame(width: 230, alignment: .leading)
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                Text("AgentBoard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeuPalette.textSecondary)
                Text("-")
                    .font(.caption.monospaced())
                    .foregroundStyle(NeuPalette.textDisabled)
                Text(activeRepositoryTitle)
                    .font(.caption.monospaced())
                    .foregroundStyle(NeuPalette.textTertiary)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                connectionStatusChip
                Button {
                    Task<Void, Never> { await appModel.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(NeuPalette.textTertiary)
                .accessibilityIdentifier("desktop_button_refresh")
            }
            .frame(width: 360, alignment: .trailing)
            .padding(.horizontal, 14)
        }
        .background(
            LinearGradient(
                colors: [NeuPalette.surface, NeuPalette.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NeuPalette.borderSoft)
                .frame(height: 1)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.075, blue: 0.125),
                    NeuPalette.inset
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        sidebarHeader("VIEWS")

                        ForEach(DesktopTab.allCases) { tab in
                            Button {
                                activeTab = tab
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: tab.systemImage)
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(width: 18)
                                    Text(tab.title)
                                        .font(.system(size: 12.5, weight: .semibold))
                                    Spacer()
                                    if let count = tabCount(tab) {
                                        Text("\(count)")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(NeuPalette.textTertiary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(NeuPalette.inset)
                                            .clipShape(Capsule())
                                    }
                                }
                                .foregroundStyle(activeTab == tab ? NeuPalette.accentCyanBright : NeuPalette
                                    .textSecondary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(activeTab == tab ? NeuPalette.accentCyan.opacity(0.12) : .clear)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(
                                                    activeTab == tab ? NeuPalette.accentCyan.opacity(0.25) : .clear,
                                                    lineWidth: 1
                                                )
                                        }
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("desktop_sidebar_tab_\(tab.rawValue)")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sidebarHeader("PROJECTS")

                        if appModel.settingsStore.repositories.isEmpty {
                            Text("No repositories")
                                .font(.caption)
                                .foregroundStyle(NeuPalette.textSecondary)
                                .padding(.horizontal, 8)
                        } else {
                            ForEach(appModel.settingsStore.repositories) { repo in
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(projectColor(repo.shortName))
                                        .frame(width: 14, height: 14)
                                        .shadow(color: projectColor(repo.shortName).opacity(0.45), radius: 8)
                                    Text(repo.shortName)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(NeuPalette.textSecondary)
                                    Spacer()
                                    Text("\(itemsCount(for: repo))")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(NeuPalette.textTertiary)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sidebarHeader("LIVE SESSIONS")

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
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(NeuPalette.borderSoft)
                .frame(width: 1)
        }
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Circle()
                    .fill(sessionStatusColor(session.status))
                    .frame(width: 6, height: 6)
                Text(session.source)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NeuPalette.accentOrange)
                    .lineLimit(1)
                Spacer()
                Text(session.status.title.uppercased())
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(NeuPalette.textTertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let item = session.workItem {
                    Text(item.issueReference)
                        .font(.system(size: 11))
                        .foregroundStyle(NeuPalette.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 13)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
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
                .frame(width: 7, height: 7)
            Text(connectionStatusText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(connectionDotColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(NeuPalette.inset)
        .clipShape(Capsule())
    }

    private var connectionDotColor: Color {
        switch appModel.chatStore.connectionState {
        case .connected: .green
        case .connecting, .reconnecting: NeuPalette.accentOrange
        case .failed: .red
        case .disconnected: NeuPalette.textSecondary
        }
    }

    private var activeRepositoryTitle: String {
        appModel.settingsStore.repositories.first?.fullName ?? "no repository"
    }

    private var connectionStatusText: String {
        switch appModel.chatStore.connectionState {
        case .connected: "LIVE"
        case .connecting: "CONNECTING"
        case .reconnecting: "RECONNECTING"
        case .failed: "ERROR"
        case .disconnected: "OFFLINE"
        }
    }

    private func sidebarHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(NeuPalette.textDisabled)
            .padding(.horizontal, 11)
            .padding(.bottom, 2)
    }

    private func tabCount(_ tab: DesktopTab) -> Int? {
        switch tab {
        case .work: appModel.workStore.items.count
        case .agents: appModel.agentsStore.summaries.count
        case .sessions: appModel.sessionsStore.sessions.count
        case .settings: nil
        }
    }

    private func projectColor(_ shortName: String) -> Color {
        let colors = [NeuPalette.accentCyan, NeuPalette.accentOrange, NeuPalette.accentPurple]
        let index = abs(shortName.hashValue) % colors.count
        return colors[index]
    }

    private func itemsCount(for repo: ConfiguredRepository) -> Int {
        appModel.workStore.items.filter { $0.repository.id == repo.id }.count
    }
}
