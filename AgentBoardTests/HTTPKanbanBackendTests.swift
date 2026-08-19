import AgentBoardCore
import Foundation
import Testing

@Suite(.serialized)
struct HTTPKanbanBackendTests {
    // MARK: - fetchTasks / fetchLatestEventID (no-auth dashboard)

    @Test
    func fetchTasksMapsStatusAndRichFieldsAcrossColumns() async throws {
        let backend = Self.makeBackend(boardJSON: Self.richBoardJSON)

        let tasks = try await backend.fetchTasks()
        #expect(tasks.count == 3)

        let running = try #require(tasks.first { $0.id == "t-running-1" })
        #expect(running.status == .running)
        #expect(running.branchName == "agentboard/t-running-1")
        #expect(running.sessionID == "sess-123")
        #expect(running.goalMode == true)
        #expect(running.consecutiveFailures == 2)
        #expect(running.lastHeartbeatAt == Date(timeIntervalSince1970: 1_700_000_200))
        #expect(running.modelOverride == "claude-opus")
        #expect(running.lastFailureError == "timeout")

        let triage = try #require(tasks.first { $0.id == "t-triage-1" })
        #expect(triage.status == .triage)
        let done = try #require(tasks.first { $0.id == "t-done-1" })
        #expect(done.status == .done)
    }

    /// `GET /board` has no archived column, so the backend must refuse rather
    /// than quietly answer with the non-archived subset. Verified live: the
    /// remote host holds 7 archived tasks the board endpoint never returns.
    @Test
    func fetchTasksRefusesToIncludeArchivedBecauseTheBoardEndpointOmitsThem() async throws {
        let backend = Self.makeBackend(boardJSON: Self.richBoardJSON)

        await #expect(throws: HermesDashboardClient.DashboardError.self) {
            try await backend.fetchTasks(status: nil, tenant: nil, excludeArchived: false)
        }
    }

    @Test
    func fetchTasksAppliesClientSideStatusAndTenantFilters() async throws {
        let backend = Self.makeBackend(boardJSON: Self.richBoardJSON)

        let all = try await backend.fetchTasks(status: nil, tenant: nil, excludeArchived: true)
        #expect(all.count == 3)
        #expect(!all.contains { $0.status == .archived })

        let runningOnly = try await backend.fetchTasks(status: .running, tenant: nil, excludeArchived: true)
        #expect(runningOnly.map(\.id) == ["t-running-1"])

        let betaOnly = try await backend.fetchTasks(status: nil, tenant: "beta", excludeArchived: true)
        #expect(betaOnly.map(\.id) == ["t-done-1"])
    }

    @Test
    func fetchLatestEventIDReturnsBoardPayloadValue() async throws {
        let backend = Self.makeBackend(boardJSON: Self.richBoardJSON)
        #expect(try await backend.fetchLatestEventID() == 42)
    }

    // MARK: - fetchComments / fetchRuns / fetchEvents / fetchLinks (task detail)

    @Test
    func taskDetailSortsCommentsAscendingEventsDescendingAndHonoursLimit() async throws {
        let backend = Self.makeBackend(
            taskDetailPath: "/api/plugins/kanban/tasks/t1",
            taskDetailJSON: Self.taskDetailJSON
        )

        let comments = try await backend.fetchComments(for: "t1")
        #expect(comments.map(\.id) == [1, 2])
        #expect(comments.map(\.body) == ["first", "second"])

        let allEvents = try await backend.fetchEvents(taskID: "t1", limit: 50)
        #expect(allEvents.map(\.id) == [3, 2, 1])

        let limitedEvents = try await backend.fetchEvents(taskID: "t1", limit: 2)
        #expect(limitedEvents.map(\.id) == [3, 2])

        let runs = try await backend.fetchRuns(for: "t1")
        #expect(runs.count == 1)
        #expect(runs[0].outcome == .completed)
        #expect(runs[0].summary == "ok")

        let links = try await backend.fetchLinks(for: "t1")
        #expect(links.parents == ["p1"])
        #expect(links.children == ["c1", "c2"])
    }

    // MARK: - Drift tolerance

    @Test
    func fetchTasksToleratesUnknownAndMissingKeys() async throws {
        let json = """
        {
          "columns": [
            {
              "name": "todo",
              "unexpected_column_field": true,
              "tasks": [
                {
                  "id": "t-extra",
                  "title": "Extra keys task",
                  "status": "todo",
                  "totally_new_field": "surprise",
                  "nested": {"a": 1}
                },
                {"id": "t-bare", "title": "Bare task"}
              ]
            }
          ],
          "latest_event_id": 7,
          "totally_unknown_top_level": {"whatever": [1, 2, 3]}
        }
        """
        let backend = Self.makeBackend(boardJSON: json)

        let tasks = try await backend.fetchTasks()
        #expect(tasks.count == 2)

        let bare = try #require(tasks.first { $0.id == "t-bare" })
        #expect(bare.status == .todo)
        #expect(bare.priority == 0)
        #expect(bare.consecutiveFailures == 0)
        #expect(bare.goalMode == false)
        #expect(bare.branchName == nil)
    }

    @Test
    func taskDetailToleratesUnknownAndMissingKeys() async throws {
        let json = """
        {
          "task": {"id": "t1", "unexpected": true},
          "comments": [
            {"id": 1, "task_id": "t1", "author": "daneel", "body": "hi", "created_at": 1700000000, "extra_field": "x"}
          ],
          "runs": [],
          "links": {},
          "events": [],
          "attachments": [{"whatever": true}],
          "child_results": null
        }
        """
        let backend = Self.makeBackend(taskDetailPath: "/api/plugins/kanban/tasks/t1", taskDetailJSON: json)

        let comments = try await backend.fetchComments(for: "t1")
        #expect(comments.count == 1)
        #expect(comments[0].author == "daneel")

        let links = try await backend.fetchLinks(for: "t1")
        #expect(links.parents.isEmpty)
        #expect(links.children.isEmpty)

        let runs = try await backend.fetchRuns(for: "t1")
        #expect(runs.isEmpty)
    }

    // MARK: - Auth-mode detection

    @Test
    func detectsUngatedLoopbackAuthAndAttachesSessionToken() async throws {
        let client = try HermesDashboardClient(
            baseURL: #require(URL(string: "http://127.0.0.1:9119")),
            credentials: nil,
            session: makeMockSession(handler: Self.makeLoopbackTokenHandler(
                boardJSON: Self.minimalBoardJSON,
                token: "tok-abc"
            ))
        )
        let backend = HTTPKanbanBackend(client: client)

        #expect(try await backend.fetchLatestEventID() == 7)
    }

    @Test
    func detectsGatedAuthLogsInWithDiscoveredProviderAndAttachesCookie() async throws {
        let client = try HermesDashboardClient(
            baseURL: #require(URL(string: "http://127.0.0.1:9119")),
            credentials: .init(username: "daneel", password: "secret"),
            session: makeMockSession(handler: Self.makeGatedHandler(boardJSON: Self.minimalBoardJSON))
        )
        let backend = HTTPKanbanBackend(client: client)

        #expect(try await backend.fetchLatestEventID() == 7)
    }

    @Test
    func noAuthHostAnswersDirectlyWithoutAnyLoginHop() async throws {
        let backend = Self.makeBackend(boardJSON: Self.minimalBoardJSON)
        #expect(try await backend.fetchLatestEventID() == 7)
    }

    // MARK: - 401 retry

    @Test
    func secondConsecutive401AfterReauthThrowsNotAuthenticated() async throws {
        let counter = Self.CallCounter()
        let client = try HermesDashboardClient(
            baseURL: #require(URL(string: "http://127.0.0.1:9119")),
            credentials: .init(username: "daneel", password: "secret"),
            session: makeMockSession(handler: Self.makeAlwaysUnauthorizedGatedHandler(counter: counter))
        )
        let backend = HTTPKanbanBackend(client: client)

        await #expect(throws: HermesDashboardClient.DashboardError.self) {
            _ = try await backend.fetchLatestEventID()
        }

        // One proactive login before the first `get()` attempt, one reactive
        // login after that attempt's 401 — never a third, i.e. no unbounded
        // retry loop. Board is hit 3 times: the unauthenticated detection
        // probe, `get()`'s initial (authenticated but still-401) attempt,
        // and its single retry — never a fourth.
        #expect(counter.loginAttempts == 2)
        #expect(counter.boardAttempts == 3)
    }
}

// MARK: - Fixtures & mock handlers

private extension HTTPKanbanBackendTests {
    final class CallCounter: @unchecked Sendable {
        var boardAttempts = 0
        var loginAttempts = 0
    }

    static let richBoardJSON = """
    {
      "columns": [
        {
          "name": "triage",
          "tasks": [
            {"id": "t-triage-1", "title": "Triage task", "status": "triage", "tenant": "acme", "priority": 1}
          ]
        },
        {
          "name": "running",
          "tasks": [
            {
              "id": "t-running-1",
              "title": "Running task",
              "status": "running",
              "tenant": "acme",
              "branch_name": "agentboard/t-running-1",
              "session_id": "sess-123",
              "goal_mode": 1,
              "consecutive_failures": 2,
              "last_heartbeat_at": 1700000200,
              "model_override": "claude-opus",
              "last_failure_error": "timeout"
            }
          ]
        },
        {
          "name": "done",
          "tasks": [
            {"id": "t-done-1", "title": "Done task", "status": "done", "tenant": "beta"}
          ]
        },
        {
          "name": "archived",
          "tasks": [
            {"id": "t-archived-1", "title": "Archived task", "status": "archived", "tenant": "acme"}
          ]
        }
      ],
      "tenants": ["acme", "beta"],
      "assignees": [],
      "latest_event_id": 42,
      "now": 1700000000
    }
    """

    static let taskDetailJSON = """
    {
      "comments": [
        {"id": 2, "task_id": "t1", "author": "daneel", "body": "second", "created_at": 1700000100},
        {"id": 1, "task_id": "t1", "author": "daneel", "body": "first", "created_at": 1700000000}
      ],
      "runs": [
        {
          "id": 1, "task_id": "t1", "profile": "claude", "status": "completed",
          "started_at": 1700000000, "ended_at": 1700000050,
          "outcome": "completed", "summary": "ok", "error": null
        }
      ],
      "links": {"parents": ["p1"], "children": ["c1", "c2"]},
      "events": [
        {"id": 1, "kind": "started", "payload": null, "created_at": 1700000000},
        {"id": 2, "kind": "progress", "payload": "{}", "created_at": 1700000010},
        {"id": 3, "kind": "finished", "payload": "{}", "created_at": 1700000020}
      ]
    }
    """

    static let minimalBoardJSON = """
    {"columns": [], "latest_event_id": 7, "now": 1700000000}
    """

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

    static func makeBackend(boardJSON: String) -> HTTPKanbanBackend {
        let client = HermesDashboardClient(
            baseURL: URL(string: "http://127.0.0.1:9119")!,
            credentials: nil,
            session: makeMockSession { request in
                try jsonResponse(
                    for: request,
                    status: 200,
                    body: boardJSON,
                    headers: ["Content-Type": "application/json"]
                )
            }
        )
        return HTTPKanbanBackend(client: client)
    }

    static func makeBackend(taskDetailPath: String, taskDetailJSON: String) -> HTTPKanbanBackend {
        let client = HermesDashboardClient(
            baseURL: URL(string: "http://127.0.0.1:9119")!,
            credentials: nil,
            session: makeMockSession { request in
                let body = request.url?.path == taskDetailPath ? taskDetailJSON : "{}"
                return try jsonResponse(
                    for: request,
                    status: 200,
                    body: body,
                    headers: ["Content-Type": "application/json"]
                )
            }
        )
        return HTTPKanbanBackend(client: client)
    }

    /// Every request that reaches `/api/plugins/kanban/board` without an
    /// `X-Hermes-Session-Token` header 401s with the bare
    /// `{"detail":"Unauthorized"}` body the ungated/loopback dashboard sends;
    /// `GET /` serves the SPA HTML carrying the scraped session token.
    static func makeLoopbackTokenHandler(
        boardJSON: String,
        token: String
    ) -> MockURLProtocol.Handler {
        { request in
            guard request.url?.path == "/api/plugins/kanban/board" else {
                // Anything other than the board path is the dashboard root
                // (`URL(string: "http://host:port")!.path` is `""`, not
                // `"/"`), which serves the SPA HTML carrying the token.
                return try jsonResponse(
                    for: request,
                    status: 200,
                    body: "<html><script>window.__HERMES_SESSION_TOKEN__=\"\(token)\";</script></html>"
                )
            }

            if request.value(forHTTPHeaderField: "X-Hermes-Session-Token") == token {
                return try jsonResponse(
                    for: request,
                    status: 200,
                    body: boardJSON,
                    headers: ["Content-Type": "application/json"]
                )
            }
            return try jsonResponse(for: request, status: 401, body: #"{"detail":"Unauthorized"}"#)
        }
    }

    /// Every request that reaches `/api/plugins/kanban/board` without the
    /// login-issued `Cookie` header 401s with the gated body carrying
    /// `"reason":"no_cookie"`; `/api/auth/providers` and
    /// `POST /auth/password-login` implement the gated login handshake.
    static func makeGatedHandler(
        boardJSON: String,
        cookieValue: String = "hermes_session_at=abc123"
    ) -> MockURLProtocol.Handler {
        { request in
            switch request.url?.path {
            case "/api/auth/providers":
                return try jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"providers":[{"name":"basic","display_name":"Username & Password","supports_password":true}]}"#,
                    headers: ["Content-Type": "application/json"]
                )
            case "/auth/password-login":
                #expect(request.httpMethod == "POST")
                return try jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"ok":true,"next":"/"}"#,
                    headers: ["Set-Cookie": "\(cookieValue); Path=/; HttpOnly"]
                )
            case "/api/plugins/kanban/board":
                if let cookie = request.value(forHTTPHeaderField: "Cookie"), cookie.contains(cookieValue) {
                    return try jsonResponse(
                        for: request,
                        status: 200,
                        body: boardJSON,
                        headers: ["Content-Type": "application/json"]
                    )
                }
                return try jsonResponse(
                    for: request,
                    status: 401,
                    body: #"{"error":"unauthenticated","reason":"no_cookie","login_url":"/login"}"#
                )
            default:
                Issue.record("unexpected request path \(request.url?.path ?? "?")")
                throw URLError(.unsupportedURL)
            }
        }
    }

    /// Login always "succeeds" (issues a cookie), but the board endpoint
    /// 401s unconditionally — modelling a session that can't actually be
    /// recovered — to prove `get()` retries at most once before throwing.
    static func makeAlwaysUnauthorizedGatedHandler(counter: CallCounter) -> MockURLProtocol.Handler {
        { request in
            switch request.url?.path {
            case "/api/auth/providers":
                return try jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"providers":[{"name":"basic","supports_password":true}]}"#,
                    headers: ["Content-Type": "application/json"]
                )
            case "/auth/password-login":
                counter.loginAttempts += 1
                return try jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"ok":true}"#,
                    headers: ["Set-Cookie": "hermes_session_at=abc; Path=/"]
                )
            case "/api/plugins/kanban/board":
                counter.boardAttempts += 1
                return try jsonResponse(
                    for: request,
                    status: 401,
                    body: #"{"error":"unauthenticated","reason":"no_cookie","login_url":"/login"}"#
                )
            default:
                Issue.record("unexpected request path \(request.url?.path ?? "?")")
                throw URLError(.unsupportedURL)
            }
        }
    }
}
