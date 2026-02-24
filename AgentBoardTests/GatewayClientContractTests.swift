import Foundation
import Testing
@testable import AgentBoard

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("GatewayClient Contract Tests")
struct GatewayClientContractTests {
    @Test("chat.history payload fixture decodes through real GatewayClient decoder")
    func chatHistoryFixtureDecodes() throws {
        let payload = try fixturePayload(named: "chat_history_payload.json")
        let history = try GatewayClient.decodeChatHistoryPayload(payload)

        #expect(history.thinkingLevel == "high")
        #expect(history.messages.count == 2)
        #expect(history.messages[0].role == "user")
        #expect(history.messages[1].text.contains("AB-48z"))
        #expect(history.messages[0].timestamp != nil)
    }

    @Test("sessions.list payload fixture decodes through real GatewayClient decoder")
    func sessionsFixtureDecodes() throws {
        let payload = try fixturePayload(named: "sessions_list_payload.json")
        let sessions = try GatewayClient.decodeSessionsPayload(payload)

        #expect(sessions.count == 2)
        #expect(sessions[0].key == "main")
        #expect(sessions[0].thinkingLevel == "medium")
        #expect(sessions[1].key == "session-2")
        #expect(sessions[1].lastActiveAt != nil)
    }

    @Test("agent identity payload fixture decodes through real GatewayClient decoder")
    func agentIdentityFixtureDecodes() throws {
        let payload = try fixturePayload(named: "agent_identity_payload.json")
        let identity = try GatewayClient.decodeAgentIdentityPayload(payload)

        #expect(identity.agentId == "codex")
        #expect(identity.name == "AgentBoard Assistant")
        #expect(identity.avatar == "robot")
    }

    @Test("decoder rejects malformed payloads to surface API contract drift")
    func malformedPayloadThrowsInvalidResponse() {
        do {
            _ = try GatewayClient.decodeChatHistoryPayload(["thinkingLevel": "low"])
            Issue.record("Expected invalidResponse for missing messages payload.")
        } catch GatewayClientError.invalidResponse {
            #expect(true)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("MockURLProtocol intercepts requests with fixture response")
    func mockURLProtocolIntercepts() async throws {
        let fixtureData = try fixtureData(named: "chat_history_payload.json")
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://agentboard.test/contracts/chat-history")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, fixtureData)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let request = URLRequest(url: URL(string: "https://agentboard.test/contracts/chat-history")!)
        let (data, response) = try await session.data(for: request)

        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        let payload = try payloadObject(from: data)
        let history = try GatewayClient.decodeChatHistoryPayload(payload)
        #expect(history.messages.count == 2)
    }

    private func fixturePayload(named filename: String) throws -> [String: Any] {
        let data = try fixtureData(named: filename)
        return try payloadObject(from: data)
    }

    private func payloadObject(from data: Data) throws -> [String: Any] {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayClientError.invalidResponse
        }
        return payload
    }

    private func fixtureData(named filename: String) throws -> Data {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("TestFixtures", isDirectory: true)
            .appendingPathComponent("GatewayClient", isDirectory: true)
        return try Data(contentsOf: directory.appendingPathComponent(filename))
    }
}
