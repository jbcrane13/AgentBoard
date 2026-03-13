import SwiftUI
import SwiftTerm

/// Embeds a SwiftTerm LocalProcessTerminalView that attaches to an existing
/// tmux session by running `tmux attach-session -t <sessionID>`.
/// If the session is not found, tmux prints its own error to the terminal before
/// exiting — no extra error-handling code is required.
struct InteractiveTerminalView: NSViewRepresentable {
    let sessionID: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.configureNativeColors()
        let socketPath = "/tmp/openclaw-tmux-sockets/openclaw.sock"
        terminalView.startProcess(
            executable: "/usr/bin/env",
            args: ["tmux", "-S", socketPath, "attach-session", "-t", sessionID],
            environment: nil,
            execName: nil
        )
        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // SwiftTerm propagates NSView bounds changes to the PTY automatically.
    }
}
