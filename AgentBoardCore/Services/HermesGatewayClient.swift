import Foundation

public struct HermesGatewayConfiguration: Codable, Hashable, Sendable {
    /// The live Hermes gateway API server port. Kept as a single source of truth so the
    /// client's unconfigured fallback always matches the actually-running gateway.
    public static let defaultBaseURL = "http://127.0.0.1:8641"

    public var baseURL: String
    public var apiKey: String?
    public var preferredModelID: String?

    public init(
        baseURL: String = HermesGatewayConfiguration.defaultBaseURL,
        apiKey: String? = nil,
        preferredModelID: String? = "hermes-agent"
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.preferredModelID = preferredModelID
    }
}

public struct HermesToolProgress: Codable, Hashable, Sendable {
    public let tool: String
    public let emoji: String?
    public let label: String?
    public let toolCallId: String
    public let status: String

    public init(tool: String, emoji: String?, label: String?, toolCallId: String, status: String) {
        self.tool = tool
        self.emoji = emoji
        self.label = label
        self.toolCallId = toolCallId
        self.status = status
    }
}

public enum HermesStreamEvent: Sendable, Hashable {
    case text(String)
    case toolProgress(HermesToolProgress)
}

public struct HermesSkill: Codable, Hashable, Sendable {
    public let name: String
    public let description: String?

    public init(name: String, description: String?) {
        self.name = name
        self.description = description
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
                Could not reach Hermes at \(url): \(
                    message
                ). Check that the profile gateway is running, reachable from \
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
        guard let parsedURL = URL(
            string: normalizedBaseURL.isEmpty ? HermesGatewayConfiguration.defaultBaseURL : normalizedBaseURL
        ),
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

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private struct ModelListResponse: Decodable, Sendable {
        struct Entry: Decodable, Sendable { let id: String }
        let data: [Entry]
    }

    public func fetchModels() async throws -> [String] {
        var request = URLRequest(url: endpointURL("v1/models"))
        request.timeoutInterval = 10
        setAuth(&request)

        let (data, response) = try await data(for: request)
        try validate(response: response, fallbackBody: data)

        let payload: ModelListResponse
        do {
            payload = try decoder.decode(ModelListResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }

        let ids = payload.data.map(\.id)
        return ids.isEmpty ? [configuration.preferredModelID ?? "hermes-agent"] : ids
    }

    private struct SkillListResponse: Decodable, Sendable {
        struct Entry: Decodable, Sendable {
            let name: String
            let description: String?
            let category: String?
        }

        let data: [Entry]
    }

    public func fetchSkills() async throws -> [HermesSkill] {
        var request = URLRequest(url: endpointURL("v1/skills"))
        request.timeoutInterval = 10
        setAuth(&request)

        let (data, response) = try await data(for: request)
        try validate(response: response, fallbackBody: data)

        let payload: SkillListResponse
        do {
            payload = try decoder.decode(SkillListResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }

        return payload.data.map { HermesSkill(name: $0.name, description: $0.description) }
    }

    public func loadConversationHistory(conversationID _: UUID) async throws -> [ConversationMessage] {
        []
    }

    public func streamReply(
        for conversation: [ConversationMessage]
    ) async throws -> AsyncThrowingStream<HermesStreamEvent, Error> {
        let request = try makeChatRequest(conversation: conversation)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await self.session.bytes(for: request)
                    try await self.validateStreamingResponse(response: response, bytes: bytes)
                    try await self.consumeStream(bytes: bytes, continuation: continuation)
                } catch {
                    continuation.finish(throwing: Self.enrichedTransportError(error, requestURL: request.url))
                }
            }
            // Cancel the inner Task when the consumer stops iterating —
            // otherwise the URLSession bytes task (and the underlying socket)
            // leaks until the server closes the connection.
            continuation.onTermination = { _ in task.cancel() }
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

    // MARK: - Typed request/response models

    private struct ChatCompletionRequest: Encodable, Sendable {
        struct Message: Encodable, Sendable {
            struct Attachment: Encodable, Sendable {
                let type: String
                var url: String?
                var title: String?
                var description: String?
            }

            let role: String
            let content: String
            var attachments: [Attachment]?
        }

        let model: String
        let messages: [Message]
        let stream: Bool
    }

    private struct ChatCompletionChunk: Decodable, Sendable {
        struct Choice: Decodable, Sendable {
            struct Delta: Decodable, Sendable {
                let content: String?
            }

            struct Message: Decodable, Sendable {
                let content: String?
            }

            let delta: Delta?
            let message: Message?
            let text: String?
            let finishReason: String?

            var assistantContent: String? {
                delta?.content ?? message?.content ?? text
            }

            enum CodingKeys: String, CodingKey {
                case delta, message, text
                case finishReason = "finish_reason"
            }
        }

        let choices: [Choice]?
    }

    private struct ChatCompletionResponse: Decodable, Sendable {
        struct Choice: Decodable, Sendable {
            struct Message: Decodable, Sendable {
                let content: String?
            }

            let message: Message?
            let text: String?

            var assistantContent: String? {
                message?.content ?? text
            }
        }

        struct MessageContent: Decodable, Sendable {
            let content: String?
        }

        let choices: [Choice]?
        let content: String?
        let message: MessageContent?
    }

    private func makeChatRequest(
        conversation: [ConversationMessage]
    ) throws -> URLRequest {
        var request = URLRequest(url: endpointURL("v1/chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuth(&request)

        let messages: [ChatCompletionRequest.Message] = conversation
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.attachments.isEmpty }
            .map { msg in
                let attachments: [ChatCompletionRequest.Message.Attachment]? = msg.attachments.isEmpty ? nil : msg
                    .attachments.map { attachment in
                        var url: String?
                        if let remoteURL = attachment.remoteURL {
                            url = remoteURL.absoluteString
                        }
                        var title: String?
                        var description: String?
                        if case let .linkPreview(payload) = attachment.payload {
                            url = payload.url.absoluteString
                            title = payload.title
                            description = payload.description
                        }
                        return ChatCompletionRequest.Message.Attachment(
                            type: attachment.type.rawValue,
                            url: url,
                            title: title,
                            description: description
                        )
                    }
                return ChatCompletionRequest.Message(
                    role: msg.role.rawValue,
                    content: msg.content,
                    attachments: attachments
                )
            }

        let payload = ChatCompletionRequest(
            model: configuration.preferredModelID ?? "hermes-agent",
            messages: messages,
            stream: true
        )
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private enum DataLineOutcome {
        case yieldedText
        case finished
        case ignored
    }

    private func processDataLine(
        _ rawData: String,
        pendingEventName: inout String?,
        continuation: AsyncThrowingStream<HermesStreamEvent, Error>.Continuation
    ) -> DataLineOutcome {
        if pendingEventName == "hermes.tool.progress" {
            pendingEventName = nil
            if let jsonData = rawData.data(using: .utf8),
               let progress = try? decoder.decode(HermesToolProgress.self, from: jsonData) {
                continuation.yield(.toolProgress(progress))
            }
            return .ignored
        }

        if rawData == "[DONE]" {
            continuation.finish()
            return .finished
        }

        guard let jsonData = rawData.data(using: .utf8),
              let chunk = try? decoder.decode(ChatCompletionChunk.self, from: jsonData),
              let firstChoice = chunk.choices?.first else {
            return .ignored
        }

        if let finishReason = firstChoice.finishReason, finishReason == "stop" {
            continuation.finish()
            return .finished
        }

        if let content = firstChoice.assistantContent, !content.isEmpty {
            continuation.yield(.text(content))
            return .yieldedText
        }

        return .ignored
    }

    private func consumeStream(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<HermesStreamEvent, Error>.Continuation
    ) async throws {
        var sawServerSentEvent = false
        var fallbackBodyLines: [String] = []
        var didYieldContent = false
        var pendingEventName: String?

        for try await line in bytes.lines {
            guard !Task.isCancelled else {
                throw CancellationError()
            }

            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pendingEventName = nil
                continue
            }

            if line.hasPrefix("event: ") {
                pendingEventName = String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            guard line.hasPrefix("data: ") else {
                fallbackBodyLines.append(line)
                continue
            }

            sawServerSentEvent = true
            let rawData = String(line.dropFirst(6))

            switch processDataLine(rawData, pendingEventName: &pendingEventName, continuation: continuation) {
            case .yieldedText:
                didYieldContent = true
            case .finished:
                return
            case .ignored:
                break
            }
        }

        if !sawServerSentEvent {
            let fallbackBody = fallbackBodyLines.joined(separator: "\n")
            if let content = try extractFallbackAssistantContent(from: fallbackBody), !content.isEmpty {
                didYieldContent = true
                continuation.yield(.text(content))
            }
        }

        if !didYieldContent {
            throw ClientError.emptyAssistantResponse
        }

        continuation.finish()
    }

    private func extractFallbackAssistantContent(from body: String) throws -> String? {
        guard let data = body.data(using: .utf8), !data.isEmpty else { return nil }

        let response: ChatCompletionResponse
        do {
            response = try decoder.decode(ChatCompletionResponse.self, from: data)
        } catch {
            return nil
        }

        if let content = response.choices?.first?.assistantContent {
            return content
        }

        if let content = response.content {
            return content
        }

        if let content = response.message?.content {
            return content
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
            return URL(string: "\(HermesGatewayConfiguration.defaultBaseURL)/\(path)")!
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
