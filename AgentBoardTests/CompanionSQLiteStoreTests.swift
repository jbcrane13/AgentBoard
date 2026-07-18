@testable import AgentBoardCompanionKit
import AgentBoardCore
import Foundation
import SQLite3
import Testing

// swiftformat:disable:next modifierOrder
nonisolated private let testSqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct CompanionSQLiteStoreTests {
    @Test
    func makeSummariesGroupsSessionsByAgentModel() {
        let now = Date(timeIntervalSince1970: 1234)
        let sessions = [
            AgentSession(
                id: "proc-1",
                source: "Local Machine",
                status: .running,
                model: "Codex",
                startedAt: now,
                lastSeenAt: now
            ),
            AgentSession(
                id: "proc-2",
                source: "Local Machine",
                status: .running,
                model: "Claude",
                startedAt: now,
                lastSeenAt: now
            ),
            AgentSession(
                id: "proc-3",
                source: "Local Machine",
                status: .running,
                model: "Codex",
                startedAt: now,
                lastSeenAt: now
            )
        ]

        let summaries = CompanionLocalProbe.makeSummaries(
            sessions: sessions,
            now: now,
            machineName: "Local Machine"
        )

        #expect(summaries.map(\.name) == ["Codex", "Claude"])
        #expect(summaries.map(\.activeSessionCount) == [2, 1])
    }

    @Test
    func replaceSessionsAndAgents() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appending(path: "agentboard-tests-\(UUID().uuidString).sqlite")

        let store = try CompanionSQLiteStore(databaseURL: databaseURL)
        try await store.initializeSchema()

        let repository = ConfiguredRepository(owner: "openai", name: "agentboard")
        let workReference = WorkReference(repository: repository, issueNumber: 7)

        try await store.replaceSessions(
            [
                AgentSession(
                    id: "proc-7",
                    source: "Blake's MacBook Pro",
                    status: .running,
                    linkedTaskID: "task-7",
                    workItem: workReference,
                    model: "hermes-agent"
                )
            ]
        )

        try await store.replaceAgents(
            [
                AgentSummary(
                    id: "codex",
                    name: "Codex",
                    health: .online,
                    activeTaskCount: 1,
                    activeSessionCount: 1,
                    recentActivity: "Running locally."
                )
            ]
        )

        let sessions = try await store.listSessions()
        let agents = try await store.listAgents()

        #expect(sessions.count == 1)
        #expect(sessions[0].workItem?.issueReference == "openai/agentboard#7")
        #expect(agents.count == 1)
        #expect(agents[0].health == .online)
    }

    @Test
    func conversationSnapshotRoundTripsMessagesAndAttachments() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appending(path: "agentboard-conversations-\(UUID().uuidString).sqlite")

        let store = try CompanionSQLiteStore(databaseURL: databaseURL)
        try await store.initializeSchema()

        let conversationID = UUID()
        let conversation = ChatConversation(
            id: conversationID,
            title: "Cross-device chat",
            modelID: "hermes-agent",
            updatedAt: Date(timeIntervalSince1970: 1800)
        )
        let attachment = try ChatAttachment(
            id: "file-1",
            type: .file,
            state: .uploaded(remoteURL: #require(URL(string: "https://example.com/file.txt"))),
            payload: .file(FileAttachmentPayload(
                localURL: URL(fileURLWithPath: "/tmp/file.txt"),
                remoteURL: #require(URL(string: "https://example.com/file.txt")),
                fileName: "file.txt"
            ))
        )
        let messages = [
            ConversationMessage(
                conversationID: conversationID,
                role: .user,
                content: "Hello",
                createdAt: Date(timeIntervalSince1970: 1700),
                attachments: [attachment]
            ),
            ConversationMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "Hi",
                createdAt: Date(timeIntervalSince1970: 1701)
            )
        ]

        try await store.saveConversationSnapshot(conversation: conversation, messages: messages)

        let conversations = try await store.listConversations()
        let loadedMessages = try await store.loadMessages(conversationID: conversationID)

        #expect(conversations == [conversation])
        #expect(loadedMessages.map(\.content) == ["Hello", "Hi"])
        #expect(loadedMessages.first?.attachments.first?.id == "file-1")
        #expect(loadedMessages.first?.attachments.first?.remoteURL == URL(string: "https://example.com/file.txt"))
    }

    @Test
    func replaceConversationsRoundTripsHermesSessionIDWithAndWithoutValue() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appending(path: "agentboard-conversations-\(UUID().uuidString).sqlite")

        let store = try CompanionSQLiteStore(databaseURL: databaseURL)
        try await store.initializeSchema()

        let withSession = ChatConversation(
            title: "Bound to Hermes",
            updatedAt: Date(timeIntervalSince1970: 1900),
            hermesSessionID: "hermes-session-42"
        )
        let withoutSession = ChatConversation(
            title: "No Hermes binding",
            updatedAt: Date(timeIntervalSince1970: 1901)
        )

        try await store.replaceConversations([withSession, withoutSession])

        let conversations = try await store.listConversations()

        #expect(conversations.first { $0.id == withSession.id }?.hermesSessionID == "hermes-session-42")
        #expect(conversations.first { $0.id == withoutSession.id }?.hermesSessionID == nil)
    }

    @Test
    func saveConversationSnapshotRoundTripsHermesSessionID() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appending(path: "agentboard-conversations-\(UUID().uuidString).sqlite")

        let store = try CompanionSQLiteStore(databaseURL: databaseURL)
        try await store.initializeSchema()

        let conversationID = UUID()
        let conversation = ChatConversation(
            id: conversationID,
            title: "Snapshot with Hermes",
            modelID: "hermes-agent",
            updatedAt: Date(timeIntervalSince1970: 1902),
            hermesSessionID: "hermes-session-99"
        )

        try await store.saveConversationSnapshot(conversation: conversation, messages: [])

        let conversations = try await store.listConversations()

        #expect(conversations == [conversation])
        #expect(conversations.first?.hermesSessionID == "hermes-session-99")
    }

    @Test
    func migratesLegacyConversationsTableToAddHermesSessionIDColumn() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appending(path: "agentboard-legacy-conversations-\(UUID().uuidString).sqlite")

        // Hand-create the legacy 4-column schema (no hermes_session_id) before the store ever opens it.
        var legacyHandle: OpaquePointer?
        #expect(sqlite3_open_v2(
            databaseURL.path,
            &legacyHandle,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK)
        #expect(sqlite3_exec(
            legacyHandle,
            """
            CREATE TABLE conversations (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                model_id TEXT,
                updated_at REAL NOT NULL
            );
            """,
            nil, nil, nil
        ) == SQLITE_OK)
        let legacyID = UUID()
        var insertStatement: OpaquePointer?
        #expect(sqlite3_prepare_v2(
            legacyHandle,
            "INSERT INTO conversations (id, title, model_id, updated_at) VALUES (?, ?, ?, ?);",
            -1, &insertStatement, nil
        ) == SQLITE_OK)
        sqlite3_bind_text(insertStatement, 1, legacyID.uuidString, -1, testSqliteTransient)
        sqlite3_bind_text(insertStatement, 2, "Legacy conversation", -1, testSqliteTransient)
        sqlite3_bind_null(insertStatement, 3)
        sqlite3_bind_double(insertStatement, 4, 1500)
        #expect(sqlite3_step(insertStatement) == SQLITE_DONE)
        sqlite3_finalize(insertStatement)
        sqlite3_close(legacyHandle)

        // Opening the store over the legacy DB should migrate the schema in place.
        let store = try CompanionSQLiteStore(databaseURL: databaseURL)
        try await store.initializeSchema()

        let conversations = try await store.listConversations()

        #expect(conversations.count == 1)
        #expect(conversations.first?.id == legacyID)
        #expect(conversations.first?.title == "Legacy conversation")
        #expect(conversations.first?.hermesSessionID == nil)
    }

    @Test
    func companionClientUsesConversationRoutes() async throws {
        let conversationID = UUID()
        let client = CompanionClient(session: makeMockSession { request in
            let requestURL = try #require(request.url)
            let response = try HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/v1/conversations"):
                return (response, Data("[]".utf8))
            case ("GET", "/v1/conversations/\(conversationID.uuidString)/messages"):
                return (response, Data("[]".utf8))
            case ("POST", "/v1/conversations/sync"):
                #expect(request.httpBody != nil || request.bodyStreamData() != nil)
                return (response, Data(#"{"ok":true}"#.utf8))
            case ("DELETE", "/v1/conversations/\(conversationID.uuidString)"):
                return (response, Data(#"{"ok":true}"#.utf8))
            default:
                let failingResponse = try HTTPURLResponse(
                    url: requestURL,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (failingResponse, Data("unexpected route".utf8))
            }
        })

        try await client.configure(baseURL: "http://companion.test:8742", bearerToken: nil)

        _ = try await client.listConversations()
        _ = try await client.loadMessages(conversationID: conversationID)
        try await client.syncConversations(conversations: [], messagesByConversation: [:])
        try await client.deleteConversationOnServer(id: conversationID)
    }

    @Test
    func companionClientRoundTripsHermesSessionIDInBothSyncDirections() async throws {
        let conversation = ChatConversation(
            title: "Bound conversation",
            updatedAt: Date(timeIntervalSince1970: 2000),
            hermesSessionID: "hermes-session-round-trip"
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let client = CompanionClient(session: makeMockSession { request in
            let requestURL = try #require(request.url)
            let response = try HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/v1/conversations"):
                // Pull direction: companion -> app must preserve hermesSessionID.
                return try (response, encoder.encode([conversation]))
            case ("POST", "/v1/conversations/sync"):
                // Push direction: app -> companion must send hermesSessionID on the wire.
                let bodyData = try #require(request.httpBody ?? request.bodyStreamData())
                let payload = try decoder.decode(ConversationSyncPayload.self, from: bodyData)
                #expect(payload.conversations.first?.hermesSessionID == "hermes-session-round-trip")
                return (response, Data(#"{"ok":true}"#.utf8))
            default:
                let failingResponse = try HTTPURLResponse(
                    url: requestURL,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (failingResponse, Data("unexpected route".utf8))
            }
        })

        try await client.configure(baseURL: "http://companion.test:8742", bearerToken: nil)

        let pulled = try await client.listConversations()
        #expect(pulled.first?.hermesSessionID == "hermes-session-round-trip")

        try await client.syncConversations(conversations: [conversation], messagesByConversation: [:])
    }
}

private extension URLRequest {
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
