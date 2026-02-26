import Foundation
import Testing
@testable import AgentBoard

@Suite("WorkspaceNotesService Tests")
@MainActor
struct WorkspaceNotesServiceTests {

    // MARK: - Helpers

    private func makeTempDir() throws -> (root: String, cleanup: () -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return (tempDir.path, { try? FileManager.default.removeItem(at: tempDir) })
    }

    private func makeService(root: String, ontologyPath: String? = nil) -> WorkspaceNotesService {
        let onto = ontologyPath ?? (root as NSString).appendingPathComponent("ontology.jsonl")
        return WorkspaceNotesService(workspaceRoot: root, ontologyPath: onto)
    }

    private func makeDate(_ string: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)!
    }

    // MARK: - Date Navigation

    @Test("goToDate changes selectedDate")
    func goToDateChangesSelectedDate() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }
        let service = makeService(root: root)

        let target = makeDate("2026-01-15")
        service.goToDate(target)

        #expect(Calendar.current.isDate(service.selectedDate, inSameDayAs: target))
    }

    @Test("goToPreviousDay decrements by one day")
    func goToPreviousDayDecrementsOneDay() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }
        let service = makeService(root: root)

        let start = makeDate("2026-02-15")
        service.goToDate(start)
        service.goToPreviousDay()

        let expected = makeDate("2026-02-14")
        #expect(Calendar.current.isDate(service.selectedDate, inSameDayAs: expected))
    }

    @Test("goToNextDay increments by one day")
    func goToNextDayIncrementsOneDay() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }
        let service = makeService(root: root)

        let start = makeDate("2026-02-15")
        service.goToDate(start)
        service.goToNextDay()

        let expected = makeDate("2026-02-16")
        #expect(Calendar.current.isDate(service.selectedDate, inSameDayAs: expected))
    }

    @Test("goToToday sets selectedDate to today")
    func goToTodaySetsToday() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }
        let service = makeService(root: root)

        service.goToDate(makeDate("2020-01-01"))
        service.goToToday()

        #expect(Calendar.current.isDateInToday(service.selectedDate))
    }

    @Test("multiple navigation steps accumulate correctly")
    func multipleNavigationSteps() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }
        let service = makeService(root: root)

        service.goToDate(makeDate("2026-02-15"))
        service.goToNextDay()
        service.goToNextDay()
        service.goToPreviousDay()

        let expected = makeDate("2026-02-16")
        #expect(Calendar.current.isDate(service.selectedDate, inSameDayAs: expected))
    }

    // MARK: - Daily Notes Loading

    @Test("loadDailyNotes returns empty string when file missing")
    func dailyNotesEmptyWhenMissing() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }
        let service = makeService(root: root)

        service.goToDate(makeDate("2026-02-25"))

        #expect(service.dailyNotes == "")
    }

    @Test("loadDailyNotes reads content from date-stamped markdown file")
    func dailyNotesReadsFile() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let memoryDir = (root as NSString).appendingPathComponent("memory")
        try FileManager.default.createDirectory(atPath: memoryDir, withIntermediateDirectories: true)
        let noteContent = "# Meeting Notes\n- Discussed architecture\n- Agreed on approach"
        try noteContent.write(
            toFile: (memoryDir as NSString).appendingPathComponent("2026-02-25.md"),
            atomically: true, encoding: .utf8
        )

        let service = makeService(root: root)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.dailyNotes == noteContent)
    }

    @Test("navigating to different date loads that date's notes")
    func navigatingLoadsDifferentNotes() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let memoryDir = (root as NSString).appendingPathComponent("memory")
        try FileManager.default.createDirectory(atPath: memoryDir, withIntermediateDirectories: true)
        try "Day 1 notes".write(
            toFile: (memoryDir as NSString).appendingPathComponent("2026-02-24.md"),
            atomically: true, encoding: .utf8
        )
        try "Day 2 notes".write(
            toFile: (memoryDir as NSString).appendingPathComponent("2026-02-25.md"),
            atomically: true, encoding: .utf8
        )

        let service = makeService(root: root)
        service.goToDate(makeDate("2026-02-24"))
        #expect(service.dailyNotes == "Day 1 notes")

        service.goToNextDay()
        #expect(service.dailyNotes == "Day 2 notes")
    }

    @Test("dailyNotes preserves unicode and emoji content")
    func dailyNotesPreservesUnicode() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let memoryDir = (root as NSString).appendingPathComponent("memory")
        try FileManager.default.createDirectory(atPath: memoryDir, withIntermediateDirectories: true)
        let content = "# \u{1F4DD} Notes — 日本語テスト\nLine with emoji: \u{1F600}\nArabic: مرحبا"
        try content.write(
            toFile: (memoryDir as NSString).appendingPathComponent("2026-02-25.md"),
            atomically: true, encoding: .utf8
        )

        let service = makeService(root: root)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.dailyNotes == content)
    }

    @Test("navigating from day with notes to day without notes clears dailyNotes")
    func navigatingToEmptyDayClearsDailyNotes() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let memoryDir = (root as NSString).appendingPathComponent("memory")
        try FileManager.default.createDirectory(atPath: memoryDir, withIntermediateDirectories: true)
        try "Day 1 notes".write(
            toFile: (memoryDir as NSString).appendingPathComponent("2026-02-24.md"),
            atomically: true, encoding: .utf8
        )
        // No file for 2026-02-25

        let service = makeService(root: root)
        service.goToDate(makeDate("2026-02-24"))
        #expect(service.dailyNotes == "Day 1 notes")

        service.goToNextDay()
        #expect(service.dailyNotes == "")
    }

    // MARK: - Ontology Loading

    @Test("loadOntology parses create ops and filters by allowed types and date")
    func ontologyParsesCreateOps() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"Use SwiftUI","summary":"Adopted SwiftUI","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"l1","type":"Lesson","properties":{"title":"Async patterns","summary":"Use structured concurrency","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"x1","type":"Agent","properties":{"title":"Should be filtered","date":"2026-02-25"}}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 2)
        #expect(service.ontologyEntries.allSatisfy { ["Decision", "Lesson"].contains($0.type) })
    }

    @Test("loadOntology filters by date matching selectedDate")
    func ontologyFiltersByDate() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"Today","summary":"Today's decision","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"d2","type":"Decision","properties":{"title":"Yesterday","summary":"Yesterday's decision","date":"2026-02-24"}}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 1)
        #expect(service.ontologyEntries[0].title == "Today")
        // Also verify the excluded entry is not present
        #expect(service.ontologyEntries.allSatisfy { $0.id != "d2" })
    }

    @Test("loadOntology handles malformed lines gracefully")
    func ontologySkipsMalformedLines() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        not json at all
        {"broken json
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"Valid","summary":"Good entry","date":"2026-02-25"}}}
        {"op":"unknown_op","entity":{"id":"d2","type":"Decision","properties":{}}}

        {"op":"create"}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 1)
        #expect(service.ontologyEntries[0].title == "Valid")
    }

    @Test("loadOntology handles empty file")
    func ontologyHandlesEmptyFile() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        try "".write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.isEmpty)
    }

    @Test("loadOntology handles missing ontology file")
    func ontologyHandlesMissingFile() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let service = makeService(root: root, ontologyPath: "/nonexistent/graph.jsonl")
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.isEmpty)
    }

    @Test("loadOntology handles update to non-existent entity without crash")
    func ontologyUpdateNonExistentEntity() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"update","id":"nonexistent","properties":{"title":"Updated"}}
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"Real","summary":"Real entry","date":"2026-02-25"}}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 1)
        #expect(service.ontologyEntries[0].title == "Real")
    }

    @Test("loadOntology handles delete op")
    func ontologyHandlesDelete() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"Deleted","summary":"Will be deleted","date":"2026-02-25"}}}
        {"op":"delete","id":"d1"}
        {"op":"create","entity":{"id":"d2","type":"Decision","properties":{"title":"Kept","summary":"Will remain","date":"2026-02-25"}}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 1)
        #expect(service.ontologyEntries[0].title == "Kept")
    }

    @Test("ontology entries sorted by type ascending")
    func ontologyEntriesSortedByType() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"create","entity":{"id":"l1","type":"Lesson","properties":{"title":"L1","summary":"","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"b1","type":"Bug","properties":{"title":"B1","summary":"","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"D1","summary":"","date":"2026-02-25"}}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 3)
        let types = service.ontologyEntries.map(\.type)
        #expect(types == ["Bug", "Decision", "Lesson"])
    }

    @Test("loadOntology title fallback: title -> summary -> entity id")
    func ontologyTitleFallback() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"Has Title","summary":"Also summary","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"d2","type":"Decision","properties":{"summary":"Only Summary","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"d3","type":"Decision","properties":{"date":"2026-02-25"}}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 3)
        let titles = service.ontologyEntries.map(\.title).sorted()
        #expect(titles.contains("Has Title"))
        #expect(titles.contains("Only Summary"))
        #expect(titles.contains("d3"))
    }

    @Test("update operation merges properties for existing entity")
    func ontologyUpdateMergesProperties() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"Original","summary":"Original summary","date":"2026-02-25","status":"draft"}}}
        {"op":"update","id":"d1","properties":{"summary":"Updated summary","status":"approved"}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 1)
        let entry = service.ontologyEntries[0]
        #expect(entry.title == "Original")
        #expect(entry.summary == "Updated summary")
        #expect(entry.status == "approved")
    }

    @Test("Bug type is included in allowed types")
    func bugTypeAllowed() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"create","entity":{"id":"b1","type":"Bug","properties":{"title":"Crash on launch","summary":"App crashes","date":"2026-02-25"}}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 1)
        #expect(service.ontologyEntries[0].type == "Bug")
    }

    @Test("entity properties include optional projectId and status")
    func ontologyEntityOptionalFields() throws {
        let (root, cleanup) = try makeTempDir()
        defer { cleanup() }

        let ontologyFile = (root as NSString).appendingPathComponent("graph.jsonl")
        let jsonl = """
        {"op":"create","entity":{"id":"d1","type":"Decision","properties":{"title":"With project","summary":"Has project","date":"2026-02-25","project_id":"proj-1","status":"active"}}}
        {"op":"create","entity":{"id":"d2","type":"Decision","properties":{"title":"No optionals","summary":"Bare","date":"2026-02-25"}}}
        """
        try jsonl.write(toFile: ontologyFile, atomically: true, encoding: .utf8)

        let service = makeService(root: root, ontologyPath: ontologyFile)
        service.goToDate(makeDate("2026-02-25"))

        #expect(service.ontologyEntries.count == 2)
        let withProject = service.ontologyEntries.first { $0.id == "d1" }
        let bare = service.ontologyEntries.first { $0.id == "d2" }
        #expect(withProject?.projectId == "proj-1")
        #expect(withProject?.status == "active")
        #expect(bare?.projectId == nil)
        #expect(bare?.status == nil)
    }
}
