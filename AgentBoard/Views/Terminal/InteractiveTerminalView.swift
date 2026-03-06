import SwiftUI
import SwiftTerm

/// Embeds a SwiftTerm LocalProcessTerminalView that attaches to an existing
/// tmux session by running `tmux attach-session -t <sessionID>`.
/// If the session is not found, tmux prints its own error to the terminal before
/// exiting — no extra error-handling code is required.
struct InteractiveTerminalView: NSViewRepresentable {
    let sessionID: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: .zero)
        tv.configureNativeColors()
        tv.startProcess(
            executable: "/usr/bin/env",
            args: ["tmux", "attach-session", "-t", sessionID],
            environment: nil,
            execName: nil
        )
        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // SwiftTerm propagates NSView bounds changes to the PTY automatically.
    }
}
