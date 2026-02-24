import Foundation
import Testing
@testable import AgentBoard

@Suite("GatewayClient Message Parsing Tests")
struct GatewayClientMessageParsingTests {

    // MARK: - GatewayClientError descriptions

    @Test("notConnected error has descriptive message")
    func notConnectedErrorDescription() {
        let error = GatewayClientError.notConnected
        #expect(error.errorDescription?.contains("Not connected") == true)
    }

    @Test("connectionFailed error includes reason in message")
    func connectionFailedErrorDescription() {
        let error = GatewayClientError.connectionFailed("TLS handshake failed")
        #expect(error.errorDescription?.contains("TLS handshake failed") == true)
    }

    @Test("requestFailed error includes message in description")
    func requestFailedErrorDescription() {
        let error = GatewayClientError.requestFailed("session not found")
        #expect(error.errorDescription?.contains("session not found") == true)
    }

    @Test("timeout error has descriptive message")
    func timeoutErrorDescription() {
        let error = GatewayClientError.timeout
        #expect(error.errorDescription?.lowercased().contains("timed out") == true)
    }

    @Test("invalidResponse error has descriptive message")
    func invalidResponseErrorDescription() {
        let error = GatewayClientError.invalidResponse
        #expect(error.errorDescription?.lowercased().contains("invalid") == true)
    }

    // MARK: - GatewayEvent computed properties

    @Test("isChatEvent is true for event named 'chat'")
    func isChatEventTrue() {
        let event = GatewayEvent(event: "chat", payload: [:], seq: nil)
        #expect(event.isChatEvent == true)
    }

    @Test("isChatEvent is false for non-chat events")
    func isChatEventFalse() {
        let event = GatewayEvent(event: "connect.challenge", payload: [:], seq: nil)
        #expect(event.isChatEvent == false)
    }

    @Test("chatSessionKey extracts sessionKey from payload")
    func chatSessionKeyExtracted() {
        let event = GatewayEvent(event: "chat", payload: ["sessionKey": "main"], seq: nil)
        #expect(event.chatSessionKey == "main")
    }

    @Test("chatSessionKey returns nil when key is missing from payload")
    func chatSessionKeyNilWhenMissing() {
        let event = GatewayEvent(event: "chat", payload: [:], seq: nil)
        #expect(event.chatSessionKey == nil)
    }

    @Test("chatRunId extracts runId from payload")
    func chatRunIdExtracted() {
        let event = GatewayEvent(event: "chat", payload: ["runId": "run-abc"], seq: nil)
        #expect(event.chatRunId == "run-abc")
    }

    @Test("chatState extracts state from payload")
    func chatStateExtracted() {
        let event = GatewayEvent(event: "chat", payload: ["state": "delta"], seq: nil)
        #expect(event.chatState == "delta")
    }

    @Test("chatState returns nil when state key absent")
    func chatStateNilWhenAbsent() {
        let event = GatewayEvent(event: "chat", payload: [:], seq: nil)
        #expect(event.chatState == nil)
    }

    @Test("chatErrorMessage extracts errorMessage from payload")
    func chatErrorMessageExtracted() {
        let event = GatewayEvent(event: "chat", payload: ["errorMessage": "rate limit exceeded"], seq: nil)
        #expect(event.chatErrorMessage == "rate limit exceeded")
    }

    @Test("chatMessageText extracts text when message content is a string")
    func chatMessageTextFromString() {
        let payload: [String: Any] = ["message": ["content": "Hello, world!"] as [String: Any]]
        let event = GatewayEvent(event: "chat", payload: payload, seq: nil)
        #expect(event.chatMessageText == "Hello, world!")
    }

    @Test("chatMessageText extracts and joins text parts from content array")
    func chatMessageTextFromParts() {
        let parts: [[String: Any]] = [
            ["type": "text", "text": "Part one"],
            ["type": "text", "text": "Part two"],
        ]
        let payload: [String: Any] = ["message": ["content": parts] as [String: Any]]
        let event = GatewayEvent(event: "chat", payload: payload, seq: nil)
        #expect(event.chatMessageText == "Part one\nPart two")
    }

    @Test("chatMessageText returns nil when message key is absent")
    func chatMessageTextNilWhenAbsent() {
        let event = GatewayEvent(event: "chat", payload: [:], seq: nil)
        #expect(event.chatMessageText == nil)
    }

    // MARK: - GatewayClient.extractText

    @Test("extractText returns string content directly")
    func extractTextFromString() {
        let result = GatewayClient.extractText(from: "plain text")
        #expect(result == "plain text")
    }

    @Test("extractText joins text-type parts and skips non-text parts")
    func extractTextFromParts() {
        let parts: [[String: Any]] = [
            ["type": "text", "text": "alpha"],
            ["type": "tool_use", "id": "ignored"],
            ["type": "text", "text": "beta"],
        ]
        let result = GatewayClient.extractText(from: parts)
        #expect(result == "alpha\nbeta")
    }

    @Test("extractText returns nil for nil input")
    func extractTextNilForNil() {
        let result = GatewayClient.extractText(from: nil)
        #expect(result == nil)
    }

    @Test("extractText returns nil for array with no text-type parts")
    func extractTextNilForNonTextParts() {
        let parts: [[String: Any]] = [
            ["type": "tool_use", "id": "tool-1"],
        ]
        let result = GatewayClient.extractText(from: parts)
        #expect(result == nil)
    }

    @Test("extractText returns nil for empty parts array")
    func extractTextNilForEmptyPartsArray() {
        let parts: [[String: Any]] = []
        let result = GatewayClient.extractText(from: parts)
        #expect(result == nil)
    }

    // MARK: - decodeSessionsPayload edge cases

    @Test("decodeSessionsPayload skips sessions with empty key and id")
    func decodeSessionsPayloadSkipsEmptyKey() throws {
        let payload: [String: Any] = [
            "sessions": [
                ["key": "", "id": ""],         // empty key + empty id → skipped
                ["key": "valid", "id": "v1"],  // valid
            ] as [[String: Any]]
        ]
        let sessions = try GatewayClient.decodeSessionsPayload(payload)
        #expect(sessions.count == 1)
        #expect(sessions[0].key == "valid")
    }

    @Test("decodeSessionsPayload falls back to 'id' field when 'key' is absent")
    func decodeSessionsPayloadUsesIdFallback() throws {
        let payload: [String: Any] = [
            "sessions": [
                ["id": "fallback-id"],  // no "key" field
            ] as [[String: Any]]
        ]
        let sessions = try GatewayClient.decodeSessionsPayload(payload)
        #expect(sessions.count == 1)
        #expect(sessions[0].key == "fallback-id")
    }

    @Test("decodeSessionsPayload throws invalidResponse when sessions key is missing")
    func decodeSessionsPayloadThrowsForMissingKey() {
        do {
            _ = try GatewayClient.decodeSessionsPayload(["other": "value"])
            Issue.record("Expected invalidResponse for missing sessions key.")
        } catch GatewayClientError.invalidResponse {
            #expect(true)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("decodeSessionsPayload maps optional fields correctly")
    func decodeSessionsPayloadMapsOptionalFields() throws {
        let lastActive: TimeInterval = 1_700_000_000
        let payload: [String: Any] = [
            "sessions": [
                [
                    "key": "s1",
                    "label": "Main Session",
                    "agentId": "codex",
                    "model": "gpt-5.3",
                    "status": "active",
                    "lastActiveAt": lastActive,
                    "thinkingLevel": "high",
                ] as [String: Any]
            ] as [[String: Any]]
        ]
        let sessions = try GatewayClient.decodeSessionsPayload(payload)
        #expect(sessions.count == 1)
        let s = sessions[0]
        #expect(s.label == "Main Session")
        #expect(s.agentId == "codex")
        #expect(s.model == "gpt-5.3")
        #expect(s.status == "active")
        #expect(s.thinkingLevel == "high")
        #expect(s.lastActiveAt != nil)
    }

    // MARK: - decodeAgentIdentityPayload edge cases

    @Test("decodeAgentIdentityPayload throws when name is whitespace-only")
    func decodeAgentIdentityWhitespaceNameThrows() {
        do {
            _ = try GatewayClient.decodeAgentIdentityPayload(["name": "   "])
            Issue.record("Expected invalidResponse for whitespace-only name.")
        } catch GatewayClientError.invalidResponse {
            #expect(true)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("decodeAgentIdentityPayload throws when name is absent")
    func decodeAgentIdentityMissingNameThrows() {
        do {
            _ = try GatewayClient.decodeAgentIdentityPayload(["agentId": "codex"])
            Issue.record("Expected invalidResponse for missing name.")
        } catch GatewayClientError.invalidResponse {
            #expect(true)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("decodeAgentIdentityPayload succeeds with valid name and optional fields")
    func decodeAgentIdentityValid() throws {
        let identity = try GatewayClient.decodeAgentIdentityPayload([
            "agentId": "codex",
            "name": "AgentBoard Assistant",
            "avatar": "robot",
        ])
        #expect(identity.agentId == "codex")
        #expect(identity.name == "AgentBoard Assistant")
        #expect(identity.avatar == "robot")
    }

    // MARK: - Timestamp parsing (via decodeChatHistoryPayload)

    @Test("decodeChatHistoryPayload treats large timestamp as milliseconds")
    func decodeChatHistoryMillisecondTimestamp() throws {
        // Gateway sends timestamps as ms since epoch (> 1e12)
        let msTimestamp: TimeInterval = 1_700_000_000_000
        let payload: [String: Any] = [
            "messages": [
                ["role": "user", "content": "hi", "timestamp": msTimestamp],
            ] as [[String: Any]]
        ]
        let history = try GatewayClient.decodeChatHistoryPayload(payload)
        let msg = try #require(history.messages.first)
        #expect(msg.timestamp != nil)
        let year = Calendar.current.component(.year, from: msg.timestamp!)
        #expect(year == 2023)
    }

    @Test("decodeChatHistoryPayload treats small timestamp as seconds")
    func decodeChatHistorySecondTimestamp() throws {
        let secondsTimestamp: TimeInterval = 1_700_000_000
        let payload: [String: Any] = [
            "messages": [
                ["role": "assistant", "content": "hello", "timestamp": secondsTimestamp],
            ] as [[String: Any]]
        ]
        let history = try GatewayClient.decodeChatHistoryPayload(payload)
        let msg = try #require(history.messages.first)
        #expect(msg.timestamp != nil)
        let year = Calendar.current.component(.year, from: msg.timestamp!)
        #expect(year == 2023)
    }

    @Test("decodeChatHistoryPayload handles missing timestamp gracefully")
    func decodeChatHistoryMissingTimestamp() throws {
        let payload: [String: Any] = [
            "messages": [
                ["role": "user", "content": "no timestamp here"],
            ] as [[String: Any]]
        ]
        let history = try GatewayClient.decodeChatHistoryPayload(payload)
        let msg = try #require(history.messages.first)
        #expect(msg.timestamp == nil)
    }
}

@Suite("GatewayDiscovery Tests")
struct GatewayDiscoveryTests {
    @Test("DiscoveredGateway url computed property formats correctly")
    func discoveredGatewayURLFormats() {
        let gw = GatewayDiscovery.DiscoveredGateway(
            id: "test-gateway",
            name: "Local OpenClaw",
            host: "192.168.1.42",
            port: 18789
        )
        #expect(gw.url == "http://192.168.1.42:18789")
    }

    @Test("DiscoveredGateway url with port 80 includes port")
    func discoveredGatewayURLIncludesPort() {
        let gw = GatewayDiscovery.DiscoveredGateway(
            id: "test",
            name: "Dev",
            host: "127.0.0.1",
            port: 80
        )
        #expect(gw.url == "http://127.0.0.1:80")
    }
}
