import AgentBoardCore
import Foundation
import Testing

@Suite(.serialized)
struct HermesDashboardClientTests {
    // MARK: - post / patch send the right method, body, and headers

    @Test
    func postSendsMethodBodyContentTypeAndDecodesResponse() async throws {
        let recorder = RequestRecorder()
        let client = try HermesDashboardClient(
            baseURL: #require(URL(string: "http://127.0.0.1:9119")),
            credentials: nil,
            session: makeMockSession { request in
                recorder.record(request)
                if request.url?.path == "/api/plugins/kanban/board" {
                    return try Self.jsonResponse(for: request, status: 200, body: "{}")
                }
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"ok":true,"received":"hello"}"#,
                    headers: ["Content-Type": "application/json"]
                )
            }
        )

        let response: Self.EchoResponse = try await client.post(
            "api/plugins/kanban/tasks",
            body: Self.EchoBody(name: "hello", value: 1),
            as: Self.EchoResponse.self
        )

        #expect(response == Self.EchoResponse(ok: true, received: "hello"))

        let taskRequests = recorder.all.filter { $0.path == "/api/plugins/kanban/tasks" }
        #expect(taskRequests.count == 1)
        let sent = try #require(taskRequests.first)
        #expect(sent.method == "POST")
        #expect(sent.contentType == "application/json")
        let sentBody = try Self.decodeEchoBody(sent.body)
        #expect(sentBody == Self.EchoBody(name: "hello", value: 1))
    }

    @Test
    func patchSendsMethodPatchBodyAndDecodesResponse() async throws {
        let recorder = RequestRecorder()
        let client = try HermesDashboardClient(
            baseURL: #require(URL(string: "http://127.0.0.1:9119")),
            credentials: nil,
            session: makeMockSession { request in
                recorder.record(request)
                if request.url?.path == "/api/plugins/kanban/board" {
                    return try Self.jsonResponse(for: request, status: 200, body: "{}")
                }
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"ok":true,"received":"patched"}"#,
                    headers: ["Content-Type": "application/json"]
                )
            }
        )

        let response: Self.EchoResponse = try await client.patch(
            "api/plugins/kanban/tasks/t1",
            body: Self.EchoBody(name: "patched", value: 2),
            as: Self.EchoResponse.self
        )

        #expect(response == Self.EchoResponse(ok: true, received: "patched"))

        let taskRequests = recorder.all.filter { $0.path == "/api/plugins/kanban/tasks/t1" }
        #expect(taskRequests.count == 1)
        let sent = try #require(taskRequests.first)
        #expect(sent.method == "PATCH")
        #expect(sent.contentType == "application/json")
        let sentBody = try Self.decodeEchoBody(sent.body)
        #expect(sentBody == Self.EchoBody(name: "patched", value: 2))
    }

    // MARK: - Single-retry-after-401 for mutating requests

    @Test
    func mutatingRequestReauthenticatesOnceAfterGated401AndRetriesSameMethodAndBody() async throws {
        let recorder = RequestRecorder()
        let attempts = AttemptCounter()
        let cookieValue = "hermes_session_at=abc123"
        let client = try HermesDashboardClient(
            baseURL: #require(URL(string: "http://127.0.0.1:9119")),
            credentials: .init(username: "daneel", password: "secret"),
            session: makeMockSession { request in
                recorder.record(request)
                switch request.url?.path {
                case "/api/plugins/kanban/board":
                    return try Self.jsonResponse(
                        for: request,
                        status: 401,
                        body: #"{"error":"unauthenticated","reason":"no_cookie","login_url":"/login"}"#
                    )
                case "/api/auth/providers":
                    return try Self.jsonResponse(
                        for: request,
                        status: 200,
                        body: #"{"providers":[{"name":"basic","supports_password":true}]}"#,
                        headers: ["Content-Type": "application/json"]
                    )
                case "/auth/password-login":
                    return try Self.jsonResponse(
                        for: request,
                        status: 200,
                        body: #"{"ok":true}"#,
                        headers: ["Set-Cookie": "\(cookieValue); Path=/; HttpOnly"]
                    )
                case "/api/plugins/kanban/tasks/t1/comments":
                    // The first hit against the target endpoint 401s even
                    // though a cookie from the proactive login is already
                    // attached, modelling a session that expired between
                    // login and the mutating call; the second hit (after
                    // reauthentication) succeeds.
                    if attempts.increment() == 1 {
                        return try Self.jsonResponse(
                            for: request,
                            status: 401,
                            body: #"{"error":"unauthenticated","reason":"no_cookie","login_url":"/login"}"#
                        )
                    }
                    return try Self.jsonResponse(
                        for: request,
                        status: 200,
                        body: #"{"ok":true,"received":"hi"}"#,
                        headers: ["Content-Type": "application/json"]
                    )
                default:
                    Issue.record("unexpected request path \(request.url?.path ?? "?")")
                    throw URLError(.unsupportedURL)
                }
            }
        )

        let response: Self.EchoResponse = try await client.post(
            "api/plugins/kanban/tasks/t1/comments",
            body: Self.EchoBody(name: "hi", value: 3),
            as: Self.EchoResponse.self
        )
        #expect(response == Self.EchoResponse(ok: true, received: "hi"))

        let commentRequests = recorder.all.filter { $0.path == "/api/plugins/kanban/tasks/t1/comments" }
        #expect(commentRequests.count == 2)
        for sent in commentRequests {
            #expect(sent.method == "POST")
            #expect(sent.contentType == "application/json")
            let sentBody = try Self.decodeEchoBody(sent.body)
            #expect(sentBody == Self.EchoBody(name: "hi", value: 3))
        }
    }

    @Test
    func twoConsecutive401sOnMutatingRequestThrowNotAuthenticatedWithoutThirdAttempt() async throws {
        let recorder = RequestRecorder()
        let attempts = AttemptCounter()
        let client = try HermesDashboardClient(
            baseURL: #require(URL(string: "http://127.0.0.1:9119")),
            credentials: .init(username: "daneel", password: "secret"),
            session: makeMockSession { request in
                recorder.record(request)
                switch request.url?.path {
                case "/api/plugins/kanban/board":
                    return try Self.jsonResponse(
                        for: request,
                        status: 401,
                        body: #"{"error":"unauthenticated","reason":"no_cookie","login_url":"/login"}"#
                    )
                case "/api/auth/providers":
                    return try Self.jsonResponse(
                        for: request,
                        status: 200,
                        body: #"{"providers":[{"name":"basic","supports_password":true}]}"#,
                        headers: ["Content-Type": "application/json"]
                    )
                case "/auth/password-login":
                    return try Self.jsonResponse(
                        for: request,
                        status: 200,
                        body: #"{"ok":true}"#,
                        headers: ["Set-Cookie": "hermes_session_at=abc; Path=/"]
                    )
                case "/api/plugins/kanban/tasks/t1":
                    attempts.increment()
                    return try Self.jsonResponse(
                        for: request,
                        status: 401,
                        body: #"{"error":"unauthenticated","reason":"no_cookie","login_url":"/login"}"#
                    )
                default:
                    Issue.record("unexpected request path \(request.url?.path ?? "?")")
                    throw URLError(.unsupportedURL)
                }
            }
        )

        await #expect(throws: HermesDashboardClient.DashboardError.self) {
            let _: Self.EchoResponse = try await client.patch(
                "api/plugins/kanban/tasks/t1",
                body: Self.EchoBody(name: "x", value: 0),
                as: Self.EchoResponse.self
            )
        }

        #expect(attempts.count == 2)
        let targetRequests = recorder.all.filter { $0.path == "/api/plugins/kanban/tasks/t1" }
        #expect(targetRequests.count == 2)
        #expect(targetRequests.allSatisfy { $0.method == "PATCH" })
    }

    // MARK: - Non-2xx, non-401 failures surface the response body

    @Test
    func conflictResponseThrowsRequestFailedCarryingResponseBody() async throws {
        let client = try HermesDashboardClient(
            baseURL: #require(URL(string: "http://127.0.0.1:9119")),
            credentials: nil,
            session: makeMockSession { request in
                if request.url?.path == "/api/plugins/kanban/board" {
                    return try Self.jsonResponse(for: request, status: 200, body: "{}")
                }
                return try Self.jsonResponse(
                    for: request,
                    status: 409,
                    body: #"{"error":"conflict","detail":"task already archived"}"#,
                    headers: ["Content-Type": "application/json"]
                )
            }
        )

        do {
            let _: Self.EchoResponse = try await client.patch(
                "api/plugins/kanban/tasks/t1",
                body: Self.EchoBody(name: "x", value: 0),
                as: Self.EchoResponse.self
            )
            Issue.record("expected patch to throw requestFailed")
        } catch let HermesDashboardClient.DashboardError.requestFailed(message) {
            #expect(message.contains("task already archived"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

// MARK: - Fixtures & mock handlers

private extension HermesDashboardClientTests {
    struct EchoBody: Codable, Sendable, Equatable {
        let name: String
        let value: Int
    }

    struct EchoResponse: Decodable, Equatable {
        let ok: Bool
        let received: String
    }

    struct RecordedRequest: Sendable {
        let method: String
        let path: String
        let body: String?
        let contentType: String?
    }

    /// Records every request the mock session sees, in order, so tests can
    /// assert on the full sequence (proactive login, first attempt, reactive
    /// login, retry) instead of only the final decoded value.
    final class RequestRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [RecordedRequest] = []

        func record(_ request: URLRequest) {
            lock.lock()
            defer { lock.unlock() }
            storage.append(RecordedRequest(
                method: request.httpMethod ?? "?",
                path: request.url?.path ?? "?",
                body: (request.httpBody ?? request.bodyStreamData()).flatMap { String(data: $0, encoding: .utf8) },
                contentType: request.value(forHTTPHeaderField: "Content-Type")
            ))
        }

        var all: [RecordedRequest] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    final class AttemptCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        @discardableResult
        func increment() -> Int {
            lock.lock()
            defer { lock.unlock() }
            value += 1
            return value
        }

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    static func decodeEchoBody(_ text: String?) throws -> EchoBody {
        let data = try #require(text?.data(using: .utf8))
        return try JSONDecoder().decode(EchoBody.self, from: data)
    }

    static func jsonResponse(
        for request: URLRequest,
        status: Int,
        body: String,
        headers: [String: String] = [:]
    ) throws -> (HTTPURLResponse, Data) {
        let response = try HTTPURLResponse(
            url: #require(request.url),
            statusCode: status,
            httpVersion: nil,
            headerFields: headers
        )!
        return (response, Data(body.utf8))
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
