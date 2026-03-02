import Foundation
import Testing
@testable import AgentBoard

@Suite("AgentTasksViewModel")
@MainActor
struct AgentTasksViewModelTests {
    @Test("Malformed task payload surfaces parse error and keeps prior tasks")
    func malformedPayloadSurfacesError() async {
        let priorTask = AgentTask(
            id: "AB-prior",
            title: "Existing task",
            status: "open",
            priority: 2,
            assignee: "codex",
            issueType: "task",
            createdAt: .distantPast,
            updatedAt: .distantPast
        )

        let model = AgentTasksViewModel(
            runCommand: { _, _ in
                ShellCommandResult(
                    exitCode: 0,
                    stdout: try fixture(named: "tasks_malformed.json"),
                    stderr: ""
                )
            },
            useFixtureData: false
        )
        model.tasks = [priorTask]

        await model.loadTasksNow()

        #expect(model.tasks == [priorTask])
        #expect(model.errorMessage?.contains("Failed to parse tasks") == true)
    }

    @Test("Empty array payload is valid and clears previous tasks")
    func emptyPayloadIsValid() async {
        let model = AgentTasksViewModel(
            runCommand: { _, _ in
                ShellCommandResult(
                    exitCode: 0,
                    stdout: try fixture(named: "tasks_empty.json"),
                    stderr: ""
                )
            },
            useFixtureData: false
        )

        model.tasks = [
            AgentTask(
                id: "AB-prior",
                title: "Old task",
                status: "open",
                priority: 2,
                assignee: "codex",
                issueType: "task",
                createdAt: .distantPast,
                updatedAt: .distantPast
            )
        ]

        await model.loadTasksNow()

        #expect(model.tasks.isEmpty)
        #expect(model.errorMessage == nil)
    }

    @Test("Valid fixture payload parses id/title/status/priority/assignee fields")
    func validPayloadParsesExpectedFields() async throws {
        let model = AgentTasksViewModel(
            runCommand: { _, _ in
                ShellCommandResult(
                    exitCode: 0,
                    stdout: try fixture(named: "tasks_valid.json"),
                    stderr: ""
                )
            },
            useFixtureData: false
        )

        await model.loadTasksNow()

        #expect(model.errorMessage == nil)
        #expect(model.tasks.count == 2)

        let first = try #require(model.tasks.first)
        #expect(first.id == "AB-123")
        #expect(first.title == "Investigate dashboard bug")
        #expect(first.status == "open")
        #expect(first.priority == 1)
        #expect(first.assignee == "codex")
        #expect(first.issueType == "bug")

        let second = try #require(model.tasks.last)
        #expect(second.id == "AB-124")
        #expect(second.assignee == "claude-code")
        #expect(second.status == "in_progress")
    }

    @Test("Command failure surfaces load error")
    func commandFailureSurfacesLoadError() async {
        struct CommandFailure: LocalizedError {
            var errorDescription: String? { "bd command failed" }
        }

        let priorTask = AgentTask(
            id: "AB-prior",
            title: "Existing task",
            status: "open",
            priority: 2,
            assignee: "codex",
            issueType: "task",
            createdAt: .distantPast,
            updatedAt: .distantPast
        )

        let model = AgentTasksViewModel(
            runCommand: { _, _ in throw CommandFailure() },
            useFixtureData: false
        )
        model.tasks = [priorTask]

        await model.loadTasksNow()

        #expect(model.tasks == [priorTask])
        #expect(model.errorMessage?.contains("Failed to load tasks") == true)
    }

    nonisolated private func fixture(named name: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let fixtureURL = testsDirectory
            .appendingPathComponent("TestFixtures")
            .appendingPathComponent("AgentTasks")
            .appendingPathComponent(name)
        return try String(contentsOf: fixtureURL, encoding: .utf8)
    }
}
