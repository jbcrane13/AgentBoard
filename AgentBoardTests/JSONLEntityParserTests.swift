import Foundation
import Testing
@testable import AgentBoard

@Suite("JSONLEntityParser Tests")
struct JSONLEntityParserTests {

    // MARK: - Helpers

    private func jsonlLine(_ dict: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8)!
    }

    // MARK: 1 — create op builds an entity with correct type and properties

    @Test("parseText: create op builds entity with correct type and properties")
    func parseTextCreateOpBuildsEntity() {
        let line = jsonlLine([
            "op": "create",
            "entity": [
                "id": "e1",
                "type": "task",
                "properties": ["title": "Do something", "status": "open"]
            ]
        ])

        let result = JSONLEntityParser.parse(text: line)

        let entity = try! #require(result["e1"])
        #expect(entity.type == "task")
        #expect(entity.properties["title"] == "Do something")
        #expect(entity.properties["status"] == "open")
    }

    // MARK: 2 — update op merges properties into an existing entity

    @Test("parseText: update op merges new property value")
    func parseTextUpdateMergesProperties() {
        let createLine = jsonlLine([
            "op": "create",
            "entity": ["id": "e2", "type": "note", "properties": ["status": "draft"]]
        ])
        let updateLine = jsonlLine([
            "op": "update",
            "id": "e2",
            "properties": ["status": "published"]
        ])

        let result = JSONLEntityParser.parse(text: createLine + "\n" + updateLine)

        let entity = try! #require(result["e2"])
        #expect(entity.properties["status"] == "published")
    }

    // MARK: 3 — update op preserves properties that were not mentioned

    @Test("parseText: update op preserves unchanged properties")
    func parseTextUpdatePreservesUnchangedProperties() {
        let createLine = jsonlLine([
            "op": "create",
            "entity": [
                "id": "e3",
                "type": "task",
                "properties": ["title": "Original Title", "priority": "high"]
            ]
        ])
        let updateLine = jsonlLine([
            "op": "update",
            "id": "e3",
            "properties": ["priority": "low"]
        ])

        let result = JSONLEntityParser.parse(text: createLine + "\n" + updateLine)

        let entity = try! #require(result["e3"])
        #expect(entity.properties["title"] == "Original Title")
        #expect(entity.properties["priority"] == "low")
    }

    // MARK: 4 — delete op removes an entity that was previously created

    @Test("parseText: delete op removes the entity")
    func parseTextDeleteRemovesEntity() {
        let createLine = jsonlLine([
            "op": "create",
            "entity": ["id": "e4", "type": "task", "properties": [:]]
        ])
        let deleteLine = jsonlLine(["op": "delete", "id": "e4"])

        let result = JSONLEntityParser.parse(text: createLine + "\n" + deleteLine)

        #expect(result["e4"] == nil)
        #expect(result.isEmpty)
    }

    // MARK: 5 — update for unknown ID is a no-op (empty result)

    @Test("parseText: update on missing ID is no-op")
    func parseTextUpdateOnMissingIDIsNoOp() {
        let updateLine = jsonlLine([
            "op": "update",
            "id": "ghost",
            "properties": ["title": "Never stored"]
        ])

        let result = JSONLEntityParser.parse(text: updateLine)

        #expect(result.isEmpty)
    }

    // MARK: 6 — delete for unknown ID is a no-op (no crash)

    @Test("parseText: delete on missing ID is no-op")
    func parseTextDeleteOnMissingIDIsNoOp() {
        let deleteLine = jsonlLine(["op": "delete", "id": "nonexistent"])

        let result = JSONLEntityParser.parse(text: deleteLine)

        #expect(result.isEmpty)
    }

    // MARK: 7 — unknown op is ignored; entity is NOT created

    @Test("parseText: unknown op 'patch' is ignored")
    func parseTextUnknownOpIsIgnored() {
        let patchLine = jsonlLine([
            "op": "patch",
            "entity": ["id": "e7", "type": "task", "properties": ["x": "1"]]
        ])

        let result = JSONLEntityParser.parse(text: patchLine)

        #expect(result["e7"] == nil)
        #expect(result.isEmpty)
    }

    // MARK: 8 — malformed JSON line is skipped; valid lines still parse

    @Test("parseText: malformed JSON line is skipped, valid lines still parse")
    func parseTextMalformedJSONLineIsSkipped() {
        let validLine = jsonlLine([
            "op": "create",
            "entity": ["id": "valid-e", "type": "note", "properties": ["body": "hello"]]
        ])
        let badLine = "{ this is not json !!!"
        let text = validLine + "\n" + badLine

        let result = JSONLEntityParser.parse(text: text)

        #expect(result.count == 1)
        #expect(result["valid-e"] != nil)
    }

    // MARK: 9 — empty string input returns empty dict

    @Test("parseText: empty string returns empty dict")
    func parseTextEmptyStringReturnsEmptyDict() {
        let result = JSONLEntityParser.parse(text: "")
        #expect(result.isEmpty)
    }

    // MARK: 10 — multiple create ops produce multiple entities with correct types

    @Test("parseText: three create ops produce three entities")
    func parseTextMultipleEntities() {
        let lines = [
            jsonlLine(["op": "create", "entity": ["id": "a", "type": "task", "properties": [:]]]),
            jsonlLine(["op": "create", "entity": ["id": "b", "type": "note", "properties": [:]]]),
            jsonlLine(["op": "create", "entity": ["id": "c", "type": "epic", "properties": [:]]])
        ].joined(separator: "\n")

        let result = JSONLEntityParser.parse(text: lines)

        #expect(result.count == 3)
        #expect(result["a"]?.type == "task")
        #expect(result["b"]?.type == "note")
        #expect(result["c"]?.type == "epic")
    }

    // MARK: 11 — parse(filePath:) returns empty dict for non-existent file

    @Test("parseFile: missing file returns empty dict without throwing")
    func parseFileMissingFileReturnsEmptyDict() {
        let nonExistentPath = "/tmp/jsonl-parser-tests-nonexistent-\(UUID().uuidString).jsonl"
        let result = JSONLEntityParser.parse(filePath: nonExistentPath)
        #expect(result.isEmpty)
    }

    // MARK: 12 — parse(filePath:) reads and parses a real file

    @Test("parseFile: reads and parses entities from a real JSONL file")
    func parseFileReadsAndParsesRealFile() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ab-jsonl-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let lines = [
            jsonlLine(["op": "create", "entity": ["id": "f1", "type": "task", "properties": ["title": "File Task 1"]]]),
            jsonlLine(["op": "create", "entity": ["id": "f2", "type": "task", "properties": ["title": "File Task 2"]]]),
            jsonlLine(["op": "update", "id": "f1", "properties": ["title": "File Task 1 Updated"]])
        ].joined(separator: "\n")

        try lines.write(to: tempURL, atomically: true, encoding: .utf8)

        let result = JSONLEntityParser.parse(filePath: tempURL.path)

        #expect(result.count == 2)
        #expect(result["f1"]?.properties["title"] == "File Task 1 Updated")
        #expect(result["f2"]?.properties["title"] == "File Task 2")
    }
}
