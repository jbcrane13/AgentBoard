import AgentBoardCore
import SwiftUI

struct SessionsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var selectedSession: AgentSession?
    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        Group {
            if appModel.sessionsStore.sessions.isEmpty {
                EmptyStateCard(
                    title: "No sessions yet",
                    message: appModel.sessionsStore
                        .statusMessage ?? "Once the companion sees agent processes, their live state will appear here.",
                    systemImage: "bolt.horizontal.circle"
                )
            } else if isCompact {
                List {
                    ForEach(appModel.sessionsStore.sessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(appModel.sessionsStore.sessions) { session in
                            Button {
                                selectedSession = session
                            } label: {
                                sessionCard(session)
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Sessions")
        .refreshable {
            await appModel.sessionsStore.refresh()
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
                .environment(appModel)
        }
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SessionStatusPill(status: session.status)
                Spacer()
                if let pid = session.pid {
                    Text("PID \(pid)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text(session.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 80)
                }
            }

            Text(session.source)
                .font(.headline)
                .foregroundStyle(.primary)

            if let model = session.model {
                Text(model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if let taskID = session.linkedTaskID {
                    Text("Task \(taskID)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let workItem = session.workItem {
                    Text(workItem.issueReference)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(session.lastSeenAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func sessionCard(_ session: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SessionStatusPill(status: session.status)
                Spacer()
                if let pid = session.pid {
                    Text("PID \(pid)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text(session.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 80)
                }
            }

            Text(session.source)
                .font(.headline)
                .foregroundStyle(.primary)

            if let model = session.model {
                Text(model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let taskID = session.linkedTaskID {
                Text("Task \(taskID)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let workItem = session.workItem {
                Text(workItem.issueReference)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Started")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Text(session.startedAt, style: .relative)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Seen")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Text(session.lastSeenAt, style: .relative)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        .contentShape(Rectangle())
    }
}
