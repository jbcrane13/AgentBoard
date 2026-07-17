import AgentBoardCore
import Foundation
import Testing

@Suite(.serialized)
struct HermesGatewayClientTests {
    @Test
    func healthCheckSucceeds() async throws {
        let client = HermesGatewayClient(session: makeMockSession { request in
            #expect(request.url?.path == "/health")
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        })
        try await client.configure(
            baseURL: "http://127.0.0.1:8642",
            apiKey: "token",
            preferredModelID: "hermes-agent"
        )

        let healthy = try await client.healthCheck()
        #expect(healthy)
    }

    @Test
    func fetchModelsDecodesIDs() async throws {
        let client = HermesGatewayClient(session: makeMockSession { request in
            #expect(request.url?.path == "/v1/models")
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = """
            {
              "data": [
                {"id": "hermes-agent"},
                {"id": "hermes-reasoner"}
              ]
            }
            """
            return (response, Data(payload.utf8))
        })
        try await client.configure(
            baseURL: "http://127.0.0.1:8642",
            apiKey: nil,
            preferredModelID: "hermes-agent"
        )

        let models = try await client.fetchModels()
        #expect(models == ["hermes-agent", "hermes-reasoner"])
    }

    @Test
    func fetchSkillsDecodesNameAndDescription() async throws {
        let client = HermesGatewayClient(session: makeMockSession { request in
            #expect(request.url?.path == "/v1/skills")
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let longDescription = String(repeating: "x", count: 150)
            let payload = """
            {
              "object": "list",
              "data": [
                {"name": "code-review", "description": "Reviews a diff.", "category": null},
                {"name": "deep-research", "description": "\(longDescription)", "category": "research"}
              ]
            }
            """
            return (response, Data(payload.utf8))
        })
        try await client.configure(
            baseURL: "http://127.0.0.1:8642",
            apiKey: nil,
            preferredModelID: "hermes-agent"
        )

        let skills = try await client.fetchSkills()
        #expect(skills == [
            HermesSkill(name: "code-review", description: "Reviews a diff."),
            HermesSkill(name: "deep-research", description: String(repeating: "x", count: 150))
        ])
    }

    @Test
    func streamReplyYieldsStreamingContent() async throws {
        let client = HermesGatewayClient(session: makeMockSession { request in
            #expect(request.url?.path == "/v1/chat/completions")
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let payload = """
            data: {"choices":[{"delta":{"content":"Fresh"},"finish_reason":null}]}

            data: {"choices":[{"delta":{"content":" reply"},"finish_reason":null}]}

            data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

            data: [DONE]

            """
            return (response, Data(payload.utf8))
        })
        try await client.configure(
            baseURL: "http://127.0.0.1:8642",
            apiKey: nil,
            preferredModelID: "hermes-agent"
        )

        let stream = try await client.streamReply(
            for: [
                ConversationMessage(conversationID: UUID(), role: .user, content: "Hello")
            ]
        )

        var combined = ""
        for try await event in stream {
            if case let .text(chunk) = event {
                combined += chunk
            }
        }

        #expect(combined == "Fresh reply")
    }

    @Test
    func streamReplyYieldsTextAndToolProgressEventsInOrder() async throws {
        let client = HermesGatewayClient(session: makeMockSession { request in
            #expect(request.url?.path == "/v1/chat/completions")
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let payload = """
            data: {"choices":[{"delta":{"content":"Fresh"},"finish_reason":null}]}

            event: hermes.tool.progress
            data: {"tool":"web_search","emoji":"🔍","label":"Searching the web…","toolCallId":"call_1","status":"running"}

            event: hermes.tool.progress
            data: {"tool":"web_search","toolCallId":"call_1","status":"completed"}

            data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

            data: [DONE]

            """
            return (response, Data(payload.utf8))
        })
        try await client.configure(
            baseURL: "http://127.0.0.1:8642",
            apiKey: nil,
            preferredModelID: "hermes-agent"
        )

        let stream = try await client.streamReply(
            for: [
                ConversationMessage(conversationID: UUID(), role: .user, content: "Hello")
            ]
        )

        var events: [HermesStreamEvent] = []
        for try await event in stream {
            events.append(event)
        }

        #expect(events == [
            .text("Fresh"),
            .toolProgress(HermesToolProgress(
                tool: "web_search",
                emoji: "🔍",
                label: "Searching the web…",
                toolCallId: "call_1",
                status: "running"
            )),
            .toolProgress(HermesToolProgress(
                tool: "web_search",
                emoji: nil,
                label: nil,
                toolCallId: "call_1",
                status: "completed"
            ))
        ])
    }

    @Test
    func streamReplySkipsMalformedToolProgressJSON() async throws {
        let client = HermesGatewayClient(session: makeMockSession { request in
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let payload = """
            event: hermes.tool.progress
            data: {"tool":"web_search"}

            data: {"choices":[{"delta":{"content":"Hi"},"finish_reason":null}]}

            data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

            data: [DONE]

            """
            return (response, Data(payload.utf8))
        })
        try await client.configure(
            baseURL: "http://127.0.0.1:8642",
            apiKey: nil,
            preferredModelID: "hermes-agent"
        )

        let stream = try await client.streamReply(
            for: [
                ConversationMessage(conversationID: UUID(), role: .user, content: "Hello")
            ]
        )

        var events: [HermesStreamEvent] = []
        for try await event in stream {
            events.append(event)
        }

        #expect(events == [.text("Hi")])
    }

    @Test
    func streamReplyThrowsEmptyAssistantResponseWhenOnlyToolEventsArrive() async throws {
        let client = HermesGatewayClient(session: makeMockSession { request in
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let payload = """
            event: hermes.tool.progress
            data: {"tool":"web_search","emoji":"🔍","label":"Searching…","toolCallId":"call_1","status":"running"}

            event: hermes.tool.progress
            data: {"tool":"web_search","toolCallId":"call_1","status":"completed"}

            """
            return (response, Data(payload.utf8))
        })
        try await client.configure(
            baseURL: "http://127.0.0.1:8642",
            apiKey: nil,
            preferredModelID: "hermes-agent"
        )

        let stream = try await client.streamReply(
            for: [
                ConversationMessage(conversationID: UUID(), role: .user, content: "Hello")
            ]
        )

        do {
            for try await _ in stream {}
            Issue.record("Expected emptyAssistantResponse to be thrown")
        } catch let error as HermesGatewayClient.ClientError {
            #expect(error == .emptyAssistantResponse)
        }
    }
}
