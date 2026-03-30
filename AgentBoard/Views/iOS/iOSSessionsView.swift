#if os(iOS)
    import SwiftUI

    struct iOSSessionsView: View {
        @Environment(AppState.self) private var appState

        var body: some View {
            NavigationStack {
                Group {
                    if appState.sessions.isEmpty {
                        ContentUnavailableView(
                            "No Active Sessions",
                            systemImage: "terminal",
                            description: Text("Sessions from your macOS gateway will appear here.")
                        )
                    } else {
                        List(appState.sessions) { session in
                            NavigationLink(value: session) {
                                sessionRow(session)
                            }
                            .accessibilityIdentifier("ios_sessions_cell_\(session.id)")
                        }
                        .listStyle(.insetGrouped)
                        .navigationDestination(for: CodingSession.self) { session in
                            iOSSessionDetailView(session: session)
                        }
                    }
                }
                .navigationTitle("Sessions")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable {
                    await appState.refreshSessions()
                }
            }
        }

        private func sessionRow(_ session: CodingSession) -> some View {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.sessionColor(for: session.status))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(session.agentType.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        if let model = session.model, !model.isEmpty {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(model)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Text(session.status.rawValue.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.sessionColor(for: session.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        AppTheme.sessionColor(for: session.status).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
            .padding(.vertical, 4)
        }
    }
#endif
