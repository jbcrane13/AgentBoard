@testable import AgentBoard
import Testing

@MainActor
struct SlashCommandServiceTests {
    @Test("resolve returns error for unknown command")
    func resolveUnknownCommand() {
        let service = SlashCommandService()
        let action = service.resolve("/doesnotexist")

        switch action {
        case .error(let message):
            #expect(message.contains("Unknown command"))
        default:
            Issue.record("Expected unknown command to return .error")
        }
    }

    @Test("resolve returns error for ambiguous prefix")
    func resolveAmbiguousPrefix() {
        let service = SlashCommandService()
        let action = service.resolve("/s")

        switch action {
        case .error(let message):
            #expect(message.contains("Unknown command"))
        default:
            Issue.record("Expected ambiguous command prefix to return .error")
        }
    }

    @Test("completions include matching subcommands")
    func subcommandCompletion() {
        let service = SlashCommandService()
        let completions = service.completions(for: "/issues v")

        #expect(completions.count == 1)
        #expect(completions.first?.command == "/issues view")
    }

    @Test("help text for command includes subcommands and arguments")
    func commandHelpText() {
        let service = SlashCommandService()
        let help = service.helpText(for: "issues")

        #expect(help.contains("Subcommands:"))
        #expect(help.contains("/view <number>"))
    }
}
