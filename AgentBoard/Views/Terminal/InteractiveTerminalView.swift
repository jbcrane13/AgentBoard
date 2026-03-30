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

            terminalView.startProcess(
                executable: "/usr/bin/env",
                args: ["tmux", "-S", socketPath, "attach-session", "-t", sessionID],
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
