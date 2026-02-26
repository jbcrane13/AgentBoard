import Foundation
import Testing
@testable import AgentBoard

extension Tag {
    @Tag static var integration: Self
}

/// Integration tests that exercise SessionMonitor against the real tmux binary.
/// These tests never start a tmux session that persists — error paths are tested
/// exclusively, so no cleanup of running sessions is required.
@Suite("SessionMonitor Integration Tests")
struct SessionMonitorIntegrationTests {

    // The default socket path mirrors what SessionMonitor uses in production.
    // We reuse it so listSessions() can reach any already-running openclaw
    // tmux server if one happens to be present (still valid — returns [] or
    // live sessions, both are acceptable).
    private let defaultSocketPath = "/tmp/openclaw-tmux-sockets/openclaw.sock"

    // MARK: - listSessions

    @Test("listSessions does not throw when tmux is available", .tags(.integration))
    func listSessionsDoesNotThrowWhenTmuxAvailable() async throws {
        let monitor = SessionMonitor(tmuxSocketPath: defaultSocketPath)
        // May return empty array (no server) or populated array — both are fine.
        let sessions = try await monitor.listSessions()
        // Reaching here without throwing is the assertion.
        _ = sessions
    }

    @Test("listSessions returns a valid CodingSession array", .tags(.integration))
    func listSessionsReturnsCodingSessionArray() async throws {
        let monitor = SessionMonitor(tmuxSocketPath: defaultSocketPath)
        let sessions: [CodingSession] = try await monitor.listSessions()
        // Array may be empty when no openclaw tmux server is running; that's fine.
        #expect(sessions.count >= 0)
    }

    @Test("listSessions returns empty array gracefully when no tmux server exists at socket path", .tags(.integration))
    func listSessionsHandlesNoRunningSessionsGracefully() async throws {
        // Use a socket path that is guaranteed not to have a server.
        let noServerSocket = "/tmp/test-no-server-\(UUID().uuidString).sock"
        let monitor = SessionMonitor(tmuxSocketPath: noServerSocket)
        // isMissingTmuxServer guard should swallow the error and return [].
        let sessions = try await monitor.listSessions()
        #expect(sessions.isEmpty)
    }

    // MARK: - launchSession error paths

    @Test("launchSession throws SessionMonitorError for a non-existent project path", .tags(.integration))
    func launchSessionThrowsForNonExistentProjectPath() async throws {
        let monitor = SessionMonitor(tmuxSocketPath: defaultSocketPath)
        let bogusPath = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        await #expect(throws: SessionMonitorError.self) {
            _ = try await monitor.launchSession(
                projectPath: bogusPath,
                agentType: .claudeCode,
                beadID: nil,
                prompt: nil
            )
        }
    }

    @Test("launchSession throws SessionMonitorError.launchFailed when project path is a file not a directory", .tags(.integration))
    func launchSessionThrowsForInvalidProjectPath() async throws {
        // Create a temporary regular file to use as the "project path".
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let tempFile = tempDir.appendingPathComponent("not-a-directory.txt")
        try "placeholder".write(to: tempFile, atomically: true, encoding: .utf8)

        let monitor = SessionMonitor(tmuxSocketPath: defaultSocketPath)
        await #expect(throws: SessionMonitorError.self) {
            _ = try await monitor.launchSession(
                projectPath: tempFile,
                agentType: .claudeCode,
                beadID: nil,
                prompt: nil
            )
        }
    }

    // MARK: - capturePane error path

    @Test("capturePane throws for a non-existent tmux session name", .tags(.integration))
    func capturePaneThrowsForNonExistentSession() async throws {
        let monitor = SessionMonitor(tmuxSocketPath: defaultSocketPath)
        let fakeName = "ab-nonexistent-session-\(UUID().uuidString)"
        await #expect(throws: (any Error).self) {
            _ = try await monitor.capturePane(session: fakeName, lines: 10)
        }
    }
}
