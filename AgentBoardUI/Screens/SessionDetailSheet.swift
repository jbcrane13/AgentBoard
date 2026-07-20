import AgentBoardCore
import SwiftUI

struct SessionDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let session: AgentSession

    @State private var selectedTab = 0
    @State private var finalOutput: String?
    @State private var isRefreshing = false
    @State private var transcript: SessionTranscript?
    @State private var isRefreshingTranscript = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppBackground()

                VStack(spacing: 0) {
                    headerCard
                        .padding(24)

                    Picker("Mode", selection: $selectedTab) {
                        Text("Overview").tag(0)
                        Text("Output Logs").tag(1)
                        if session.tmuxSession != nil {
                            Text("Terminal").tag(2)
                        }
                        Text("Transcript").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .accessibilityIdentifier("session_detail_picker_mode")

                    if selectedTab == 0 {
                        overviewTab
                    } else if selectedTab == 2 {
                        terminalTab
                    } else if selectedTab == 3 {
                        transcriptTab
                    } else {
                        logsTab
                    }
                }
            }
            .navigationTitle("Session \(session.id.prefix(8))")
            .agentBoardNavigationBarTitleInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityIdentifier("session_detail_button_close")
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
                            .accessibilityIdentifier("session_detail_button_stop")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .accessibilityIdentifier("session_detail_menu_actions")
                }
            }
        }
        .accessibilityIdentifier("screen_session_detail")
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
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.source)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if let model = session.model {
                    Text(model)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.accentOrange)
                }
            }
        }
        .padding(24)
        .cardSurface(cornerRadius: 24, elevation: 8)
    }

    private var overviewTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if session.linkedTaskID != nil || session.workItem != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LINKS")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.textSecondary)

                        if let taskID = session.linkedTaskID {
                            HStack(spacing: 12) {
                                Image(systemName: "list.clipboard")
                                    .font(.headline)
                                Text("Task \(taskID)")
                                    .font(.headline)
                            }
                            .foregroundStyle(AppTheme.accentCyan)
                        }

                        if let workItem = session.workItem {
                            HStack(spacing: 12) {
                                Image(systemName: "number")
                                    .font(.headline)
                                Text(workItem.issueReference)
                                    .font(.headline)
                            }
                            .foregroundStyle(AppTheme.accentCyan)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface(cornerRadius: 24, elevation: 8)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("TIMELINE")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Started")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(session.startedAt, style: .relative)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Last Seen")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(session.lastSeenAt, style: .relative)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
                .padding(24)
                .cardSurface(cornerRadius: 24, elevation: 8)
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
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(16)
                    } else {
                        Text("No logs available")
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .insetSurface(cornerRadius: 16, depth: 6)
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

    private var transcriptTab: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 8) {
                if isRefreshingTranscript && transcript == nil {
                    ProgressView().padding()
                } else if let transcript, !transcript.content.isEmpty {
                    Text(transcript.content)
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.textPrimary)
                        .textSelection(.enabled)
                        .padding(16)
                } else {
                    Text("No transcript available yet")
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .insetSurface(cornerRadius: 16, depth: 6)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .accessibilityIdentifier("session_transcript_view")
        .task {
            await fetchTranscript()
        }
        .onChange(of: appModel.sessionsStore.lastSyncedAt) { _, _ in
            guard transcript?.isFinal != true else { return }
            Task { await fetchTranscript() }
        }
    }

    private func fetchTranscript() async {
        isRefreshingTranscript = true
        transcript = await appModel.sessionsStore.fetchTranscript(sessionID: session.id)
        isRefreshingTranscript = false
    }

    @ViewBuilder
    private var terminalTab: some View {
        if let tmuxSession = session.tmuxSession {
            #if os(macOS) && canImport(SwiftTerm)
                let attach = SessionLauncher.attachCommand(for: tmuxSession)
                EmbeddedTerminalView(
                    executable: attach.executable,
                    arguments: attach.arguments,
                    environment: nil,
                    onProcessExit: { _ in }
                )
                .id(tmuxSession)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.06, green: 0.06, blue: 0.08))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .accessibilityIdentifier("session_detail_terminal_embedded")
            #else
                terminalUnavailableView
            #endif
        } else {
            terminalUnavailableView
        }
    }

    private var terminalUnavailableView: some View {
        Text("No terminal available")
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
    }
}
