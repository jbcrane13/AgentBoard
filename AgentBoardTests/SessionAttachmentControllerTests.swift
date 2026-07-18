import AgentBoardCore
import Testing

@Suite("SessionAttachmentController")
@MainActor
struct SessionAttachmentControllerTests {
    // MARK: - attachArguments (pure)

    @Test("attachArguments read-only includes -r")
    func attachArgumentsReadOnly() {
        let args = SessionAttachmentController.attachArguments(sessionName: "ab-repo-1", readOnly: true)
        #expect(args == ["attach-session", "-r", "-t", "ab-repo-1"])
    }

    @Test("attachArguments interactive omits -r")
    func attachArgumentsInteractive() {
        let args = SessionAttachmentController.attachArguments(sessionName: "ab-repo-1", readOnly: false)
        #expect(args == ["attach-session", "-t", "ab-repo-1"])
    }

    // MARK: - State machine

    @Test func initialStateIsDetached() {
        let controller = SessionAttachmentController()
        #expect(controller.state == .detached)
    }

    @Test func attachEntersReadOnlyState() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        #expect(controller.state == .attachedReadOnly(sessionName: "ab-repo-1"))
    }

    @Test func attachingASecondSessionDetachesTheFirst() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.attach(sessionName: "ab-repo-2")
        #expect(controller.state == .attachedReadOnly(sessionName: "ab-repo-2"))
    }

    @Test func takeControlSwitchesToInteractive() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.takeControl()
        #expect(controller.state == .attachedInteractive(sessionName: "ab-repo-1"))
    }

    @Test func takeControlIsNoOpWhenNotReadOnly() {
        let controller = SessionAttachmentController()
        controller.takeControl()
        #expect(controller.state == .detached)
    }

    @Test func releaseControlSwitchesBackToReadOnly() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.takeControl()
        controller.releaseControl()
        #expect(controller.state == .attachedReadOnly(sessionName: "ab-repo-1"))
    }

    @Test func releaseControlIsNoOpWhenNotInteractive() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.releaseControl()
        #expect(controller.state == .attachedReadOnly(sessionName: "ab-repo-1"))
    }

    @Test func detachReturnsToDetachedFromAnyState() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.takeControl()
        controller.detach()
        #expect(controller.state == .detached)
    }

    @Test func failRecordsMessage() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.fail(message: "tmux missing")
        #expect(controller.state == .failed(message: "tmux missing"))
    }

    // MARK: - handleProcessExit

    @Test func handleProcessExitDetachesOnMatchingReadOnlyExit() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.handleProcessExit(sessionName: "ab-repo-1", wasReadOnly: true)
        #expect(controller.state == .detached)
    }

    @Test func handleProcessExitDetachesOnMatchingInteractiveExit() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.takeControl()
        controller.handleProcessExit(sessionName: "ab-repo-1", wasReadOnly: false)
        #expect(controller.state == .detached)
    }

    @Test("Stale exit from a superseded read-only client is ignored after Take Control")
    func handleProcessExitIgnoresStaleReadOnlyExitAfterTakeControl() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.takeControl()
        // The old read-only PTY's delayed exit callback arrives after the swap.
        controller.handleProcessExit(sessionName: "ab-repo-1", wasReadOnly: true)
        #expect(controller.state == .attachedInteractive(sessionName: "ab-repo-1"))
    }

    @Test("Stale exit for a different session name is ignored")
    func handleProcessExitIgnoresExitForDifferentSession() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.handleProcessExit(sessionName: "ab-repo-2", wasReadOnly: true)
        #expect(controller.state == .attachedReadOnly(sessionName: "ab-repo-1"))
    }

    @Test func handleProcessExitIsNoOpWhenDetached() {
        let controller = SessionAttachmentController()
        controller.handleProcessExit(sessionName: "ab-repo-1", wasReadOnly: true)
        #expect(controller.state == .detached)
    }

    @Test func handleProcessExitIsNoOpWhenFailed() {
        let controller = SessionAttachmentController()
        controller.attach(sessionName: "ab-repo-1")
        controller.fail(message: "boom")
        controller.handleProcessExit(sessionName: "ab-repo-1", wasReadOnly: true)
        #expect(controller.state == .failed(message: "boom"))
    }
}
