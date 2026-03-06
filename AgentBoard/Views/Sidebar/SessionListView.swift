import SwiftUI

struct SessionListView: View {
    @Environment(AppState.self) private var appState
    let showHeader: Bool

    init(showHeader: Bool = true) {
        self.showHeader = showHeader
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showHeader {
                sectionHeader("Coding Sessions")
            }

            if appState.unreadSessionAlertsCount > 0 {
                alertsRow
            }

            if appState.sessions.isEmpty {
                Text("No active sessions")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.sidebarMutedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                ForEach(appState.sessions) { session in
                    sessionRow(session)
                }
            }
        }
        .padding(.horizontal, showHeader ? 12 : 2)
        .padding(.top, showHeader ? 8 : 2)
        .padding(.bottom, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(AppTheme.sidebarMutedText)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
    }

    private var alertsRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 10))
            Text("\(appState.unreadSessionAlertsCount) session update\(appState.unreadSessionAlertsCount == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(Color(red: 1.0, green: 0.231, blue: 0.188))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func sessionRow(_ session: CodingSession) -> some View {
        let isInteractive = session.status == .running || session.status == .idle

        return Button {
            guard isInteractive else { return }
            appState.openSessionInTerminal(session)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor(session.status))
                    .frame(width: 7, height: 7)
                    .shadow(color: session.status == .running
                            ? statusColor(session.status).opacity(0.5)
                            : .clear, radius: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(size: 12))
                        .foregroundStyle(isInteractive
                                         ? AppTheme.sidebarPrimaryText
                                         : AppTheme.sidebarMutedText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 5) {
                        if let beadId = session.beadId {
                            Text(beadId)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Color.accentColor.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 3)
                                )
                        }
                        if let model = session.model, !model.isEmpty {
                            Text(model)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.sidebarMutedText)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(statusLabel(session))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.sidebarMutedText)

                    if appState.sessionAlertSessionIDs.contains(session.id) {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.231, blue: 0.188))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(appState.activeSessionID == session.id
                          ? Color.white.opacity(0.12)
                          : Color.clear)
            )
            .contentShape(Rectangle())
            .opacity(isInteractive ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityIdentifier("SessionRow")
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        AppTheme.sessionColor(for: status)
    }

    private func statusLabel(_ session: CodingSession) -> String {
        switch session.status {
        case .running:
            let minutes = Int(session.elapsed / 60)
            return "\(minutes)m"
        case .idle:
            return "idle"
        case .stopped:
            return "done"
        case .error:
            return "error"
        }
    }
}
