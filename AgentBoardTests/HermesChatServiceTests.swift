@testable import AgentBoard
import Foundation
import Testing

@Suite(.serialized)
struct HermesChatServiceTests {
    @Test("healthCheck returns true for a healthy Hermes gateway")
    func healthCheckReturnsTrue() async throws {
        let session = makeMockSession()
        let service = HermesChatService(session: session)
        try await service.configure(gatewayURLString: "http://agentboard.test:8642", apiKey: nil)

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "http://agentboard.test:8642/health")
            return (mockResponse(statusCode: 200, url: request.url!), Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        let healthy = try await service.healthCheck()
        #expect(healthy == true)
    }

    @Test("streamChat parses SSE delta chunks and forwards auth")
    func streamChatParsesChunks() async throws {
        let session = makeMockSession()
        let service = HermesChatService(session: session)
        try await service.configure(gatewayURLString: "http://agentboard.test:8642", apiKey: "secret")

        let history = [
            ChatMessage(role: .assistant, content: "Previous reply")
        ]
        let eventStream = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}
        data: {"choices":[{"delta":{"content":" world"}}]}
        data: [DONE]

        """

        MockURLProtocol.requestHandler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
            #expect(request.url?.absoluteString == "http://agentboard.test:8642/v1/chat/completions")

            guard let body = request.httpBody,
                  let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let messages = payload["messages"] as? [[String: String]] else {
                Issue.record("Expected a valid JSON chat payload.")
                return (mockResponse(statusCode: 500, url: request.url!), Data())
            }

            #expect(messages.count == 2)
            #expect(messages[0]["role"] == "assistant")
            #expect(messages[1]["role"] == "user")
            #expect(messages[1]["content"] == "Hi Hermes")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            return (response, Data(eventStream.utf8))
        }
        defer { MockURLProtocol.requestHandler = nil }

        let stream = try await service.streamChat(
            message: "Hi Hermes",
            history: history,
            model: nil
        )

        var combined = ""
        for try await chunk in stream {
            combined += chunk
        }

        #expect(combined == "Hello world")
    }
}
