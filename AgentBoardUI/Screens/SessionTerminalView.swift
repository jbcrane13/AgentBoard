import AgentBoardCore
import SwiftUI

struct SessionTerminalView: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    let session: SessionLauncher.ActiveSession
    let onMinimize: () -> Void

    @State private var paneOutput: String = ""
    @State private var isRefreshing = false
    @State private var refreshTimer: Timer?

    private var statusColor: Color {
        switch session.status {
        case .running: NeuPalette.accentCyan
        case .completed: NeuPalette.statusClosed
        case .failed: .red
        case .stalled: NeuPalette.accentOrange
        }
    }

    private var statusTitle: String {
        switch session.status {
        case .running: "RUNNING"
        case .completed: "COMPLETED"
        case .failed: "FAILED"
        case .stalled: "STALLED"
        }
    }

    var body: some View {
        ZStack {
            NeuBackground()

            VStack(spacing: 0) {
                // Header bar
                HStack(spacing: 12) {
                    Button {
                        onMinimize()
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NeuPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session_terminal_minimize")

                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.6), radius: 6)

                    Text(session.agentType.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NeuPalette.textPrimary)

                    Text(session.preset.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NeuPalette.accentOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(NeuPalette.accentOrange.opacity(0.12))
                        .clipShape(Capsule())

                    Text(statusTitle)
                        .font(.caption2.weight(.bold).monospaced())
                        .tracking(0.8)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.08))
                        .clipShape(Capsule())

                    Spacer()

                    Text("Issue #\(session.issueNumber)")
                        .font(.caption.monospaced())
                        .foregroundStyle(NeuPalette.accentCyan)

                    Text(session.elapsed)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(NeuPalette.textTertiary)

                    Button {
                        captureOutput()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(NeuButtonTarget(isAccent: false))
                    .accessibilityIdentifier("session_terminal_refresh")

                    Button {
                        appModel.sessionLauncher.openInTerminal(sessionName: session.sessionName)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Terminal")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(NeuButtonTarget(isAccent: true))
                    .accessibilityIdentifier("session_terminal_open_terminal")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [NeuPalette.surface, NeuPalette.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(NeuPalette.borderSoft)
                        .frame(height: 1)
                }

                // Terminal output
                if paneOutput.isEmpty && !isRefreshing {
                    VStack(spacing: 16) {
                        Image(systemName: "terminal")
                            .font(.system(size: 40))
                            .foregroundStyle(NeuPalette.textTertiary)
                        Text("Waiting for session output…")
                            .font(.subheadline)
                            .foregroundStyle(NeuPalette.textSecondary)
                        Text("Session: \(session.sessionName)")
                            .font(.caption.monospaced())
                            .foregroundStyle(NeuPalette.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                if isRefreshing && paneOutput.isEmpty {
                                    ProgressView()
                                        .padding()
                                } else {
                                    Text(paneOutput)
                                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                                        .foregroundStyle(NeuPalette.textPrimary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                }
                            }
                            .id("terminal_output")
                        }
                        .onChange(of: paneOutput) {
                            withAnimation {
                                proxy.scrollTo("terminal_output", anchor: .bottom)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.08))
                }
            }
        }
        .task {
            captureOutput()
        }
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    private func captureOutput() {
        isRefreshing = true
        let output = appModel.sessionLauncher.capturePane(sessionName: session.sessionName)
        if let output {
            paneOutput = output
        }
        isRefreshing = false
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                captureOutput()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
