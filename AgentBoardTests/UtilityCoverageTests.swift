import Foundation
import Testing
@testable import AgentBoard

@Suite("Utility Coverage")
struct UtilityCoverageTests {
    @Test("ShellCommandResult combinedOutput trims and joins stdout/stderr")
    func shellCommandResultCombinedOutput() {
        let result = ShellCommandResult(exitCode: 1, stdout: " hello \n", stderr: " error \n")
        #expect(result.combinedOutput == "hello\nerror")

        let stdoutOnly = ShellCommandResult(exitCode: 0, stdout: "ok\n", stderr: "")
        #expect(stdoutOnly.combinedOutput == "ok")
    }

    @Test("ShellCommand run captures stdout")
    func shellCommandRunSuccess() throws {
        let result = try ShellCommand.run(arguments: ["sh", "-c", "printf 'hello'"])
        #expect(result.exitCode == 0)
        #expect(result.stdout == "hello")
        #expect(result.stderr.isEmpty)
    }

    @Test("ShellCommand run uses working directory")
    func shellCommandRunWithWorkingDirectory() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = try ShellCommand.run(arguments: ["pwd"], workingDirectory: tempDir)
        let actual = try URL(fileURLWithPath: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)).standardizedFileURL.path
        let expected = tempDir.standardizedFileURL.path
        #expect(actual == expected)
    }

    @Test("ShellCommand run throws failed error with captured output")
    func shellCommandRunFailure() {
        do {
            _ = try ShellCommand.run(
                arguments: ["sh", "-c", "printf 'stdout text\\n'; printf 'stderr text\\n' 1>&2; exit 7"]
            )
            Issue.record("Expected ShellCommandError.failed to be thrown")
        } catch ShellCommandError.failed(let result) {
            #expect(result.exitCode == 7)
            #expect(result.stdout.contains("stdout text"))
            #expect(result.stderr.contains("stderr text"))
            #expect(result.combinedOutput == "stdout text\nstderr text")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("ShellCommand runAsync executes command")
    func shellCommandRunAsync() async throws {
        let result = try await ShellCommand.runAsync(arguments: ["sh", "-c", "printf 'async'"])
        #expect(result.stdout == "async")
        #expect(result.stderr.isEmpty)
    }

    @Test("JSONLParser parses beads, maps fields, and sorts by updatedAt descending")
    func jsonlParserParsesAndSorts() throws {
        let parser = JSONLParser()
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let fileURL = tempDir.appendingPathComponent("issues.jsonl")

        let content = """
        {"id":"AB-EPIC","title":"Epic","description":"Top level","status":"open","issue_type":"epic","labels":["planning"],"owner":"alice","created_at":"2025-01-01T10:00:00Z","updated_at":"2025-01-03T10:00:00.123Z"}
        {"id":"AB-1","title":"Child","description":null,"status":"in-progress","issue_type":"task","labels":["ios"],"owner":"bob","created_at":"2025-01-02T11:00:00.100Z","updated_at":"2025-01-04T12:00:00Z","dependencies":[{"depends_on_id":"AB-EPIC","type":"parent-child"},{"depends_on_id":"AB-0","type":"blocks"}]}
        {"id":"AB-2","title":"Bug","status":"closed","issue_type":"bug","created_at":"2025-01-01T09:00:00Z","updated_at":"2025-01-05T09:00:00Z"}
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let beads = try parser.parseBeads(from: fileURL)
        #expect(beads.map(\.id) == ["AB-2", "AB-1", "AB-EPIC"])

        let epic = try #require(beads.first(where: { $0.id == "AB-EPIC" }))
        #expect(epic.kind == .epic)
        #expect(epic.status == .open)

        let child = try #require(beads.first(where: { $0.id == "AB-1" }))
        #expect(child.kind == .task)
        #expect(child.status == .inProgress)
        #expect(child.epicId == "AB-EPIC")
        #expect(child.dependencies == ["AB-EPIC", "AB-0"])
        #expect(child.assignee == "bob")
        #expect(child.labels == ["ios"])
        #expect(child.createdAt != .distantPast)
        #expect(child.updatedAt > child.createdAt)

        let bug = try #require(beads.first(where: { $0.id == "AB-2" }))
        #expect(bug.kind == .bug)
        #expect(bug.status == .done)
    }

    @Test("JSONLParser ignores invalid and blank lines")
    func jsonlParserIgnoresInvalidLines() throws {
        let parser = JSONLParser()
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let fileURL = tempDir.appendingPathComponent("issues.jsonl")

        let content = """

        {"id":"AB-3","title":"Valid","status":"open"}
        not-json

        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let beads = try parser.parseBeads(from: fileURL)
        #expect(beads.count == 1)
        #expect(beads[0].id == "AB-3")
        #expect(beads[0].createdAt == .distantPast)
        #expect(beads[0].updatedAt == .distantPast)
        #expect(beads[0].kind == .task)
    }

    @Test("JSONLParser returns empty for non-UTF8 file content")
    func jsonlParserNonUTF8() throws {
        let parser = JSONLParser()
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let fileURL = tempDir.appendingPathComponent("issues.jsonl")

        let bytes = Data([0xFF, 0xFE, 0xFD])
        try bytes.write(to: fileURL, options: .atomic)

        let beads = try parser.parseBeads(from: fileURL)
        #expect(beads.isEmpty)
    }

    @Test("JSONLParser throws when file does not exist")
    func jsonlParserMissingFileThrows() {
        let parser = JSONLParser()
        let missing = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-missing.jsonl")

        do {
            _ = try parser.parseBeads(from: missing)
            Issue.record("Expected parseBeads to throw for missing file")
        } catch {
            #expect(true)
        }
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentBoardTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
