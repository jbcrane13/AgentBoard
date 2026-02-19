import Foundation
import SwiftUI
import Testing
@testable import AgentBoard

@Suite("Model Coverage")
struct ModelCoverageTests {
    @Test("ChatMessage init and computed properties")
    func chatMessageInitAndComputedProperties() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let content = """
        Review AgentBoard-69u and AgentBoard-69u.1.
        Duplicate mention AgentBoard-69u.
        ```swift
        print("hi")
        ```
        """

        let message = ChatMessage(
            id: id,
            role: .assistant,
            content: content,
            timestamp: timestamp,
            beadContext: "AgentBoard-69u",
            sentToCanvas: true
        )

        #expect(message.id == id)
        #expect(message.role == .assistant)
        #expect(message.timestamp == timestamp)
        #expect(message.beadContext == "AgentBoard-69u")
        #expect(message.sentToCanvas)
        #expect(message.referencedIssueIDs == ["AgentBoard-69u", "AgentBoard-69u.1"])
        #expect(message.hasCodeBlock)
    }

    @Test("BeadStatus mapping and beadsValue")
    func beadStatusMapping() {
        #expect(BeadStatus.fromBeads("open") == .open)
        #expect(BeadStatus.fromBeads("in_progress") == .inProgress)
        #expect(BeadStatus.fromBeads("in-progress") == .inProgress)
        #expect(BeadStatus.fromBeads("blocked") == .blocked)
        #expect(BeadStatus.fromBeads("done") == .done)
        #expect(BeadStatus.fromBeads("closed") == .done)
        #expect(BeadStatus.fromBeads("unknown") == .open)

        #expect(BeadStatus.open.beadsValue == "open")
        #expect(BeadStatus.inProgress.beadsValue == "in_progress")
        #expect(BeadStatus.blocked.beadsValue == "blocked")
        #expect(BeadStatus.done.beadsValue == "closed")
    }

    @Test("BeadKind mapping and beadsValue")
    func beadKindMapping() {
        #expect(BeadKind.fromBeads("bug") == .bug)
        #expect(BeadKind.fromBeads("feature") == .feature)
        #expect(BeadKind.fromBeads("enhancement") == .feature)
        #expect(BeadKind.fromBeads("epic") == .epic)
        #expect(BeadKind.fromBeads("anything-else") == .task)
        #expect(BeadKind.fromBeads(nil) == .task)

        #expect(BeadKind.task.beadsValue == "task")
        #expect(BeadKind.bug.beadsValue == "bug")
        #expect(BeadKind.feature.beadsValue == "feature")
        #expect(BeadKind.epic.beadsValue == "epic")
    }

    @Test("Bead Codable round-trip")
    func beadCodableRoundTrip() throws {
        let bead = Bead(
            id: "AB-1",
            title: "Implement tests",
            body: "Body",
            status: .inProgress,
            kind: .feature,
            epicId: "AB-EPIC",
            labels: ["test", "swift"],
            assignee: "codex",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_123),
            dependencies: ["AB-0"],
            gitBranch: "feat/tests",
            lastCommit: "abcdef1"
        )

        let data = try JSONEncoder().encode(bead)
        let decoded = try JSONDecoder().decode(Bead.self, from: data)
        #expect(decoded == bead)
    }

    @Test("BeadDraft labels parsing and from(bead)")
    func beadDraftParsingAndMapping() {
        var draft = BeadDraft()
        draft.labelsText = " ios,  swift , , tests ,"
        #expect(draft.labels == ["ios", "swift", "tests"])

        let bead = Bead(
            id: "AB-2",
            title: "Title",
            body: nil,
            status: .blocked,
            kind: .bug,
            epicId: "AB-EPIC",
            labels: ["one", "two"],
            assignee: nil,
            createdAt: .distantPast,
            updatedAt: .distantPast,
            dependencies: [],
            gitBranch: nil,
            lastCommit: nil
        )

        let mapped = BeadDraft.from(bead)
        #expect(mapped.title == "Title")
        #expect(mapped.description.isEmpty)
        #expect(mapped.kind == .bug)
        #expect(mapped.status == .blocked)
        #expect(mapped.assignee.isEmpty)
        #expect(mapped.labelsText == "one, two")
        #expect(mapped.epicId == "AB-EPIC")
    }

    @Test("Project issues file URL")
    func projectIssuesFileURL() {
        let project = Project(
            id: UUID(),
            name: "AgentBoard",
            path: URL(fileURLWithPath: "/tmp/AgentBoard"),
            beadsPath: URL(fileURLWithPath: "/tmp/AgentBoard/.beads"),
            icon: "📁",
            isActive: false,
            openCount: 0,
            inProgressCount: 0,
            totalCount: 0
        )

        #expect(project.issuesFileURL.path == "/tmp/AgentBoard/.beads/issues.jsonl")
    }

    @Test("AppConfig computed properties and Codable")
    func appConfigComputedPropertiesAndCodable() throws {
        var config = AppConfig.empty
        #expect(!config.isGatewayManual)

        config.gatewayConfigSource = "manual"
        #expect(config.isGatewayManual)

        let customPath = "/tmp/AgentBoardProjects"
        config.projectsDirectory = customPath
        #expect(config.resolvedProjectsDirectory.path == customPath)

        let homeProjects = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Projects", isDirectory: true).path
        config.projectsDirectory = nil
        #expect(config.resolvedProjectsDirectory.path == homeProjects)

        let configured = ConfiguredProject(path: "/tmp/AgentBoard", icon: "📁")
        let codableConfig = AppConfig(
            projects: [configured],
            selectedProjectPath: configured.path,
            openClawGatewayURL: "http://127.0.0.1:18789",
            openClawToken: "token",
            gatewayConfigSource: "auto",
            projectsDirectory: "/tmp"
        )

        let data = try JSONEncoder().encode(codableConfig)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.projects == [configured])
        #expect(decoded.selectedProjectPath == configured.path)
        #expect(decoded.openClawGatewayURL == "http://127.0.0.1:18789")
        #expect(decoded.openClawToken == "token")
        #expect(decoded.gatewayConfigSource == "auto")
        #expect(decoded.projectsDirectory == "/tmp")
    }

    @Test("CodingSession and SessionStatus sort order")
    func codingSessionAndStatusSortOrder() {
        let session = CodingSession(
            id: "ses-1",
            name: "Session",
            agentType: .codex,
            projectPath: URL(fileURLWithPath: "/tmp/project"),
            beadId: "AB-1",
            status: .running,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            elapsed: 100,
            model: "gpt-5.3-codex",
            processID: 123,
            cpuPercent: 2.5
        )

        #expect(session.id == "ses-1")
        #expect(session.agentType == .codex)
        #expect(session.status == .running)
        #expect(SessionStatus.running.sortOrder == 0)
        #expect(SessionStatus.idle.sortOrder == 1)
        #expect(SessionStatus.stopped.sortOrder == 2)
        #expect(SessionStatus.error.sortOrder == 3)
    }

    @Test("GitCommitRecord and BeadGitSummary fields")
    func gitCommitRecordAndSummaryFields() {
        let commit = GitCommitRecord(
            sha: "abcdef1234567890",
            shortSHA: "abcdef1",
            authoredAt: Date(timeIntervalSince1970: 1_700_000_000),
            subject: "AgentBoard-1: update tests",
            refs: "HEAD -> main",
            branch: "main",
            beadIDs: ["AgentBoard-1"]
        )
        let summary = BeadGitSummary(beadID: "AgentBoard-1", latestCommit: commit, commitCount: 3)

        #expect(commit.id == commit.sha)
        #expect(summary.beadID == "AgentBoard-1")
        #expect(summary.latestCommit.shortSHA == "abcdef1")
        #expect(summary.commitCount == 3)
    }

    @Test("HistoryEventType labels and symbols")
    func historyEventTypeLabelsAndSymbols() {
        #expect(HistoryEventType.beadCreated.label == "Bead Created")
        #expect(HistoryEventType.beadStatus.label == "Bead Status")
        #expect(HistoryEventType.sessionStarted.label == "Session Started")
        #expect(HistoryEventType.sessionCompleted.label == "Session Completed")
        #expect(HistoryEventType.commit.label == "Commit")

        #expect(HistoryEventType.beadCreated.symbolName == "plus.circle")
        #expect(HistoryEventType.beadStatus.symbolName == "arrow.triangle.2.circlepath")
        #expect(HistoryEventType.sessionStarted.symbolName == "play.circle")
        #expect(HistoryEventType.sessionCompleted.symbolName == "checkmark.circle")
        #expect(HistoryEventType.commit.symbolName == "point.topleft.down.curvedto.point.bottomright.up")
    }

    @Test("HistoryEvent init sets defaults")
    func historyEventInit() {
        let event = HistoryEvent(
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            type: .commit,
            title: "Commit made"
        )

        #expect(!event.id.uuidString.isEmpty)
        #expect(event.type == .commit)
        #expect(event.title == "Commit made")
        #expect(event.details == nil)
        #expect(event.projectName == nil)
        #expect(event.beadID == nil)
        #expect(event.commitSHA == nil)
    }

    @Test("CanvasContent id extracts associated UUID")
    func canvasContentIDMapping() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/image.png")

        #expect(CanvasContent.markdown(id: id, title: "M", content: "C").id == id)
        #expect(CanvasContent.html(id: id, title: "H", content: "C").id == id)
        #expect(CanvasContent.image(id: id, title: "I", url: url).id == id)
        #expect(CanvasContent.diff(id: id, title: "D", before: "a", after: "b", filename: "f").id == id)
        #expect(CanvasContent.diagram(id: id, title: "G", mermaid: "graph TD;").id == id)
        #expect(CanvasContent.terminal(id: id, title: "T", output: "out").id == id)
    }

    @Test("OpenClawConnectionState labels and color access")
    func openClawConnectionStateLabelsAndColor() {
        let cases: [(OpenClawConnectionState, String)] = [
            (.disconnected, "Disconnected"),
            (.connecting, "Connecting"),
            (.reconnecting, "Reconnecting"),
            (.connected, "Connected"),
        ]

        for (state, label) in cases {
            #expect(state.label == label)
            _ = state.color
        }
    }
}
