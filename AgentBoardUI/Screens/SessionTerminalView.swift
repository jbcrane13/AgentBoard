import AgentBoardCore
import SwiftUI

struct SessionTerminalView: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    let session: SessionLauncher.ActiveSession
    @Binding var isExpanded: Bool
    let onMinimize: () -> Void

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
                header

                switch session.status {
                case .failed:
                    failedStateView
                case .stalled:
                    stalledStateView
                case .running, .completed:
                    terminalContentView
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
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

            if session.status == .running || session.status == .completed {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" :
                        "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(NeuButtonTarget(isAccent: false))
                .accessibilityLabel(isExpanded ? "Collapse terminal" : "Expand terminal to full width")
                .accessibilityIdentifier("session_terminal_toggle_expand")

                Button {
                    appModel.sessionLauncher.openInTerminal(sessionName: session.sessionName)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Detach")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(NeuButtonTarget(isAccent: true))
                .accessibilityLabel("Open session in Terminal.app")
                .accessibilityIdentifier("session_terminal_open_terminal")
            }

            Button {
                onMinimize()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NeuPalette.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close session terminal")
            .accessibilityIdentifier("session_terminal_close")
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
    }

    // MARK: - Live Terminal

    @ViewBuilder
    private var terminalContentView: some View {
        #if os(macOS) && canImport(SwiftTerm)
            let attach = SessionLauncher.attachCommand(for: session.sessionName)
            EmbeddedTerminalView(
                executable: attach.executable,
                arguments: attach.arguments,
                environment: nil,
                onProcessExit: { _ in }
            )
            .id(session.sessionName)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08))
            .accessibilityIdentifier("session_terminal_embedded")
        #else
            VStack(spacing: 12) {
                Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(NeuPalette.textSecondary)
                Text("Interactive terminal is available on macOS only")
                    .font(.subheadline)
                    .foregroundStyle(NeuPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    // MARK: - Failed State

    private var failedStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Session Failed")
                .font(.title2.weight(.bold))
                .foregroundStyle(NeuPalette.textPrimary)

            Text("The agent session encountered an error and could not continue.")
                .font(.subheadline)
                .foregroundStyle(NeuPalette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if let error = appModel.sessionLauncher.lastError {
                Text(error)
                    .font(.caption.monospaced())
                    .foregroundStyle(NeuPalette.textTertiary)
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                Button {
                    appModel.sessionLauncher.openInTerminal(sessionName: session.sessionName)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                        Text("View in Terminal")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(NeuButtonTarget(isAccent: true))
                .accessibilityLabel("Open failed session in Terminal.app")
                .accessibilityIdentifier("session_terminal_failed_open_terminal")

                Button {
                    onMinimize()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Close")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(NeuButtonTarget(isAccent: false))
                .accessibilityLabel("Close failed session view")
                .accessibilityIdentifier("session_terminal_failed_close")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stalled State

    private var stalledStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundStyle(NeuPalette.accentOrange)

            Text("Session Stalled")
                .font(.title2.weight(.bold))
                .foregroundStyle(NeuPalette.textPrimary)

            Text("The agent session appears to be inactive. It may have stopped producing output.")
                .font(.subheadline)
                .foregroundStyle(NeuPalette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            HStack(spacing: 12) {
                Button {
                    appModel.sessionLauncher.openInTerminal(sessionName: session.sessionName)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                        Text("View in Terminal")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(NeuButtonTarget(isAccent: true))
                .accessibilityLabel("Open stalled session in Terminal.app")
                .accessibilityIdentifier("session_terminal_stalled_open_terminal")

                Button {
                    onMinimize()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Close")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(NeuButtonTarget(isAccent: false))
                .accessibilityLabel("Close stalled session view")
                .accessibilityIdentifier("session_terminal_stalled_close")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
