#if os(macOS)
    import SwiftTerm
    import SwiftUI

    /// Embeds a SwiftTerm LocalProcessTerminalView that attaches to an existing
    /// tmux session by running `tmux attach-session -t <sessionID>`.
    /// If the session is not found, tmux prints its own error to the terminal before
    /// exiting — no extra error-handling code is required.
    struct InteractiveTerminalView: NSViewRepresentable {
        let sessionID: String

        func makeNSView(context _: Context) -> LocalProcessTerminalView {
            let terminalView = LocalProcessTerminalView(frame: .zero)
            terminalView.configureNativeColors()
            let socketPath = "/tmp/openclaw-tmux-sockets/openclaw.sock"

            // Build environment with Homebrew paths so tmux (and agent CLIs) are found.
            var env = ProcessInfo.processInfo.environment
            let extraPaths = ["/opt/homebrew/bin", "/opt/homebrew/sbin"]
            let currentPath = env["PATH"] ?? "/usr/bin:/bin"
            env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
            env["TERM"] = "xterm-256color"

            // Enable mouse mode + larger scrollback so the user can scroll up
            // in the embedded terminal. Then attach to the session.
            let shellCmd = [
                "tmux -S \(socketPath) set-option -g mouse on 2>/dev/null;",
                "tmux -S \(socketPath) set-option -g history-limit 10000 2>/dev/null;",
                "exec tmux -S \(socketPath) attach-session -t \(sessionID)"
            ].joined(separator: " ")

            terminalView.startProcess(
                executable: "/bin/sh",
                args: ["-c", shellCmd],
                environment: env.map { "\($0.key)=\($0.value)" },
                execName: nil
            )
            return terminalView
        }

        func updateNSView(_: LocalProcessTerminalView, context _: Context) {
            // SwiftTerm propagates NSView bounds changes to the PTY automatically.
        }
    }
#endif
