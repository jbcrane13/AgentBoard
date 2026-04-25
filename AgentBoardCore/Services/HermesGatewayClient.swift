import Foundation

public struct HermesGatewayConfiguration: Codable, Hashable, Sendable {
    public var baseURL: String
    public var apiKey: String?
    public var preferredModelID: String?

    public init(
        baseURL: String = "http://127.0.0.1:8642",
        apiKey: String? = nil,
        preferredModelID: String? = "hermes-agent"
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.preferredModelID = preferredModelID
    }
}

public actor HermesGatewayClient {
    public enum ClientError: LocalizedError, Equatable {
        case invalidGatewayURL
        case invalidResponse
        case emptyAssistantResponse
        case transportError(url: String, message: String)
        case httpError(statusCode: Int, body: String)

        public var errorDescription: String? {
            switch self {
            case .invalidGatewayURL:
                return "Invalid Hermes gateway URL."
            case .invalidResponse:
                return "Invalid response from Hermes gateway."
            case .emptyAssistantResponse:
                return "Hermes returned a successful response, but no assistant text was found."
            case let .transportError(url, message):
                return """
                Could not reach Hermes at \(url): \(message). Check that the profile gateway is running, reachable from \
                this device, and using the right HTTP URL/port.
                """
            case let .httpError(statusCode, body):
                let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    return "Hermes gateway returned HTTP \(statusCode)."
                }
                return "Hermes gateway returned HTTP \(statusCode): \(trimmed.prefix(220))"
            }
        }
    }

    private let session: URLSession
    private var configuration = HermesGatewayConfiguration()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func configure(
        baseURL: String,
        apiKey: String?,
        preferredModelID: String?
    ) throws {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedURL = URL(string: normalizedBaseURL.isEmpty ? "http://127.0.0.1:8642" : normalizedBaseURL),
              let scheme = parsedURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              parsedURL.host != nil else {
            throw ClientError.invalidGatewayURL
        }

        configuration = HermesGatewayConfiguration(
            baseURL: Self.normalizeGatewayURL(parsedURL).absoluteString,
            apiKey: apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            preferredModelID: preferredModelID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    public func currentConfiguration() -> HermesGatewayConfiguration {
        configuration
    }

    public func healthCheck() async throws -> Bool {
        var request = URLRequest(url: endpointURL("health"))
        request.timeoutInterval = 5
        setAuth(&request)

        let (_, response) = try await data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    public func fetchModels() async throws -> [String] {
        var request = URLRequest(url: endpointURL("v1/models"))
        request.timeoutInterval = 10
        setAuth(&request)

        let (data, response) = try await data(for: request)
        try validate(response: response, fallbackBody: data)

        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = payload["data"] as? [[String: Any]] else {
            throw ClientError.invalidResponse
        }

        let ids = models.compactMap { $0["id"] as? String }
        return ids.isEmpty ? [configuration.preferredModelID ?? "hermes-agent"] : ids
    }

    public func loadConversationHistory(conversationID _: UUID) async throws -> [ConversationMessage] {
        []
    }

    public func streamReply(
        for conversation: [ConversationMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        let request = try makeChatRequest(conversation: conversation)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await self.session.bytes(for: request)
                    try await self.validateStreamingResponse(response: response, bytes: bytes)
                    try await self.consumeStream(bytes: bytes, continuation: continuation)
                } catch {
                    continuation.finish(throwing: Self.enrichedTransportError(error, requestURL: request.url))
                }
            }
        }
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw Self.enrichedTransportError(error, requestURL: request.url)
        }
    }

    private static func enrichedTransportError(_ error: Error, requestURL: URL?) -> Error {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return error }

        return ClientError.transportError(
            url: requestURL?.absoluteString ?? "the configured Hermes endpoint",
            message: error.localizedDescription
        )
    }

    private func makeChatRequest(
        conversation: [ConversationMessage]
    ) throws -> URLRequest {
        var request = URLRequest(url: endpointURL("v1/chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuth(&request)

        let messages = conversation
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.content] }
        let payload: [String: Any] = [
            "model": configuration.preferredModelID ?? "hermes-agent",
            "messages": messages,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    private func consumeStream(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        var sawServerSentEvent = false
        var fallbackBodyLines: [String] = []
        var didYieldContent = false

        for try await line in bytes.lines {
            guard !Task.isCancelled else {
                throw CancellationError()
            }

            guard line.hasPrefix("data: ") else {
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fallbackBodyLines.append(line)
                }
                continue
            }

            sawServerSentEvent = true
            let rawData = String(line.dropFirst(6))

            if rawData == "[DONE]" {
                continuation.finish()
                return
            }

            guard let jsonData = rawData.data(using: .utf8),
                  let payload = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = payload["choices"] as? [[String: Any]],
                  let firstChoice = choices.first else {
                continue
            }

            if let finishReason = firstChoice["finish_reason"] as? String,
               finishReason == "stop" {
                continuation.finish()
                return
            }

            if let content = Self.extractAssistantContent(from: firstChoice), !content.isEmpty {
                didYieldContent = true
                continuation.yield(content)
            }
        }

        if !sawServerSentEvent {
            let fallbackBody = fallbackBodyLines.joined(separator: "\n")
            if let content = try Self.extractFallbackAssistantContent(from: fallbackBody), !content.isEmpty {
                didYieldContent = true
                continuation.yield(content)
            }
        }

        if !didYieldContent {
            throw ClientError.emptyAssistantResponse
        }

        continuation.finish()
    }

    private static func extractFallbackAssistantContent(from body: String) throws -> String? {
        guard let data = body.data(using: .utf8), !data.isEmpty else { return nil }
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if let choices = payload["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let content = extractAssistantContent(from: firstChoice) {
            return content
        }

        if let content = payload["content"] as? String {
            return content
        }

        if let message = payload["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        return nil
    }

    private static func extractAssistantContent(from choice: [String: Any]) -> String? {
        if let delta = choice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            return content
        }

        if let message = choice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        if let text = choice["text"] as? String {
            return text
        }

        return nil
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

    private func validate(response: URLResponse, fallbackBody: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let body = String(data: fallbackBody, encoding: .utf8) ?? ""
            throw ClientError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }

    private func setAuth(_ request: inout URLRequest) {
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    private func endpointURL(_ path: String) -> URL {
        guard let baseURL = URL(string: configuration.baseURL) else {
            return URL(string: "http://127.0.0.1:8642/\(path)")!
        }
        return baseURL.appending(path: path)
    }

    private static func normalizeGatewayURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath == "v1" {
            components.path = ""
        }

        return components.url ?? url
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
