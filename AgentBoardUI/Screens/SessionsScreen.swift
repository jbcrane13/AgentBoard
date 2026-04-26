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
            NeuBackground()

            VStack(spacing: 0) {
                header
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 8)

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
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                AgentBoardEyebrow(text: "SESSIONS")
                Text("Runtime Engine")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
            Button {
                Task { await appModel.sessionsStore.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(NeuButtonTarget(isAccent: false))
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
                        .foregroundStyle(NeuPalette.textSecondary)
                } else {
                    Text(session.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(NeuPalette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 80)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.source)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NeuPalette.textPrimary)

                if let model = session.model {
                    Text(model)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NeuPalette.accentOrange)
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
                        .foregroundStyle(NeuPalette.textSecondary)
                    }

                    if let workItem = session.workItem {
                        HStack(spacing: 8) {
                            Image(systemName: "number")
                                .font(.caption)
                            Text(workItem.issueReference)
                                .font(.subheadline)
                        }
                        .foregroundStyle(NeuPalette.textSecondary)
                    }
                }
                .padding(12)
                .neuRecessed(cornerRadius: 12, depth: 3)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Started")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NeuPalette.textSecondary)
                    Text(session.startedAt, style: .relative)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NeuPalette.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Seen")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NeuPalette.textSecondary)
                    Text(session.lastSeenAt, style: .relative)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NeuPalette.textPrimary)
                }
            }
        }
        .padding(20)
        .neuExtruded(cornerRadius: 24, elevation: 8)
    }
}

struct SessionStatusNeu: View {
    let status: AgentSessionStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status == .running ? NeuPalette.accentCyan : status == .stopped ? NeuPalette
                    .accentOrange : status == .error ? .red : NeuPalette.textSecondary)
                .frame(width: 8, height: 8)
            Text(status.title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(NeuPalette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .neuRecessed(cornerRadius: 12, depth: 3)
    }
}
