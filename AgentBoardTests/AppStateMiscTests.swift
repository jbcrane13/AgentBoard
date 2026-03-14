import Foundation
import Testing
@testable import AgentBoard

/// Thread-safe mutable container for test assertions.
private final class LockIsolated<Value>: @unchecked Sendable {
    private var _value: Value
    private let lock = NSLock()
    init(_ value: Value) { _value = value }
    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&_value)
    }
}

@Suite("AppState Misc")
@MainActor
struct AppStateMiscTests {

    @Test("sendChatMessage with empty string does not append any messages")
    func sendChatMessageEmptyStringDoesNothing() async {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        await state.sendChatMessage("")
        #expect(state.chatMessages.isEmpty)
    }

    @Test("sendChatMessage with whitespace-only string does not append any messages")
    func sendChatMessageWhitespaceDoesNothing() async {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        await state.sendChatMessage("   \n  ")
        #expect(state.chatMessages.isEmpty)
    }

    @Test("sendChatMessage appends a user message and an assistant placeholder")
    func sendChatMessageAppendsUserAndAssistantMessages() async {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        await state.sendChatMessage("hello")
        #expect(state.chatMessages.count >= 2)
        #expect(state.chatMessages[0].role == .user)
        #expect(state.chatMessages[0].content == "hello")
        #expect(state.chatMessages[1].role == .assistant)
    }

    @Test("dismissConnectionErrorToast sets showConnectionErrorToast to false")
    func dismissConnectionErrorToastSetsToFalse() {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        state.showConnectionErrorToast = true
        state.dismissConnectionErrorToast()
        #expect(state.showConnectionErrorToast == false)
    }

    @Test("clearUnreadChatCount resets unreadChatCount to zero")
    func clearUnreadChatCountResetsToZero() {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        state.unreadChatCount = 5
        state.clearUnreadChatCount()
        #expect(state.unreadChatCount == 0)
    }

    @Test("gitSummary returns summary for known bead ID and nil for unknown")
    func gitSummaryForBeadID() {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        let commit = GitCommitRecord(
            sha: "abc123def456",
            shortSHA: "abc123d",
            authoredAt: Date(),
            subject: "test",
            refs: "",
            branch: "main",
            beadIDs: ["AB-1"]
        )
        let summary = BeadGitSummary(beadID: "AB-1", latestCommit: commit, commitCount: 1)
        state.beadGitSummaries["AB-1"] = summary

        #expect(state.gitSummary(for: "AB-1") != nil)
        #expect(state.gitSummary(for: "MISSING") == nil)
    }

    @Test("updateOpenClaw writes config and sets statusMessage")
    func updateOpenClawWritesConfigAndStatus() {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        state.updateOpenClaw(gatewayURL: "http://localhost:8080", token: "secret-token", source: "manual")

        #expect(state.appConfig.openClawGatewayURL == "http://localhost:8080")
        #expect(state.appConfig.openClawToken == "secret-token")
        #expect(state.appConfig.gatewayConfigSource == "manual")
        #expect(state.statusMessage == "Saved OpenClaw settings.")
    }

    @Test("updateBead to done calls bd close and does not pass --status")
    func updateBeadToDonesCallsBdClose() async {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true)

        // Capture all commands issued by updateBead
        let capturedCommands = LockIsolated<[[String]]>([])
        let state = AppState(
            configStore: AppConfigStore(directory: _d),
            bootstrapOnInit: false,
            startBackgroundLoops: false,
            commandRunner: { args, _ in
                capturedCommands.withLock { $0.append(args) }
                return ShellCommandResult(exitCode: 0, stdout: "[]", stderr: "")
            }
        )

        // Set up a project and select it
        let projectDir = _d.appendingPathComponent("proj")
        try! FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let beadsDir = projectDir.appendingPathComponent(".beads")
        try! FileManager.default.createDirectory(at: beadsDir, withIntermediateDirectories: true)
        let project = Project(
            id: UUID(), name: "Test", path: projectDir, beadsPath: beadsDir,
            icon: "T", isActive: true, openCount: 1, inProgressCount: 0, totalCount: 1
        )
        state.projects = [project]
        state.selectedProjectID = project.id

        // Create a bead with status open
        let bead = Bead(
            id: "AB-test1", title: "Test bead", body: nil, status: .open,
            kind: .task, priority: 2, epicId: nil, labels: [], assignee: nil,
            createdAt: Date(), updatedAt: Date(), dependencies: [],
            gitBranch: nil, lastCommit: nil
        )

        // Draft with status changed to done
        var draft = BeadDraft.from(bead)
        draft.status = .done

        await state.updateBead(bead, with: draft)

        let commands = capturedCommands.withLock { $0 }

        // (1) bd close <id> must have been called
        let closeCommand = commands.first { $0.starts(with: ["bd", "close"]) }
        #expect(closeCommand != nil, "Expected 'bd close' to be called")
        #expect(closeCommand?.contains("AB-test1") == true)

        // (2) The bd update call must NOT contain --status (since bd close handles it)
        let updateCommand = commands.first { $0.starts(with: ["bd", "update"]) }
        #expect(updateCommand != nil, "Expected 'bd update' to be called for other fields")
        #expect(updateCommand?.contains("--status") == false,
                "bd update must NOT pass --status when closing via bd close")
    }

    @Test("updateOpenClaw with empty strings sets config fields to nil")
    func updateOpenClawEmptyStringSetsNil() {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        state.appConfig.openClawGatewayURL = "http://old.com"
        state.appConfig.openClawToken = "old-token"

        state.updateOpenClaw(gatewayURL: "", token: "", source: "manual")

        #expect(state.appConfig.openClawGatewayURL == nil)
        #expect(state.appConfig.openClawToken == nil)
        #expect(state.statusMessage == "Saved OpenClaw settings.")
    }
}
