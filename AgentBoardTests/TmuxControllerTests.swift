import AgentBoardCore
import Foundation
import Testing

@Suite("LiveTmuxController argument builders")
struct TmuxControllerTests {
    @Test func prepareWorkspaceCreatesAndReusesIsolatedGitWorktree() async throws {
        let identifier = UUID().uuidString.lowercased()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentBoard-worktree-test-\(identifier)", isDirectory: true)
        let remote = root.appendingPathComponent("remote.git", isDirectory: true)
        let canonical = root.appendingPathComponent("canonical-\(identifier)", isDirectory: true)
        let sessionName = "ab-worktree-test-\(identifier)"
        let expectedWorkspace = LiveTmuxController.workspacePath(
            repoPath: canonical.path,
            sessionName: sessionName
        )
        defer {
            _ = try? runGit(["-C", canonical.path, "worktree", "remove", "--force", expectedWorkspace])
            _ = try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try runGit(["init", "--bare", "--initial-branch=main", remote.path])
        try runGit(["init", "--initial-branch=main", canonical.path])
        try runGit(["-C", canonical.path, "config", "user.email", "tests@agentboard.local"])
        try runGit(["-C", canonical.path, "config", "user.name", "AgentBoard Tests"])
        try "seed\n".write(
            to: canonical.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        try runGit(["-C", canonical.path, "add", "README.md"])
        try runGit(["-C", canonical.path, "commit", "-m", "seed"])
        try runGit(["-C", canonical.path, "remote", "add", "origin", remote.path])
        try runGit(["-C", canonical.path, "push", "-u", "origin", "main"])
        try runGit(["-C", canonical.path, "remote", "set-head", "origin", "main"])

        let controller = LiveTmuxController()
        let firstWorkspace = try await controller.prepareWorkspace(
            name: sessionName,
            repoPath: canonical.path
        )
        let reusedWorkspace = try await controller.prepareWorkspace(
            name: sessionName,
            repoPath: canonical.path
        )

        #expect(firstWorkspace == expectedWorkspace)
        #expect(reusedWorkspace == expectedWorkspace)
        #expect(
            try runGit(["-C", expectedWorkspace, "branch", "--show-current"])
                .trimmingCharacters(in: .whitespacesAndNewlines) ==
                LiveTmuxController.workspaceBranch(for: sessionName)
        )
    }

    @Test func workspaceIdentityIsStableAndSessionSpecific() {
        let home = URL(fileURLWithPath: "/tmp/test-home", isDirectory: true)

        #expect(
            LiveTmuxController.workspacePath(
                repoPath: "/Users/test/Projects/LeadFeed",
                sessionName: "ab-leadscout-54",
                homeDirectory: home
            ) == "/tmp/test-home/.agentboard/worktrees/LeadFeed/ab-leadscout-54"
        )
        #expect(
            LiveTmuxController.workspaceBranch(for: "ab-leadscout-54") ==
                "agentboard/ab-leadscout-54"
        )
    }

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

    @discardableResult
    private func runGit(_ arguments: [String]) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let output = String(
            data: stdout.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        guard process.terminationStatus == 0 else {
            let error = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            throw GitTestError.commandFailed(error)
        }
        return output
    }
}

private enum GitTestError: Error {
    case commandFailed(String)
}
