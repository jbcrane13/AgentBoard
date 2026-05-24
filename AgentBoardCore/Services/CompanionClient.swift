import Foundation

public struct CompanionConfiguration: Codable, Hashable, Sendable {
    public var baseURL: String
    public var bearerToken: String?

    public init(
        baseURL: String = "http://127.0.0.1:8742",
        bearerToken: String? = nil
    ) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
    }
}

public actor CompanionClient {
    public enum ClientError: LocalizedError, Equatable {
        case invalidBaseURL
        case invalidResponse
        case httpError(statusCode: Int, body: String)
        case operationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "Invalid companion service URL."
            case .invalidResponse:
                return "Unexpected response from the companion service."
            case let .httpError(statusCode, body):
                let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    return "Companion service returned HTTP \(statusCode)."
                }
                return "Companion service returned HTTP \(statusCode): \(trimmed.prefix(220))"
            case let .operationFailed(message):
                return message
            }
        }
    }

    private let session: URLSession
    private var configuration = CompanionConfiguration()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(session: URLSession = .shared) {
        self.session = session
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    public func configure(baseURL: String, bearerToken: String?) throws {
        let normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalized.isEmpty ? "http://127.0.0.1:8742" : normalized),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw ClientError.invalidBaseURL
        }

        configuration = CompanionConfiguration(
            baseURL: normalized.isEmpty ? "http://127.0.0.1:8742" : normalized,
            bearerToken: bearerToken?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    public func healthCheck() async throws -> Bool {
        let (data, response) = try await session.data(for: makeRequest(path: "health"))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClientError.httpError(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        return true
    }

    public func listSessions() async throws -> [AgentSession] {
        try await fetch(path: "v1/sessions")
    }

    public func listAgents() async throws -> [AgentSummary] {
        try await fetch(path: "v1/agents")
    }

    private struct OkResponse: Decodable, Sendable { let ok: Bool }
    private struct SessionOutputResponse: Decodable, Sendable { let output: String? }

    public func stopSession(id: String) async throws {
        var request = makeRequest(path: "v1/sessions/\(id)/stop")
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let payload: OkResponse
        do {
            payload = try decoder.decode(OkResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
        if !payload.ok {
            throw ClientError.operationFailed("Failed to stop session — the session may no longer be running.")
        }
    }

    public func nudgeSession(id: String) async throws {
        var request = makeRequest(path: "v1/sessions/\(id)/nudge")
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let payload: OkResponse
        do {
            payload = try decoder.decode(OkResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
        if !payload.ok {
            throw ClientError.operationFailed("Failed to nudge session — the session may no longer be running.")
        }
    }

    public func fetchSessionOutput(id: String) async throws -> String? {
        let (data, response) = try await session.data(for: makeRequest(path: "v1/sessions/\(id)/output"))
        try validate(response: response, data: data)
        let payload: SessionOutputResponse
        do {
            payload = try decoder.decode(SessionOutputResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
        guard let output = payload.output else { return nil }
        return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : output
    }

    public func events() async throws -> AsyncThrowingStream<CompanionEvent, Error> {
        var request = makeRequest(path: "v1/events")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await self.session.bytes(for: request)
                    try await self.validateStreamingResponse(response: response, bytes: bytes)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard let data = payload.data(using: .utf8) else { continue }
                        try continuation.yield(self.decoder.decode(CompanionEvent.self, from: data))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Conversations

    public func listConversations() async throws -> [ChatConversation] {
        try await fetch(path: "v1/conversations")
    }

    public func loadMessages(conversationID: UUID) async throws -> [ConversationMessage] {
        try await fetch(path: "v1/conversations/\(conversationID.uuidString)/messages")
    }

    public func syncConversations(
        conversations: [ChatConversation],
        messagesByConversation: [UUID: [ConversationMessage]]
    ) async throws {
        let payload = ConversationSyncPayload(
            conversations: conversations,
            messagesByConversation: messagesByConversation
        )
        var request = makeRequest(path: "v1/conversations/sync")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    public func deleteConversationOnServer(id: UUID) async throws {
        var request = makeRequest(path: "v1/conversations/\(id.uuidString)")
        request.httpMethod = "DELETE"
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    // MARK: - Internal

    private func fetch<Value: Decodable>(path: String) async throws -> Value {
        let (data, response) = try await session.data(for: makeRequest(path: path))
        try validate(response: response, data: data)
        return try decoder.decode(Value.self, from: data)
    }

    private func makeRequest(path: String) -> URLRequest {
        let baseURL = URL(string: configuration.baseURL) ?? URL(string: "http://127.0.0.1:8742")!
        var request = URLRequest(url: baseURL.appending(path: path))
        if let bearerToken = configuration.bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ClientError.httpError(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
    }

    private func validateStreamingResponse(
        response: URLResponse,
        bytes: URLSession.AsyncBytes
    ) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var responseBody = ""
            for try await line in bytes.lines {
                responseBody += line
            }
            throw ClientError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
