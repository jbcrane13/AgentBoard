import Foundation

/// Tracks the macOS live-terminal attachment to a single tmux session at a time.
/// The controller never spawns a process itself — it only publishes the desired
/// attachment state; the terminal view owns the real PTY and reports back via
/// `handleProcessExit`.
@MainActor
@Observable
public final class SessionAttachmentController {
    public enum AttachmentState: Equatable, Sendable {
        case detached
        case attachedReadOnly(sessionName: String)
        case attachedInteractive(sessionName: String)
        case failed(message: String)
    }

    public private(set) var state: AttachmentState = .detached

    public init() {}

    /// Attaches read-only to `sessionName`. Attaching always replaces any
    /// existing attachment — only one session is attached at a time.
    public func attach(sessionName: String) {
        state = .attachedReadOnly(sessionName: sessionName)
    }

    /// Switches the current read-only attachment to interactive (read-write).
    /// No-op unless currently attached read-only.
    public func takeControl() {
        guard case let .attachedReadOnly(sessionName) = state else { return }
        state = .attachedInteractive(sessionName: sessionName)
    }

    /// Switches the current interactive attachment back to read-only.
    /// No-op unless currently attached interactively.
    public func releaseControl() {
        guard case let .attachedInteractive(sessionName) = state else { return }
        state = .attachedReadOnly(sessionName: sessionName)
    }

    /// Terminates the current attachment. Only the local tmux client is
    /// affected — the tmux session itself keeps running.
    public func detach() {
        state = .detached
    }

    /// Records an attach/re-attach failure (session gone, tmux missing, etc).
    public func fail(message: String) {
        state = .failed(message: message)
    }

    /// Called by the view layer when the underlying client PTY exits.
    /// A client PTY is torn down for reasons other than the session actually
    /// ending — most notably, taking/releasing control tears down the old
    /// client to respawn the new one. Only honor the exit if `state` still
    /// reflects the exact attachment (`sessionName`, `wasReadOnly`) that PTY
    /// was spawned for; otherwise it's a stale signal from an attachment
    /// that has already moved on.
    public func handleProcessExit(sessionName: String, wasReadOnly: Bool) {
        switch state {
        case let .attachedReadOnly(name) where wasReadOnly && name == sessionName:
            state = .detached
        case let .attachedInteractive(name) where !wasReadOnly && name == sessionName:
            state = .detached
        default:
            break
        }
    }

    /// Pure tmux argument builder for attaching to `sessionName`. `-r` enforces
    /// read-only at the tmux server itself — the UI's own keystroke swallowing
    /// is defense in depth, not the safety mechanism.
    public nonisolated static func attachArguments( // swiftlint:disable:this modifier_order
        sessionName: String,
        readOnly: Bool
    ) -> [String] {
        readOnly
            ? ["attach-session", "-r", "-t", sessionName]
            : ["attach-session", "-t", sessionName]
    }
}
