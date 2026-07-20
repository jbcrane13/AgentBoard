import AgentBoardCore
import SwiftUI

struct SessionsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var selectedSession: AgentSession?
    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 24)]

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 8)

                if let banner = syncBanner {
                    banner
                        .padding(.horizontal, isCompact ? 16 : 24)
                        .padding(.bottom, 12)
                }

                if appModel.sessionsStore.sessions.isEmpty {
                    EmptyStateCard(
                        title: "No sessions yet",
                        message: appModel.sessionsStore
                            .statusMessage ??
                            "Once the companion sees agent processes, their live state will appear here.",
                        systemImage: "bolt.horizontal.circle"
                    )
                    .padding(isCompact ? 16 : 24)
                } else if isCompact {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 20) {
                            ForEach(appModel.sessionsStore.sessions) { session in
                                Button {
                                    selectedSession = session
                                } label: {
                                    SessionCardNeu(session: session)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("sessions_cell_session_\(session.id)")
                            }
                        }
                        .padding(isCompact ? 16 : 24)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(appModel.sessionsStore.sessions) { session in
                                Button {
                                    selectedSession = session
                                } label: {
                                    SessionCardNeu(session: session)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("sessions_cell_session_\(session.id)")
                            }
                        }
                        .padding(24)
                    }
                }
            }
        }
        .agentBoardNavigationBarHidden(true)
        .refreshable {
            await appModel.sessionsStore.refresh()
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
                .environment(appModel)
        }
        .accessibilityIdentifier("screen_sessions")
    }

    private var syncBanner: SyncStatusBanner? {
        switch appModel.sessionsStore.syncStatus {
        case .cached:
            SyncStatusBanner(
                icon: "wifi.slash",
                title: "Showing cached sessions",
                message: "Companion service is unreachable. Sessions will sync when it reconnects.",
                tone: .warning,
                identifier: "sessions_banner_cached"
            )
        case .offline:
            SyncStatusBanner(
                icon: "antenna.radiowaves.left.and.right.slash",
                title: "Companion not connected",
                message: "Connect the companion service in Settings to sync sessions across devices.",
                tone: .info,
                identifier: "sessions_banner_offline"
            )
        case .loading, .live:
            nil
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                AgentBoardEyebrow(text: "SESSIONS")
                Text("Runtime Engine")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
            Button {
                Task { await appModel.sessionsStore.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(AppButtonStyle(isAccent: false))
            .accessibilityIdentifier("sessions_button_refresh")
        }
    }
}

private struct SessionCardNeu: View {
    let session: AgentSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SessionStatusNeu(status: session.status)
                Spacer()
                if let pid = session.pid {
                    Text("PID \(pid)")
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text(session.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 80)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.source)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if let model = session.model {
                    Text(model)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accentOrange)
                }
            }

            if session.linkedTaskID != nil || session.workItem != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let taskID = session.linkedTaskID {
                        HStack(spacing: 8) {
                            Image(systemName: "list.clipboard")
                                .font(.caption)
                            Text("Task \(taskID)")
                                .font(.subheadline)
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }

                    if let workItem = session.workItem {
                        HStack(spacing: 8) {
                            Image(systemName: "number")
                                .font(.caption)
                            Text(workItem.issueReference)
                                .font(.subheadline)
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(12)
                .insetSurface(cornerRadius: 12, depth: 3)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Started")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(session.startedAt, style: .relative)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Seen")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(session.lastSeenAt, style: .relative)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .padding(20)
        .cardSurface(cornerRadius: 24, elevation: 8)
    }
}

struct SyncStatusBanner: View {
    enum Tone {
        case warning
        case info
    }

    let icon: String
    let title: String
    let message: String
    let tone: Tone
    let identifier: String

    private var accentColor: Color {
        switch tone {
        case .warning: AppTheme.accentOrange
        case .info: AppTheme.textSecondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .insetSurface(cornerRadius: 16, depth: 4)
        .accessibilityIdentifier(identifier)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

struct SessionStatusNeu: View {
    let status: AgentSessionStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status == .running ? AppTheme.accentCyan : status == .stopped ? AppTheme
                    .accentOrange : status == .error ? .red : AppTheme.textSecondary)
                .frame(width: 8, height: 8)
            Text(status.title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .insetSurface(cornerRadius: 12, depth: 3)
    }
}
