import AgentBoardCore
import Foundation
import Testing

/// Coverage for `CompanionClient.events()` — the SSE stream that powers
/// live updates from the companion service. The stream parses one
/// `CompanionEvent` per `data:` line and skips other SSE framing lines.
@Suite(.serialized)
struct CompanionClientEventsTests {
    @Test
    func eventsDecodesDataLinesAndSkipsOtherSSEFraming() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let sentAt = Date(timeIntervalSince1970: 1_700_000_000)
        let body = """
        : heartbeat
        retry: 5000

        event: companion
        data: \(eventJSON(id: firstID, kind: .sessionsChanged, sentAt: sentAt))

        data: \(eventJSON(id: secondID, kind: .conversationsChanged, sentAt: sentAt))


        """

        let client = CompanionClient(session: makeMockSession { request in
            #expect(request.url?.path == "/v1/events")
            #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            return (response, Data(body.utf8))
        })

        try await client.configure(baseURL: "http://companion.test:8742", bearerToken: nil)

        var received: [CompanionEvent] = []
        for try await event in try await client.events() {
            received.append(event)
            if received.count == 2 { break }
        }

        #expect(received.map(\.id) == [firstID, secondID])
        #expect(received.map(\.kind) == [.sessionsChanged, .conversationsChanged])
    }

    @Test
    func eventsSurfacesHTTPErrorsForNon200Status() async throws {
        let client = CompanionClient(session: makeMockSession { request in
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("companion offline".utf8))
        })

        try await client.configure(baseURL: "http://companion.test:8742", bearerToken: nil)

        await #expect(throws: CompanionClient.ClientError.self) {
            for try await _ in try await client.events() {
                Issue.record("expected stream to throw before yielding")
            }
        }
    }

    @Test
    func eventsTerminatesStreamOnMalformedDataLine() async throws {
        let validID = UUID()
        let body = """
        data: not-json

        data: \(eventJSON(id: validID, kind: .agentsChanged, sentAt: Date(timeIntervalSince1970: 1_700_000_500)))

        """

        let client = CompanionClient(session: makeMockSession { request in
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            return (response, Data(body.utf8))
        })

        try await client.configure(baseURL: "http://companion.test:8742", bearerToken: nil)

        var streamError: Error?
        var received: [CompanionEvent] = []
        do {
            for try await event in try await client.events() {
                received.append(event)
            }
        } catch {
            streamError = error
        }

        // Malformed JSON on a `data:` line currently surfaces as a decoding
        // error that tears the stream down — the subsequent valid event never
        // arrives. Pinning that contract prevents silent corruption.
        #expect(streamError != nil)
        #expect(received.isEmpty)
    }

    // MARK: - Helpers

    private func eventJSON(id: UUID, kind: CompanionEventKind, sentAt: Date) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let event = CompanionEvent(id: id, kind: kind, sentAt: sentAt)
        guard let data = try? encoder.encode(event),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
