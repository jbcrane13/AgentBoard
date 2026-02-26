import Foundation
import Testing
@testable import AgentBoard

@Suite("TerminalLauncher Pure Functions")
struct TerminalLauncherTests {

    // MARK: - shellSingleQuoted

    @Test("shellSingleQuoted wraps plain string in single quotes")
    func shellSingleQuotedWrapsInSingleQuotes() {
        #expect(TerminalLauncher.shellSingleQuoted("hello") == "'hello'")
    }

    @Test("shellSingleQuoted escapes embedded single quote using quote-backslash-quote-quote idiom")
    func shellSingleQuotedHandlesEmbeddedSingleQuote() {
        // Implementation: replace ' with '\'' then wrap in single quotes
        // "it's" → 'it'\''s'
        #expect(TerminalLauncher.shellSingleQuoted("it's") == "'it'\\''s'")
    }

    @Test("shellSingleQuoted handles empty string")
    func shellSingleQuotedHandlesEmptyString() {
        #expect(TerminalLauncher.shellSingleQuoted("") == "''")
    }

    @Test("shellSingleQuoted handles spaces in string")
    func shellSingleQuotedHandlesSpaces() {
        #expect(TerminalLauncher.shellSingleQuoted("hello world") == "'hello world'")
    }

    @Test("shellSingleQuoted passes backslash through unchanged inside single quotes")
    func shellSingleQuotedHandlesBackslash() {
        // Backslashes have no special meaning inside single quotes — passed through verbatim
        #expect(TerminalLauncher.shellSingleQuoted("foo\\bar") == "'foo\\bar'")
    }

    // MARK: - generateITerm2Script

    @Test("generateITerm2Script contains the command string")
    func generateITerm2ScriptContainsCommand() {
        let command = "echo hello"
        let script = TerminalLauncher.generateITerm2Script(command: command)
        #expect(script.contains(command))
    }

    @Test("generateITerm2Script contains a project path when command includes a path")
    func generateITerm2ScriptContainsProjectPath() {
        let projectPath = "/Users/blake/Projects/AgentBoard"
        let command = "cd \(projectPath) && claude"
        let script = TerminalLauncher.generateITerm2Script(command: command)
        #expect(script.contains(projectPath))
    }

    // MARK: - generateTerminalScript

    @Test("generateTerminalScript contains the command string")
    func generateTerminalScriptContainsCommand() {
        let command = "echo hello"
        let script = TerminalLauncher.generateTerminalScript(command: command)
        #expect(script.contains(command))
    }

    @Test("generateTerminalScript contains AppleScript 'do script' keyword")
    func generateTerminalScriptContainsDoScript() {
        let script = TerminalLauncher.generateTerminalScript(command: "ls")
        #expect(script.contains("do script"))
    }
}
