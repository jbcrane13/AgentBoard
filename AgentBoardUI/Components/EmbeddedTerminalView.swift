#if os(macOS) && canImport(SwiftTerm)
    import AppKit
    import SwiftTerm
    import SwiftUI

    /// SwiftUI wrapper around SwiftTerm's `LocalProcessTerminalView`.
    /// Spawns the given executable inside a real PTY and renders an interactive terminal —
    /// keystrokes flow into the process, ANSI/colour output renders correctly.
    struct EmbeddedTerminalView: NSViewRepresentable {
        let executable: String
        let arguments: [String]
        let environment: [String]?
        let onProcessExit: (Int32) -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(onProcessExit: onProcessExit)
        }

        func makeNSView(context: Context) -> LocalProcessTerminalView {
            let terminal = LocalProcessTerminalView(frame: .zero)
            terminal.processDelegate = context.coordinator

            terminal.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            terminal.nativeBackgroundColor = NSColor(srgbRed: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
            terminal.nativeForegroundColor = NSColor(srgbRed: 0.86, green: 0.88, blue: 0.92, alpha: 1.0)

            let env = environment ?? Terminal.getEnvironmentVariables()
            terminal.startProcess(
                executable: executable,
                args: arguments,
                environment: env
            )
            return terminal
        }

        func updateNSView(_: LocalProcessTerminalView, context: Context) {
            context.coordinator.onProcessExit = onProcessExit
        }

        final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
            var onProcessExit: (Int32) -> Void

            init(onProcessExit: @escaping (Int32) -> Void) {
                self.onProcessExit = onProcessExit
            }

            func sizeChanged(source _: LocalProcessTerminalView, newCols _: Int, newRows _: Int) {}
            func setTerminalTitle(source _: LocalProcessTerminalView, title _: String) {}
            func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) {}

            func processTerminated(source _: TerminalView, exitCode: Int32?) {
                onProcessExit(exitCode ?? 0)
            }
        }
    }
#endif
