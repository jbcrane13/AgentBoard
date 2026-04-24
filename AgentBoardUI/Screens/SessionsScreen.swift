import AgentBoardCore
import SwiftUI

struct SessionsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        ZStack {
            BoardBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    BoardHeader(
                        eyebrow: "Sessions",
                        title: "Live execution status from the companion service",
                        subtitle: "The new app tracks sessions as companion-owned runtime state rather than terminal capture views inside the client."
                    )

                    Spacer(minLength: 20)

                    Button("Refresh") {
                        Task { await appModel.sessionsStore.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BoardPalette.cobalt)
                }

                if appModel.sessionsStore.sessions.isEmpty {
                    EmptyStateCard(
                        title: "No sessions yet",
                        message: appModel.sessionsStore
                            .statusMessage ??
                            "Once the companion sees agent processes, their live state will appear here.",
                        systemImage: "bolt.horizontal.circle"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(appModel.sessionsStore.sessions) { session in
                                BoardSurface {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            SessionStatusPill(status: session.status)
                                            Spacer()
                                            Text(session.id)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(BoardPalette.gold)
                                        }

                                        Text(session.source)
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        if let model = session.model {
                                            Text(model)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(BoardPalette.paper.opacity(0.82))
                                        }

                                        if let taskID = session.linkedTaskID {
                                            Text("Task \(taskID)")
                                                .font(.subheadline)
                                                .foregroundStyle(BoardPalette.paper.opacity(0.72))
                                        }

                                        if let workItem = session.workItem {
                                            Text(workItem.issueReference)
                                                .font(.caption)
                                                .foregroundStyle(BoardPalette.paper.opacity(0.72))
                                        }

                                        Divider()
                                            .overlay(Color.white.opacity(0.1))

                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Started")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(BoardPalette.paper.opacity(0.6))
                                                Text(session.startedAt, style: .relative)
                                                    .foregroundStyle(.white)
                                            }

                                            Spacer()

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Last Seen")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(BoardPalette.paper.opacity(0.6))
                                                Text(session.lastSeenAt, style: .relative)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
