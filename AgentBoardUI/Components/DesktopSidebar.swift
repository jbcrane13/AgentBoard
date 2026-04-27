import AgentBoardCore
import SwiftUI

struct DesktopSidebar: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let activeTab: DesktopTab?
    let onTabSelect: (DesktopTab) -> Void
    let onSessionTap: (SessionLauncher.ActiveSession) -> Void
    let onQuickLaunch: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NeuPalette.surface,
                    NeuPalette.inset
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    viewsSection
                    projectsSection
                    liveSessionsSection
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

    // MARK: - Views Section

    private var viewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sidebarHeader("VIEWS")

            ForEach(DesktopTab.allCases) { tab in
                Button {
                    onTabSelect(tab)
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
    }

    // MARK: - Projects Section

    private var projectsSection: some View {
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
    }

    // MARK: - Live Sessions Section

    private var liveSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sidebarHeader("LIVE SESSIONS")
                Spacer()
                Button {
                    onQuickLaunch()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NeuPalette.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebar_quick_launch")
            }

            if allSidebarSessions.isEmpty && companionSessionsNotInLocal.isEmpty {
                Text("No active sessions")
                    .font(.caption)
                    .foregroundStyle(NeuPalette.textSecondary)
                    .padding(.horizontal, 8)
            } else {
                ForEach(allSidebarSessions) { session in
                    Button {
                        onSessionTap(session)
                    } label: {
                        locallyLaunchedSessionRow(session)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar_session_\(session.id)")
                }

                ForEach(companionSessionsNotInLocal) { session in
                    companionSessionRow(session)
                        .accessibilityIdentifier("sidebar_companion_session_\(session.id)")
                }
            }
        }
    }

    // MARK: - Helpers

    private var allSidebarSessions: [SessionLauncher.ActiveSession] {
        appModel.sessionLauncher.activeSessions
    }

    private var companionSessionsNotInLocal: [AgentSession] {
        let localNames = Set(appModel.sessionLauncher.activeSessions.map(\.sessionName))
        return appModel.sessionsStore.sessions.filter { session in
            guard let tmuxName = session.tmuxSession else { return true }
            return !localNames.contains(tmuxName)
        }
    }

    private func locallyLaunchedSessionRow(_ session: SessionLauncher.ActiveSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Circle()
                    .fill(localSessionStatusColor(session.status))
                    .frame(width: 6, height: 6)
                Text(session.agentType.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NeuPalette.accentOrange)
                    .lineLimit(1)
                Spacer()
                Text(session.status == .running ? "RUNNING" : session.status.description.uppercased())
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(NeuPalette.textTertiary)
            }
            HStack(spacing: 6) {
                Text("#\(session.issueNumber)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NeuPalette.accentCyan)
                Text(session.preset.rawValue)
                    .font(.system(size: 10))
                    .foregroundStyle(NeuPalette.textTertiary)
                    .lineLimit(1)
            }
            .padding(.leading, 13)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
    }

    private func companionSessionRow(_ session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Circle()
                    .fill(companionStatusColor(session.status))
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
            if let item = session.workItem {
                Text(item.issueReference)
                    .font(.system(size: 11))
                    .foregroundStyle(NeuPalette.textTertiary)
                    .lineLimit(1)
                    .padding(.leading, 13)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
    }

    private func localSessionStatusColor(_ status: SessionLauncher.ActiveSession.SessionStatus) -> Color {
        switch status {
        case .running: NeuPalette.statusSuccess
        case .completed: NeuPalette.statusClosed
        case .failed: .red
        case .stalled: NeuPalette.accentOrange
        }
    }

    private func companionStatusColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .running: NeuPalette.statusSuccess
        case .idle: NeuPalette.statusIdle
        case .stopped: NeuPalette.textSecondary
        case .error: .red
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
