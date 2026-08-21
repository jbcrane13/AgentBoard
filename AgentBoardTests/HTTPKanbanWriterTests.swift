import AgentBoardCore
import Foundation
import Testing

@Suite(.serialized)
struct HTTPKanbanWriterTests {
    // MARK: - Create

    @Test
    func createPostsToTasksEndpointWithPresentFieldsOmittingAbsentOptionals() async throws {
        let captured = Self.CapturedRequest()
        let writer = Self.makeWriter { request in
            captured.request = request
            return try Self.jsonResponse(
                for: request,
                body: #"{"task": {"id": "t-9", "title": "New task", "status": "todo"}}"#
            )
        }

        let draft = KanbanCreateDraft(title: "New task", priority: 2, parentIDs: ["p1", "p2"])
        let task = try await writer.create(draft)

        #expect(task.id == "t-9")
        #expect(task.title == "New task")
        #expect(task.status == .todo)

        let request = try #require(captured.request)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/plugins/kanban/tasks")

        let body = try Self.jsonBody(request)
        #expect(body["title"] as? String == "New task")
        #expect(body["priority"] as? Int == 2)
        #expect(body["parents"] as? [String] == ["p1", "p2"])
        #expect(body.keys.contains("body") == false)
        #expect(body.keys.contains("assignee") == false)
        #expect(body.keys.contains("tenant") == false)
    }

    @Test
    func createSendsPresentOptionalsWhenDraftProvidesThem() async throws {
        let captured = Self.CapturedRequest()
        let writer = Self.makeWriter { request in
            captured.request = request
            return try Self.jsonResponse(
                for: request,
                body: #"{"task": {"id": "t-10", "title": "Full task", "status": "triage"}}"#
            )
        }

        let draft = KanbanCreateDraft(
            title: "Full task",
            body: "Details",
            assignee: "daneel",
            priority: 1,
            tenant: "acme",
            parentIDs: []
        )
        _ = try await writer.create(draft)

        let body = try Self.jsonBody(#require(captured.request))
        #expect(body["body"] as? String == "Details")
        #expect(body["assignee"] as? String == "daneel")
        #expect(body["tenant"] as? String == "acme")
        #expect((body["parents"] as? [String])?.isEmpty == true)
    }

    @Test
    func createThrowsDecodingFailedWhenResponseCarriesNoUsableTask() async throws {
        let writer = Self.makeWriter { request in
            try Self.jsonResponse(for: request, body: #"{"task": null}"#)
        }

        await #expect(throws: HermesDashboardClient.DashboardError.self) {
            _ = try await writer.create(KanbanCreateDraft(title: "Orphan"))
        }
    }

    // MARK: - Comment

    @Test
    func commentPostsToCommentsSubpathWithBody() async throws {
        let captured = Self.CapturedRequest()
        let writer = Self.makeWriter { request in
            captured.request = request
            return try Self.jsonResponse(for: request, body: "{}")
        }

        try await writer.comment(taskID: "t1", body: "looks good")

        let request = try #require(captured.request)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/plugins/kanban/tasks/t1/comments")
        let body = try Self.jsonBody(request)
        #expect(body["body"] as? String == "looks good")
        #expect(body.count == 1)
    }

    // MARK: - Complete / Block / Unblock / Promote / Archive / Assign

    @Test
    func completeSendsStatusDoneAndSummary() async throws {
        let captured = Self.CapturedRequest()
        let writer = Self.makeWriter { request in
            captured.request = request
            return try Self.jsonResponse(for: request, body: "{}")
        }

        try await writer.complete(taskID: "t1", summary: "shipped it")

        let request = try #require(captured.request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path == "/api/plugins/kanban/tasks/t1")
        let body = try Self.jsonBody(request)
        #expect(body["status"] as? String == "done")
        #expect(body["summary"] as? String == "shipped it")
        #expect(body.count == 2)
    }

    @Test
    func blockSendsStatusBlockedAndBlockReason() async throws {
        let captured = Self.CapturedRequest()
        let writer = Self.makeWriter { request in
            captured.request = request
            return try Self.jsonResponse(for: request, body: "{}")
        }

        try await writer.block(taskID: "t1", reason: "waiting on design")

        let request = try #require(captured.request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path == "/api/plugins/kanban/tasks/t1")
        let body = try Self.jsonBody(request)
        #expect(body["status"] as? String == "blocked")
        #expect(body["block_reason"] as? String == "waiting on design")
        #expect(body.count == 2)
    }

    /// `unblock` and `promote` issue an identical request — the plugin API
    /// has no dedicated promote endpoint — so both are asserted here.
    @Test
    func unblockAndPromoteBothSendStatusReadyOnly() async throws {
        let captured = Self.CapturedRequest()
        let writer = Self.makeWriter { request in
            captured.request = request
            return try Self.jsonResponse(for: request, body: "{}")
        }

        try await writer.unblock(taskID: "t1")
        var request = try #require(captured.request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path == "/api/plugins/kanban/tasks/t1")
        var body = try Self.jsonBody(request)
        #expect(body as? [String: String] == ["status": "ready"])

        captured.request = nil
        try await writer.promote(taskID: "t1")
        request = try #require(captured.request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path == "/api/plugins/kanban/tasks/t1")
        body = try Self.jsonBody(request)
        #expect(body as? [String: String] == ["status": "ready"])
    }

    @Test
    func archiveSendsStatusArchivedOnly() async throws {
        let captured = Self.CapturedRequest()
        let writer = Self.makeWriter { request in
            captured.request = request
            return try Self.jsonResponse(for: request, body: "{}")
        }

        try await writer.archive(taskID: "t1")

        let request = try #require(captured.request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path == "/api/plugins/kanban/tasks/t1")
        let body = try Self.jsonBody(request)
        #expect(body as? [String: String] == ["status": "archived"])
    }

    @Test
    func assignSendsAssigneeAndNoStatusKey() async throws {
        let captured = Self.CapturedRequest()
        let writer = Self.makeWriter { request in
            captured.request = request
            return try Self.jsonResponse(for: request, body: "{}")
        }

        try await writer.assign(taskID: "t1", assignee: "daneel")

        let request = try #require(captured.request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path == "/api/plugins/kanban/tasks/t1")
        let body = try Self.jsonBody(request)
        #expect(body["assignee"] as? String == "daneel")
        #expect(body.keys.contains("status") == false)
        #expect(body.count == 1)
    }

    // MARK: - Error propagation

    @Test
    func conflictResponseSurfacesAsDashboardError() async throws {
        let writer = Self.makeWriter { request in
            if request.url?.path == "/api/plugins/kanban/board" {
                return try Self.jsonResponse(for: request, body: "{}")
            }
            return try Self.jsonResponse(
                for: request,
                status: 409,
                body: #"{"detail":"task already completed"}"#
            )
        }

        await #expect(throws: HermesDashboardClient.DashboardError.self) {
            try await writer.complete(taskID: "t1", summary: "done")
        }
    }
}

// MARK: - Fixtures & helpers

private extension HTTPKanbanWriterTests {
    final class CapturedRequest: @unchecked Sendable {
        var request: URLRequest?
    }

    static func jsonResponse(
        for request: URLRequest,
        status: Int = 200,
        body: String
    ) throws -> (HTTPURLResponse, Data) {
        let response = try HTTPURLResponse(
            url: #require(request.url),
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    static func makeWriter(handler: @escaping MockURLProtocol.Handler) -> HTTPKanbanWriter {
        let client = HermesDashboardClient(
            baseURL: URL(string: "http://127.0.0.1:9119")!,
            credentials: nil,
            session: makeMockSession(handler: handler)
        )
        return HTTPKanbanWriter(client: client)
    }

    static func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody ?? request.bodyStreamData())
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private extension URLRequest {
    /// `URLProtocol` strips `httpBody` when a request streams; mirror it back from the stream.
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
}
