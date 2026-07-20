import AgentBoardCore
import SwiftUI

struct SessionTerminalView: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    let session: SessionLauncher.ActiveSession
    @Binding var isExpanded: Bool
    let onMinimize: () -> Void

    @State private var attachmentController = SessionAttachmentController()
    @State private var hasAttachedOnce = false
    @State private var fallbackTranscript: SessionTranscript?
    @State private var nudgeText = ""
    @State private var showKillConfirmation = false

    private var isReadOnly: Bool {
        if case .attachedInteractive = attachmentController.state { return false }
        return true
    }

    private var attachmentFailureMessage: String? {
        if case let .failed(message) = attachmentController.state { return message }
        return nil
    }

    private var showsAttachmentFallback: Bool {
        switch attachmentController.state {
        case .failed: true
        case .detached: hasAttachedOnce
        case .attachedReadOnly, .attachedInteractive: false
        }
    }

    private var matchingAgentSession: AgentSession? {
        appModel.sessionsStore.sessions.first { $0.tmuxSession == session.sessionName }
    }

    private var statusColor: Color {
        switch session.status {
        case .running: AppTheme.accentCyan
        case .completed: AppTheme.statusClosed
        case .failed: .red
        case .stalled: AppTheme.accentOrange
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
            AppBackground()

            VStack(spacing: 0) {
                header
                lifecycleErrorBanner

                #if os(macOS) && canImport(SwiftTerm)
                    if session.status == .running || session.status == .completed || session.status == .stalled {
                        nudgeBar
                    }
                #endif

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
        .accessibilityIdentifier("session_terminal_view")
        .task(id: session.sessionName) {
            attachmentController.attach(sessionName: session.sessionName)
            hasAttachedOnce = true
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
                .foregroundStyle(AppTheme.textPrimary)

            Text(session.preset.rawValue)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.accentOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.accentOrange.opacity(0.12))
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
                .foregroundStyle(AppTheme.accentCyan)

            Text(session.elapsed)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)

            if session.status == .running || session.status == .completed {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" :
                        "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(AppButtonStyle(isAccent: false))
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
                .buttonStyle(AppButtonStyle(isAccent: true))
                .accessibilityLabel("Open session in Terminal.app")
                .accessibilityIdentifier("session_terminal_open_terminal")

                #if os(macOS) && canImport(SwiftTerm)
                    Button {
                        if isReadOnly {
                            attachmentController.takeControl()
                        } else {
                            attachmentController.releaseControl()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isReadOnly ? "keyboard" : "keyboard.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(isReadOnly ? "Take Control" : "Release")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(AppButtonStyle(isAccent: !isReadOnly))
                    .disabled(showsAttachmentFallback)
                    .accessibilityLabel(isReadOnly ? "Take keyboard control of session" : "Release keyboard control")
                    .accessibilityIdentifier("session_button_takecontrol")
                #endif
            }

            #if os(macOS) && canImport(SwiftTerm)
                // Restart applies whenever AgentBoard launched the session (a stored
                // LaunchConfig exists) — including failed sessions, where it matters most.
                if appModel.sessionLauncher.canRelaunch(sessionName: session.sessionName) {
                    Button {
                        restart()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Restart")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(AppButtonStyle(isAccent: false))
                    .accessibilityLabel("Restart session")
                    .accessibilityIdentifier("session_button_restart")
                }

                // Kill applies to any still-alive tmux session, including stalled ones.
                if session.status == .running || session.status == .completed || session.status == .stalled {
                    Button {
                        showKillConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.octagon")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Kill")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(AppButtonStyle(isAccent: false))
                    .accessibilityLabel("Kill session")
                    .accessibilityIdentifier("session_button_kill")
                    .confirmationDialog(
                        "Kill this session?",
                        isPresented: $showKillConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Kill Session", role: .destructive) {
                            Task {
                                await appModel.sessionLauncher.killSession(sessionName: session.sessionName)
                                attachmentController.detach()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            #endif

            Button {
                attachmentController.detach()
                onMinimize()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Minimize session terminal")
            .accessibilityIdentifier("session_button_minimize")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // The spec calls for real glass on the terminal header, but this bar
        // packs several small status pills/buttons directly above a live
        // terminal backdrop that can scroll busy, high-contrast text — full
        // `glassEffect` risks legibility there, so this degrades to
        // `.thinMaterial` per the spec's explicit fallback. The terminal
        // content itself (`liveTerminalView`) stays fully opaque.
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.borderSoft)
                .frame(height: 1)
        }
    }

    // MARK: - Live Terminal

    @ViewBuilder
    private var terminalContentView: some View {
        #if os(macOS) && canImport(SwiftTerm)
            if showsAttachmentFallback {
                attachmentFallbackView
            } else {
                liveTerminalView
            }
        #else
            VStack(spacing: 12) {
                Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Interactive terminal is available on macOS only")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    #if os(macOS) && canImport(SwiftTerm)
        @ViewBuilder
        private var liveTerminalView: some View {
            let readOnly = isReadOnly
            let attach = SessionLauncher.attachCommand(for: session.sessionName, readOnly: readOnly)
            let sessionName = session.sessionName

            VStack(spacing: 0) {
                if !readOnly {
                    interactiveBanner
                }

                EmbeddedTerminalView(
                    executable: attach.executable,
                    arguments: attach.arguments,
                    environment: nil,
                    isInputEnabled: !readOnly,
                    onProcessExit: { _ in
                        attachmentController.handleProcessExit(sessionName: sessionName, wasReadOnly: readOnly)
                    }
                )
                .id("\(sessionName)-\(readOnly ? "ro" : "rw")")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.06, green: 0.06, blue: 0.08))
                .accessibilityIdentifier("session_terminal_embedded")
            }
        }

        private var interactiveBanner: some View {
            HStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .font(.caption.weight(.bold))
                Text("Keyboard input live")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(AppTheme.accentCyan)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.accentCyan.opacity(0.12))
        }

        private var transcriptContent: String {
            guard let content = fallbackTranscript?.content, !content.isEmpty else {
                return "No transcript available yet"
            }
            return content
        }

        private var attachmentFallbackView: some View {
            VStack(spacing: 16) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(attachmentFailureMessage != nil ? "Attachment Failed" : "Session Ended")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if let message = attachmentFailureMessage {
                    Text(message)
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                ScrollView(showsIndicators: false) {
                    Text(transcriptContent)
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .insetSurface(cornerRadius: 16, depth: 6)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("session_transcript_view")
            .task(id: matchingAgentSession?.id) {
                guard let agentSessionID = matchingAgentSession?.id else { return }
                fallbackTranscript = await appModel.sessionsStore.fetchTranscript(sessionID: agentSessionID)
            }
        }
    #endif
}

// MARK: - Failed / Stalled States

private extension SessionTerminalView {
    var failedStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Session Failed")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("The agent session encountered an error and could not continue.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if let error = appModel.sessionLauncher.lastError {
                Text(error)
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.textTertiary)
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
                .buttonStyle(AppButtonStyle(isAccent: true))
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
                .buttonStyle(AppButtonStyle(isAccent: false))
                .accessibilityLabel("Close failed session view")
                .accessibilityIdentifier("session_terminal_failed_close")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var stalledStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accentOrange)

            Text("Session Stalled")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("The agent session appears to be inactive. It may have stopped producing output.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
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
                .buttonStyle(AppButtonStyle(isAccent: true))
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
                .buttonStyle(AppButtonStyle(isAccent: false))
                .accessibilityLabel("Close stalled session view")
                .accessibilityIdentifier("session_terminal_stalled_close")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lifecycle controls (nudge, restart, kill)

private extension SessionTerminalView {
    @ViewBuilder
    var lifecycleErrorBanner: some View {
        if session.status != .failed, let message = appModel.sessionLauncher.lastError {
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
        }
    }
}

#if os(macOS) && canImport(SwiftTerm)
    fileprivate extension SessionTerminalView {
        var nudgeBar: some View {
            HStack(spacing: 8) {
                TextField("Nudge session...", text: $nudgeText)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.textPrimary)
                    .onSubmit { sendNudge() }
                    .accessibilityIdentifier("session_textfield_nudge")

                Button {
                    sendNudge()
                } label: {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(AppButtonStyle(isAccent: true))
                .disabled(nudgeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send nudge to session")
                .accessibilityIdentifier("session_button_nudge_send")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(AppTheme.surface.opacity(0.6))
        }

        func sendNudge() {
            let text = nudgeText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            nudgeText = ""
            let sessionName = session.sessionName
            Task { await appModel.sessionLauncher.sendKeys(sessionName: sessionName, text: text) }
        }

        func restart() {
            let sessionName = session.sessionName
            attachmentController.detach()
            Task {
                if let newName = await appModel.sessionLauncher.relaunch(sessionName: sessionName) {
                    attachmentController.attach(sessionName: newName)
                }
            }
        }
    }
#endif
