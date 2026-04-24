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
        for try await chunk in stream {
            combined += chunk
        }

        #expect(combined == "Fresh reply")
    }
}
