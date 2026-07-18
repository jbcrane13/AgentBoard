import AgentBoardCore
import Testing

@Suite("LiveTmuxController argument builders")
struct TmuxControllerTests {
    @Test func sendKeysArgumentsSendsLiteralTextThenSeparateEnter() {
        let commands = LiveTmuxController.sendKeysArguments(for: "ab-repo-1", text: "yes")

        #expect(commands.count == 2)

        let literalCall = commands[0]
        #expect(literalCall == [
            "-S", LiveTmuxController.tmuxSocketPath,
            "send-keys", "-t", "ab-repo-1", "-l", "yes"
        ])

        let enterCall = commands[1]
        #expect(enterCall.contains("Enter"))
        #expect(!enterCall.contains("-l"), "the Enter send must not carry the literal flag")
        #expect(enterCall == [
            "-S", LiveTmuxController.tmuxSocketPath,
            "send-keys", "-t", "ab-repo-1", "Enter"
        ])
    }

    @Test func killSessionArgumentsIncludesSocketAndTarget() {
        let arguments = LiveTmuxController.killSessionArguments(for: "ab-repo-2")

        #expect(arguments == [
            "-S", LiveTmuxController.tmuxSocketPath,
            "kill-session", "-t", "ab-repo-2"
        ])
    }
}
