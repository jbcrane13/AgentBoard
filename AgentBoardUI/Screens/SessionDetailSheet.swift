import AgentBoardCore
import SwiftUI

struct SessionDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let session: AgentSession

    @State private var output: String?
    @State private var isLoadingOutput = false
    @State private var showStopConfirm = false
    @State private var isActing = false

    private var isControllable: Bool {
        session.status == .running || session.status == .idle
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        metadataCard
                        outputCard
                        if isControllable {
                            controlCard
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(session.source)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadOutput() }
                    } label: {
                        Label("Refresh Output", systemImage: "arrow.clockwise")
                    }
                    .foregroundStyle(.white)
                    .disabled(isLoadingOutput)
                }
            }
            .alert("Stop Session", isPresented: $showStopConfirm) {
                Button("Stop", role: .destructive) {
                    Task {
                        isActing = true
                        await appModel.sessionsStore.stopSession(id: session.id)
                        isActing = false
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Send a stop signal to \"\(session.source)\"? The session will be terminated.")
            }
        }
        .task { await loadOutput() }
    }

    private var metadataCard: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SessionStatusPill(status: session.status)
                    Spacer()
                    if let pid = session.pid {
                        BoardChip(label: "PID \(pid)", systemImage: "cpu", tint: .secondary)
                    }
                }

                Text(session.source)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                if let model = session.model {
                    Label(model, systemImage: "cpu")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let tmux = session.tmuxSession {
                    Label(tmux, systemImage: "terminal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let linkedTask = appModel.agentsStore.tasks.first(where: { $0.sessionID == session.id }) {
                    Label(linkedTask.title, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }

                if let workItem = session.workItem {
                    Label(workItem.issueReference, systemImage: "square.grid.2x2")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }

                Divider().overlay(Color.white.opacity(0.1))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Started")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(session.startedAt, style: .relative)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Seen")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(session.lastSeenAt, style: .relative)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var outputCard: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Terminal Output")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if isLoadingOutput {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.orange)
                    }
                }

                if let output, !output.isEmpty {
                    ScrollView {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.green)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(maxHeight: 320)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.36))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                } else if !isLoadingOutput {
                    Text("No output captured. The companion service may need tmux enabled.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var controlCard: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Controls")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Button {
                        Task {
                            isActing = true
                            await appModel.sessionsStore.nudgeSession(id: session.id)
                            isActing = false
                        }
                    } label: {
                        Label("Nudge", systemImage: "hand.tap")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .disabled(isActing)

                    Button {
                        showStopConfirm = true
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isActing)
                }
            }
        }
    }

    private func loadOutput() async {
        isLoadingOutput = true
        output = await appModel.sessionsStore.fetchOutput(sessionID: session.id)
        if output == nil {
            output = session.lastOutput
        }
        isLoadingOutput = false
    }
}
