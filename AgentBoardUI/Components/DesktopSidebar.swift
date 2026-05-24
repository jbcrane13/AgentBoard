import AgentBoardCore
import SwiftUI

struct DesktopSidebar: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Binding var selection: AppDestination?
    let onSessionTap: (SessionLauncher.ActiveSession) -> Void
    let onQuickLaunch: () -> Void

    var body: some View {
        List(selection: $selection) {
            Section("Views") {
                ForEach(AppDestination.desktopTabs) { tab in
                    tabRow(tab)
                        .tag(tab)
                        .accessibilityIdentifier("desktop_sidebar_tab_\(tab.rawValue)")
                }
            }

            Section("Projects") {
                if appModel.settingsStore.repositories.isEmpty {
                    Text("No repositories")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.settingsStore.repositories) { repo in
                        Label {
                            HStack {
                                Text(repo.shortName)
                                Spacer()
                                Text("\(itemsCount(for: repo))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: "folder")
                                .foregroundStyle(projectColor(repo.shortName))
                        }
                    }
                }
            }

            Section("Live Sessions") {
                Button {
                    onQuickLaunch()
                } label: {
                    Label("Quick Launch", systemImage: "plus")
                }
                .accessibilityIdentifier("sidebar_quick_launch")

                if allSidebarSessions.isEmpty && companionSessionsNotInLocal.isEmpty {
                    Text("No active sessions")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allSidebarSessions) { session in
                        Button {
                            onSessionTap(session)
                        } label: {
                            locallyLaunchedSessionRow(session)
                        }
                        .accessibilityIdentifier("sidebar_session_\(session.id)")
                    }

                    ForEach(companionSessionsNotInLocal) { session in
                        companionSessionRow(session)
                            .accessibilityIdentifier("sidebar_companion_session_\(session.id)")
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func tabRow(_ tab: AppDestination) -> some View {
        if let count = tabCount(tab) {
            Label(tab.title, systemImage: tab.systemImage)
                .badge(count)
        } else {
            Label(tab.title, systemImage: tab.systemImage)
        }
    }

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
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.agentType.displayName)
                    .lineLimit(1)
                Text("#\(session.issueNumber) \(session.preset.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: session.status == .running ? "play.circle.fill" : "circle")
                .foregroundStyle(localSessionStatusColor(session.status))
        }
    }

    private func companionSessionRow(_ session: AgentSession) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.source)
                    .lineLimit(1)
                if let item = session.workItem {
                    Text(item.issueReference)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(session.status.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: companionStatusImage(session.status))
                .foregroundStyle(companionStatusColor(session.status))
        }
    }

    private func localSessionStatusColor(_ status: SessionLauncher.ActiveSession.SessionStatus) -> Color {
        switch status {
        case .running: .green
        case .completed: .secondary
        case .failed: .red
        case .stalled: .orange
        }
    }

    private func companionStatusImage(_ status: AgentSessionStatus) -> String {
        switch status {
        case .running: "play.circle.fill"
        case .idle: "pause.circle"
        case .stopped: "stop.circle"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private func companionStatusColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .running: .green
        case .idle: .blue
        case .stopped: .secondary
        case .error: .red
        }
    }

    private func tabCount(_ tab: AppDestination) -> Int? {
        switch tab {
        case .work: appModel.workStore.items.count
        case .agents: appModel.agentsStore.summaries.count
        case .sessions: appModel.sessionsStore.sessions.count
        case .chat, .settings: nil
        }
    }

    private func projectColor(_ shortName: String) -> Color {
        let colors: [Color] = [.blue, .orange, .purple]
        let index = Int(shortName.hashValue.magnitude % UInt(colors.count))
        return colors[index]
    }

    private func itemsCount(for repo: ConfiguredRepository) -> Int {
        appModel.workStore.items.filter { $0.repository.id == repo.id }.count
    }
}
