import AgentBoardCore
import SwiftUI

struct DashboardScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    var onOpenChat: (() -> Void)?

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 20), count: isCompact ? 2 : 3)
    }

    private var snapshot: DashboardSnapshot {
        DashboardSnapshot.build(
            kanbanTasks: appModel.agentsStore.tasks,
            workItems: appModel.workStore.items,
            sessions: appModel.sessionsStore.sessions,
            conversations: appModel.chatStore.conversations,
            chatConnection: appModel.chatStore.connectionState,
            syncStatus: appModel.sessionsStore.syncStatus
        )
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 20) {
                        agentTasksTile
                        workItemsTile
                        sessionsTile
                        chatTile
                    }
                    .padding(isCompact ? 16 : 24)
                }
            }
        }
        .agentBoardNavigationBarHidden(true)
        .refreshable {
            await appModel.refreshAll()
        }
        .accessibilityIdentifier("screen_dashboard")
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                AgentBoardEyebrow(text: "DASHBOARD")
                Text("Home")
                    .font(.system(size: isCompact ? 34 : 30, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
            Button {
                Task { await appModel.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(AppButtonStyle(isAccent: false))
            .accessibilityIdentifier("dashboard_button_refresh")
        }
    }

    private var agentTasksTile: some View {
        DashboardTile(
            title: "Agent Tasks",
            systemImage: AppDestination.agents.systemImage,
            accentColor: AppTheme.accentCyan
        ) {
            appModel.selectedDestination = .agents
        } content: {
            HStack(spacing: 14) {
                statPill(label: "Running", count: snapshot.kanban.running, color: AppTheme.statusSuccess)
                statPill(label: "Ready", count: snapshot.kanban.ready, color: AppTheme.accentCyan)
                statPill(label: "Blocked", count: snapshot.kanban.blocked, color: AppTheme.accentOrange)
            }
            previewList(snapshot.runningTaskTitles, emptyText: "No tasks running")
        }
        .accessibilityIdentifier("dashboard_tile_agents")
    }

    private var workItemsTile: some View {
        DashboardTile(
            title: "Work Items",
            systemImage: AppDestination.work.systemImage,
            accentColor: AppTheme.statusBlue
        ) {
            appModel.selectedDestination = .work
        } content: {
            HStack(spacing: 14) {
                statPill(label: "To Do", count: snapshot.work.todo, color: AppTheme.statusBlue)
                statPill(label: "In Progress", count: snapshot.work.inProgress, color: AppTheme.accentOrange)
                statPill(label: "Resolved", count: snapshot.work.resolved, color: AppTheme.accentGreen)
            }
        }
        .accessibilityIdentifier("dashboard_tile_work")
    }

    private var sessionsTile: some View {
        DashboardTile(
            title: "Sessions",
            systemImage: AppDestination.sessions.systemImage,
            accentColor: AppTheme.statusIdle
        ) {
            appModel.selectedDestination = .sessions
        } content: {
            HStack(spacing: 14) {
                statPill(label: "Active", count: snapshot.sessions.active, color: AppTheme.statusSuccess)
                statPill(label: "Total", count: snapshot.sessions.total, color: AppTheme.textSecondary)
            }
            Text(snapshot.sessions.syncStatus.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .accessibilityIdentifier("dashboard_tile_sessions")
    }

    private var chatTile: some View {
        DashboardTile(
            title: "Chat",
            systemImage: AppDestination.chat.systemImage,
            accentColor: AppTheme.accentPurple
        ) {
            if let onOpenChat {
                onOpenChat()
            } else {
                appModel.selectedDestination = .chat
            }
        } content: {
            Text(snapshot.chatConnection.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            previewList(
                snapshot.recentConversations.map(\.title),
                emptyText: "No conversations yet"
            )
        }
        .accessibilityIdentifier("dashboard_tile_chat")
    }

    private func statPill(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.6), radius: 4)
            Text("\(count)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func previewList(_ lines: [String], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if lines.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                ForEach(lines, id: \.self) { line in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.textTertiary)
                            .frame(width: 4, height: 4)
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashboardTile<Content: View>: View {
    let title: String
    let systemImage: String
    let accentColor: Color
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 30, height: 30)
                        .background(accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(cornerRadius: 22, elevation: 8)
        }
        .buttonStyle(.plain)
    }
}
