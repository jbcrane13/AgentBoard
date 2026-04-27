import AgentBoardCore
import Testing

@Suite("SlashCommandHandler")
struct SlashCommandHandlerTests {
    // MARK: - Local commands

    @Test func helpCommandReturnsShowHelp() {
        #expect(SlashCommandHandler.handle("/help") == .showHelp)
    }

    @Test func commandsAliasReturnsShowHelp() {
        #expect(SlashCommandHandler.handle("/commands") == .showHelp)
    }

    @Test func newCommandReturnsNewConversation() {
        #expect(SlashCommandHandler.handle("/new") == .newConversation)
    }

    @Test func clearCommandReturnsClearConversation() {
        #expect(SlashCommandHandler.handle("/clear") == .clearConversation)
    }

    @Test func statusCommandReturnsShowStatus() {
        #expect(SlashCommandHandler.handle("/status") == .showStatus)
    }

    @Test func configCommandReturnsShowConfig() {
        #expect(SlashCommandHandler.handle("/config") == .showConfig)
    }

    @Test func modelWithArgumentReturnsSwitchModel() {
        let result = SlashCommandHandler.handle("/model hermes-pro")
        #expect(result == .switchModel("hermes-pro"))
    }

    @Test func modelWithoutArgumentReturnsShowStatus() {
        #expect(SlashCommandHandler.handle("/model") == .showStatus)
    }

    @Test func modelWithExtraSpacesTrimsArgument() {
        let result = SlashCommandHandler.handle("/model   hermes-pro   ")
        #expect(result == .switchModel("hermes-pro"))
    }

    // MARK: - Passthrough commands

    @Test("Passthrough commands are forwarded unchanged", arguments: ["/retry", "/compress", "/stop", "/compact"])
    func passthroughCommandsForward(command: String) {
        #expect(SlashCommandHandler.handle(command) == .passthrough)
    }

    // MARK: - Unknown commands

    @Test func unknownCommandReturnsUnknown() {
        let result = SlashCommandHandler.handle("/foo")
        if case let .unknown(cmd) = result {
            #expect(cmd == "/foo")
        } else {
            Issue.record("Expected .unknown, got \(result)")
        }
    }

    @Test func unknownCommandWithArgumentReturnsUnknown() {
        let result = SlashCommandHandler.handle("/foo bar baz")
        if case let .unknown(cmd) = result {
            #expect(cmd == "/foo")
        } else {
            Issue.record("Expected .unknown")
        }
    }

    // MARK: - Case insensitivity

    @Test func commandsAreCaseInsensitive() {
        #expect(SlashCommandHandler.handle("/HELP") == .showHelp)
        #expect(SlashCommandHandler.handle("/New") == .newConversation)
        #expect(SlashCommandHandler.handle("/CLEAR") == .clearConversation)
    }

    // MARK: - Non-slash input

    @Test func nonSlashInputIsPassthrough() {
        #expect(SlashCommandHandler.handle("hello") == .passthrough)
        #expect(SlashCommandHandler.handle("") == .passthrough)
    }

    // MARK: - Whitespace handling

    @Test func leadingWhitespaceIsHandled() {
        // trimming happens in ChatStore before calling handler, but let's verify behavior
        let result = SlashCommandHandler.handle("  /help")
        // Does not start with "/" after trim check inside handler — it checks the raw string
        // The handler checks hasPrefix("/") on the trimmed value
        #expect(result == .passthrough) // leading space means not a slash command
    }

    // MARK: - Format helpers

    @Test func formatHelpContainsAllCommands() {
        let help = SlashCommandHandler.formatHelp()
        #expect(help.contains("/help"))
        #expect(help.contains("/new"))
        #expect(help.contains("/clear"))
        #expect(help.contains("/model"))
        #expect(help.contains("/status"))
        #expect(help.contains("/config"))
    }

    @Test func formatStatusIncludesAllFields() {
        let status = SlashCommandHandler.formatStatus(
            connectionState: "Connected",
            model: "hermes-pro",
            conversationTitle: "Test Chat",
            messageCount: 5
        )
        #expect(status.contains("Connected"))
        #expect(status.contains("hermes-pro"))
        #expect(status.contains("Test Chat"))
        #expect(status.contains("5"))
    }

    @Test func formatConfigIncludesURLAndModel() {
        let config = SlashCommandHandler.formatConfig(
            gatewayURL: "http://127.0.0.1:8642",
            model: "hermes-agent",
            hasAPIKey: true,
            repos: ["jbcrane13/AgentBoard", "jbcrane13/GrowWise"]
        )
        #expect(config.contains("http://127.0.0.1:8642"))
        #expect(config.contains("hermes-agent"))
        #expect(config.contains("Set"))
        #expect(config.contains("jbcrane13/AgentBoard"))
        #expect(config.contains("jbcrane13/GrowWise"))
    }

    @Test func formatConfigWithNoReposOmitsRepoSection() {
        let config = SlashCommandHandler.formatConfig(
            gatewayURL: "http://127.0.0.1:8642",
            model: "hermes-agent",
            hasAPIKey: false,
            repos: []
        )
        #expect(config.contains("Not set"))
        #expect(!config.contains("Repositories"))
    }

    // MARK: - New toggle / mode commands

    @Test func skillsCommandReturnsShowSkills() {
        #expect(SlashCommandHandler.handle("/skills") == .showSkills)
    }

    @Test func memoryCommandReturnsShowMemory() {
        #expect(SlashCommandHandler.handle("/memory") == .showMemory)
    }

    @Test func toolsCommandReturnsShowTools() {
        #expect(SlashCommandHandler.handle("/tools") == .showTools)
    }

    @Test func thinkCommandReturnsToggleThinking() {
        #expect(SlashCommandHandler.handle("/think") == .toggleThinking)
    }

    @Test func webCommandReturnsToggleWeb() {
        #expect(SlashCommandHandler.handle("/web") == .toggleWeb)
    }

    @Test func codeCommandReturnsToggleCode() {
        #expect(SlashCommandHandler.handle("/code") == .toggleCode)
    }

    @Test func imageCommandReturnsToggleImage() {
        #expect(SlashCommandHandler.handle("/image") == .toggleImage)
    }

    @Test func speakCommandReturnsToggleSpeak() {
        #expect(SlashCommandHandler.handle("/speak") == .toggleSpeak)
    }

    @Test func resetCommandReturnsResetConversation() {
        #expect(SlashCommandHandler.handle("/reset") == .resetConversation)
    }

    @Test func skillWithNameReturnsActivateSkill() {
        let result = SlashCommandHandler.handle("/skill my-skill")
        #expect(result == .activateSkill("my-skill"))
    }

    @Test func skillWithoutNameIsPassthrough() {
        #expect(SlashCommandHandler.handle("/skill") == .passthrough)
    }

    // MARK: - SlashCommand struct

    @Test func slashCommandIDMatchesName() {
        let cmd = SlashCommand(name: "/test", description: "A test", category: .local)
        #expect(cmd.id == "/test")
    }

    @Test func slashCommandDefaultUsageMatchesName() {
        let cmd = SlashCommand(name: "/test", description: "A test", category: .local)
        #expect(cmd.usage == "/test")
    }

    @Test func slashCommandCustomUsage() {
        let cmd = SlashCommand(name: "/model", description: "Switch", category: .local, usage: "/model <name>")
        #expect(cmd.usage == "/model <name>")
    }

    // MARK: - builtInCommands / allCommands

    @Test func builtInCommandsIsNonEmpty() {
        #expect(!SlashCommandHandler.builtInCommands.isEmpty)
    }

    @Test func allCommandsIncludesSkillCommands() {
        let skill = SlashCommand(name: "/summarize", description: "Summarize", category: .skill)
        let all = SlashCommandHandler.allCommands(skills: [skill])
        #expect(all.contains(skill))
    }

    // MARK: - commands(matching:) prefix filter

    @Test func commandsMatchingFiltersCorrectly() {
        let matches = SlashCommandHandler.commands(matching: "/st")
        let names = matches.map(\.name)
        #expect(names.contains("/status"))
        #expect(names.contains("/stop"))
        // Should not include unrelated commands
        #expect(!names.contains("/help"))
    }

    @Test func commandsMatchingIncludesSkills() {
        let skill = SlashCommand(name: "/summarize", description: "Sum", category: .skill)
        let matches = SlashCommandHandler.commands(matching: "/su", skills: [skill])
        #expect(matches.contains(skill))
    }

    @Test func commandsMatchingReturnsEmptyForNoMatch() {
        let matches = SlashCommandHandler.commands(matching: "/zzz")
        #expect(matches.isEmpty)
    }

    // MARK: - formatHelp includes new commands

    @Test func formatHelpIncludesNewCommands() {
        let help = SlashCommandHandler.formatHelp()
        #expect(help.contains("/skills"))
        #expect(help.contains("/think"))
        #expect(help.contains("/reset"))
    }
}
