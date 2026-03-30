#if os(iOS)
    import SwiftUI

    struct iOSSessionDetailView: View {
        @Environment(AppState.self) private var appState
        let session: CodingSession

        @State private var paneOutput: String = ""
        @State private var isLoadingOutput = false

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sessionInfoSection
                    Divider()
                    logSection
                }
                .padding()
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nudge") {
                        Task<Void, Never> {
                            await appState.nudgeSession(sessionID: session.id)
                        }
                    }
                    .accessibilityIdentifier("ios_session_detail_button_nudge")
                }
            }
            .task {
                await loadPaneOutput()
            }
            .refreshable {
                await loadPaneOutput()
            }
        }

        private var sessionInfoSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.sessionColor(for: session.status))
                        .frame(width: 10, height: 10)
                    Text(session.status.rawValue.capitalized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.sessionColor(for: session.status))
                }

                LabeledContent("Agent", value: session.agentType.rawValue)
                    .font(.system(size: 13))

                if let model = session.model, !model.isEmpty {
                    LabeledContent("Model", value: model)
                        .font(.system(size: 13))
                }

                if let issueNumber = session.linkedIssueNumber {
                    LabeledContent("Issue", value: "#\(issueNumber)")
                        .font(.system(size: 13))
                }

                LabeledContent("Elapsed", value: elapsedLabel)
                    .font(.system(size: 13))
            }
        }

        private var logSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Session Output")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if isLoadingOutput {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button {
                        Task<Void, Never> { await loadPaneOutput() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .accessibilityIdentifier("ios_session_detail_button_refresh_log")
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    Text(paneOutput.isEmpty ? "No output captured." : paneOutput)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(paneOutput.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
        }

        private func loadPaneOutput() async {
            isLoadingOutput = true
            if let output = await appState.captureSessionPane(sessionID: session.id) {
                paneOutput = output
            }
            isLoadingOutput = false
        }

        private var elapsedLabel: String {
            let elapsed = max(0, Int(session.elapsed))
            let hours = elapsed / 3600
            let minutes = (elapsed % 3600) / 60
            let seconds = elapsed % 60
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
#endif
