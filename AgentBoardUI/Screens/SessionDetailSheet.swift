import AgentBoardCore
import SwiftUI

struct SessionDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let session: AgentSession

    @State private var selectedTab = 0
    @State private var finalOutput: String?
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                NeuBackground()

                VStack(spacing: 0) {
                    headerCard
                        .padding(24)

                    Picker("Mode", selection: $selectedTab) {
                        Text("Overview").tag(0)
                        Text("Output Logs").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    if selectedTab == 0 {
                        overviewTab
                    } else {
                        logsTab
                    }
                }
            }
            .navigationTitle("Session \(session.id.prefix(8))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(NeuPalette.textPrimary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if session.status == .running {
                            Button("Stop Session", role: .destructive) {
                                Task {
                                    await appModel.sessionsStore.stopSession(id: session.id)
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(NeuPalette.textPrimary)
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SessionStatusNeu(status: session.status)
                Spacer()
                if let pid = session.pid {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.caption)
                        Text("PID \(pid)")
                            .font(.caption.monospaced())
                    }
                    .foregroundStyle(NeuPalette.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.source)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(NeuPalette.textPrimary)

                if let model = session.model {
                    Text(model)
                        .font(.body.weight(.medium))
                        .foregroundStyle(NeuPalette.accentOrange)
                }
            }
        }
        .padding(24)
        .neuExtruded(cornerRadius: 24, elevation: 8)
    }

    private var overviewTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if session.linkedTaskID != nil || session.workItem != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LINKS")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(NeuPalette.textSecondary)

                        if let taskID = session.linkedTaskID {
                            HStack(spacing: 12) {
                                Image(systemName: "list.clipboard")
                                    .font(.headline)
                                Text("Task \(taskID)")
                                    .font(.headline)
                            }
                            .foregroundStyle(NeuPalette.accentCyan)
                        }

                        if let workItem = session.workItem {
                            HStack(spacing: 12) {
                                Image(systemName: "number")
                                    .font(.headline)
                                Text(workItem.issueReference)
                                    .font(.headline)
                            }
                            .foregroundStyle(NeuPalette.accentCyan)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .neuExtruded(cornerRadius: 24, elevation: 8)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("TIMELINE")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(NeuPalette.textSecondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Started")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NeuPalette.textSecondary)
                            Text(session.startedAt, style: .relative)
                                .font(.body.weight(.medium))
                                .foregroundStyle(NeuPalette.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Last Seen")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NeuPalette.textSecondary)
                            Text(session.lastSeenAt, style: .relative)
                                .font(.body.weight(.medium))
                                .foregroundStyle(NeuPalette.textPrimary)
                        }
                    }
                }
                .padding(24)
                .neuExtruded(cornerRadius: 24, elevation: 8)
            }
            .padding(.horizontal, 24)
        }
    }

    private var logsTab: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if isRefreshing && finalOutput == nil {
                        ProgressView().padding()
                    } else if let out = finalOutput, !out.isEmpty {
                        Text(out)
                            .font(.caption.monospaced())
                            .foregroundStyle(NeuPalette.textPrimary)
                            .padding(16)
                    } else {
                        Text("No logs available")
                            .foregroundStyle(NeuPalette.textSecondary)
                            .padding()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .neuRecessed(cornerRadius: 16, depth: 6)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .task {
            await fetchOutput()
        }
    }

    private func fetchOutput() async {
        isRefreshing = true
        let output = await appModel.sessionsStore.fetchOutput(sessionID: session.id)
        if output == nil {
            finalOutput = session.lastOutput
        } else {
            finalOutput = output
        }
        isRefreshing = false
    }
}
