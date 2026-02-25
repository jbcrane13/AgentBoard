import Foundation
import Testing
@testable import AgentBoard

@Suite("CoordinationService Tests")
@MainActor
struct CoordinationServiceTests {

    // MARK: - Helpers

    private func makeTempFile(content: String) throws -> (path: String, dir: URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let filePath = tempDir.appendingPathComponent("coordination.jsonl")
        try content.write(to: filePath, atomically: true, encoding: .utf8)
        return (filePath.path, tempDir)
    }

    /// Calls startPolling to trigger an immediate reload, then stops the timer.
    private func reloadService(_ service: CoordinationService) {
        service.startPolling()
        service.stopPolling()
    }

    // MARK: - AgentStatus Parsing

    @Test("reload from valid JSONL with AgentStatus entries populates agentStatuses")
    func reloadAgentStatuses() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"Fix bug","updated":"2026-02-25"}}}
        {"op":"create","entity":{"id":"s2","type":"AgentStatus","properties":{"agent":"quentin","status":"idle","current_task":"","updated":"2026-02-25"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 2)
        #expect(service.agentStatuses[0].agent == "daneel")
        #expect(service.agentStatuses[0].status == "active")
        #expect(service.agentStatuses[0].currentTask == "Fix bug")
        #expect(service.agentStatuses[1].agent == "quentin")
        #expect(service.agentStatuses[1].status == "idle")
    }

    // MARK: - Handoff Parsing

    @Test("reload from valid JSONL with Handoff entries populates handoffs sorted by date descending")
    func reloadHandoffs() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"h1","type":"Handoff","properties":{"from_agent":"daneel","to_agent":"quentin","task":"Review PR","context":"PR #42","status":"completed","date":"2026-02-24"}}}
        {"op":"create","entity":{"id":"h2","type":"Handoff","properties":{"from_agent":"quentin","to_agent":"daneel","task":"Deploy","context":"v1.0","status":"pending","bead_id":"AB-123","date":"2026-02-25"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.handoffs.count == 2)
        #expect(service.handoffs[0].date == "2026-02-25")
        #expect(service.handoffs[0].task == "Deploy")
        #expect(service.handoffs[0].beadId == "AB-123")
        #expect(service.handoffs[1].date == "2026-02-24")
        #expect(service.handoffs[1].task == "Review PR")
        #expect(service.handoffs[1].beadId == nil)
    }

    // MARK: - Mixed Types

    @Test("reload from JSONL with both types correctly separates into statuses and handoffs")
    func reloadBothTypes() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"Build","updated":"now"}}}
        {"op":"create","entity":{"id":"h1","type":"Handoff","properties":{"from_agent":"daneel","to_agent":"quentin","task":"Review","context":"ctx","status":"pending","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"s2","type":"AgentStatus","properties":{"agent":"quentin","status":"busy","current_task":"Test","updated":"now"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 2)
        #expect(service.handoffs.count == 1)
    }

    // MARK: - Missing File

    @Test("reload with missing file leaves existing state unchanged")
    func reloadMissingFilePreservesState() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"Build","updated":"now"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)

        let service = CoordinationService(filePath: path)
        reloadService(service)
        #expect(service.agentStatuses.count == 1)

        // Delete the file
        try FileManager.default.removeItem(at: dir)

        // Trigger reload again — file is gone
        reloadService(service)

        // State should be preserved since file is missing (reload returns early)
        #expect(service.agentStatuses.count == 1)
        #expect(service.agentStatuses[0].agent == "daneel")
    }

    // MARK: - Malformed Input

    @Test("reload with malformed JSONL lines skips bad lines and parses good ones")
    func reloadSkipsMalformedLines() throws {
        let jsonl = """
        not json
        {"broken": json
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"OK","updated":"now"}}}
        {"op":"create"}

        {"op":"create","entity":{"id":"s2","type":"AgentStatus","properties":{"agent":"quentin","status":"idle","current_task":"","updated":"now"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 2)
    }

    // MARK: - Update Operations

    @Test("reload with create + update merges properties correctly")
    func reloadUpdateMergesProperties() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"Building","updated":"10:00"}}}
        {"op":"update","id":"s1","properties":{"status":"idle","current_task":"Done","updated":"10:05"}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 1)
        let status = service.agentStatuses[0]
        #expect(status.agent == "daneel")
        #expect(status.status == "idle")
        #expect(status.currentTask == "Done")
        #expect(status.updated == "10:05")
    }

    // MARK: - Delete Operations

    @Test("reload with create + delete excludes deleted entity from results")
    func reloadDeleteExcludesEntity() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"","updated":"now"}}}
        {"op":"create","entity":{"id":"s2","type":"AgentStatus","properties":{"agent":"quentin","status":"idle","current_task":"","updated":"now"}}}
        {"op":"delete","id":"s1"}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 1)
        #expect(service.agentStatuses[0].agent == "quentin")
    }

    @Test("delete removes handoff entries too")
    func deleteRemovesHandoff() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"h1","type":"Handoff","properties":{"from_agent":"daneel","to_agent":"quentin","task":"Review","context":"","status":"pending","date":"2026-02-25"}}}
        {"op":"delete","id":"h1"}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.handoffs.isEmpty)
    }

    // MARK: - Polling Behavior

    @Test("startPolling calls reload immediately")
    func startPollingCallsReloadImmediately() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"Test","updated":"now"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        #expect(service.agentStatuses.isEmpty)

        service.startPolling()

        // State populated immediately, not after timer fires
        #expect(service.agentStatuses.count == 1)
        #expect(service.agentStatuses[0].agent == "daneel")

        service.stopPolling()
    }

    @Test("stopPolling is safe to call when not polling")
    func stopPollingWhenNotPolling() {
        let service = CoordinationService(filePath: "/nonexistent")
        service.stopPolling()
    }

    @Test("stopPolling is safe to call multiple times")
    func stopPollingMultipleTimes() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"","updated":""}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        service.startPolling()
        service.stopPolling()
        service.stopPolling()
    }

    // MARK: - Sorting

    @Test("agentStatuses sorted by agent name ascending")
    func agentStatusesSortedByName() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"quentin","status":"idle","current_task":"","updated":""}}}
        {"op":"create","entity":{"id":"s2","type":"AgentStatus","properties":{"agent":"argus","status":"active","current_task":"","updated":""}}}
        {"op":"create","entity":{"id":"s3","type":"AgentStatus","properties":{"agent":"daneel","status":"busy","current_task":"","updated":""}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        let agents = service.agentStatuses.map(\.agent)
        #expect(agents == ["argus", "daneel", "quentin"])
    }

    @Test("handoffs sorted by date descending")
    func handoffsSortedByDateDescending() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"h1","type":"Handoff","properties":{"from_agent":"a","to_agent":"b","task":"T1","context":"","status":"done","date":"2026-02-20"}}}
        {"op":"create","entity":{"id":"h2","type":"Handoff","properties":{"from_agent":"b","to_agent":"c","task":"T2","context":"","status":"done","date":"2026-02-25"}}}
        {"op":"create","entity":{"id":"h3","type":"Handoff","properties":{"from_agent":"c","to_agent":"a","task":"T3","context":"","status":"done","date":"2026-02-22"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        let dates = service.handoffs.map(\.date)
        #expect(dates == ["2026-02-25", "2026-02-22", "2026-02-20"])
    }

    // MARK: - Default Values

    @Test("default values for missing properties")
    func defaultValuesForMissingProperties() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{}}}
        {"op":"create","entity":{"id":"h1","type":"Handoff","properties":{}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 1)
        #expect(service.agentStatuses[0].agent == "unknown")
        #expect(service.agentStatuses[0].status == "offline")
        #expect(service.agentStatuses[0].currentTask == "")
        #expect(service.agentStatuses[0].updated == "")

        #expect(service.handoffs.count == 1)
        #expect(service.handoffs[0].fromAgent == "")
        #expect(service.handoffs[0].toAgent == "")
        #expect(service.handoffs[0].status == "pending")
        #expect(service.handoffs[0].beadId == nil)
        #expect(service.handoffs[0].date == "")
    }

    @Test("unknown entity types are ignored")
    func unknownEntityTypesIgnored() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"x1","type":"UnknownType","properties":{"agent":"test"}}}
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"active","current_task":"","updated":"now"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 1)
        #expect(service.handoffs.isEmpty)
    }

    @Test("update to non-existent entity does not crash")
    func updateNonExistentEntity() throws {
        let jsonl = """
        {"op":"update","id":"ghost","properties":{"status":"active"}}
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"idle","current_task":"","updated":""}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 1)
        #expect(service.agentStatuses[0].agent == "daneel")
    }

    @Test("delete of non-existent entity does not crash")
    func deleteNonExistentEntity() throws {
        let jsonl = """
        {"op":"delete","id":"ghost"}
        {"op":"create","entity":{"id":"s1","type":"AgentStatus","properties":{"agent":"daneel","status":"idle","current_task":"","updated":""}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.agentStatuses.count == 1)
    }

    @Test("handoff entry includes all fields")
    func handoffEntryIncludesAllFields() throws {
        let jsonl = """
        {"op":"create","entity":{"id":"h1","type":"Handoff","properties":{"from_agent":"daneel","to_agent":"quentin","task":"Implement auth","context":"Needs JWT setup","status":"in_progress","bead_id":"AB-42x","date":"2026-02-25"}}}
        """
        let (path, dir) = try makeTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = CoordinationService(filePath: path)
        reloadService(service)

        #expect(service.handoffs.count == 1)
        let h = service.handoffs[0]
        #expect(h.id == "h1")
        #expect(h.fromAgent == "daneel")
        #expect(h.toAgent == "quentin")
        #expect(h.task == "Implement auth")
        #expect(h.context == "Needs JWT setup")
        #expect(h.status == "in_progress")
        #expect(h.beadId == "AB-42x")
        #expect(h.date == "2026-02-25")
    }
}
