import Foundation

protocol HermesChatServicing: Actor {
    func configure(gatewayURLString: String?, apiKey: String?) throws
    func healthCheck() async throws -> Bool
    func fetchModels() async throws -> [String]
    func streamChat(
        message: String,
        history: [ChatMessage],
        model: String?
    ) async throws -> AsyncThrowingStream<String, Error>
}

enum HermesChatServiceError: LocalizedError, Equatable {
    case invalidGatewayURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidGatewayURL:
            return "Invalid Hermes gateway URL."
        case .invalidResponse:
            return "Invalid response from Hermes gateway."
        case let .httpError(statusCode, body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Hermes gateway returned HTTP \(statusCode)."
            }
            return "Hermes gateway returned HTTP \(statusCode): \(trimmed.prefix(220))"
        }
    }
}

actor HermesChatService {
    private let session: URLSession
    private var gatewayURL: URL = HermesChatService.defaultGatewayURL
    private var apiKey: String?

    private static let defaultGatewayURL = URL(string: "http://127.0.0.1:8642")!
    private static let defaultModel = "hermes-agent"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func configure(gatewayURLString: String?, apiKey: String?) throws {
        let rawURL = gatewayURLString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = rawURL?.isEmpty == false ? rawURL! : Self.defaultGatewayURL.absoluteString

        guard let parsedURL = URL(string: normalized),
              let scheme = parsedURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              parsedURL.host != nil else {
            throw HermesChatServiceError.invalidGatewayURL
        }

        gatewayURL = Self.normalizeGatewayURL(parsedURL)
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.apiKey = trimmedKey.nilIfEmpty
    }

    func healthCheck() async throws -> Bool {
        var request = URLRequest(url: endpointURL("health"))
        request.timeoutInterval = 5
        setAuth(&request)

        let (_, response) = try await session.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    func fetchModels() async throws -> [String] {
        var request = URLRequest(url: endpointURL("v1/models"))
        request.timeoutInterval = 10
        setAuth(&request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, fallbackBody: data)

        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = payload["data"] as? [[String: Any]] else {
            throw HermesChatServiceError.invalidResponse
        }

        return models.compactMap { $0["id"] as? String }
    }

    func streamChat(
        message: String,
        history: [ChatMessage],
        model: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        let request = try makeChatRequest(message: message, history: history, model: model)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    try await self.validateStreamingResponse(response: response, bytes: bytes)
                    try await self.consumeStream(bytes: bytes, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func makeChatRequest(
        message: String,
        history: [ChatMessage],
        model: String?
    ) throws -> URLRequest {
        var request = URLRequest(url: endpointURL("v1/chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuth(&request)

        let messages = history
            .filter { $0.role == .user || $0.role == .assistant }
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.content] }

        let selectedModel = (model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").nilIfEmpty
            ?? Self.defaultModel
        let payload: [String: Any] = [
            "model": selectedModel,
            "messages": messages + [["role": MessageRole.user.rawValue, "content": message]],
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        return request
    }

    private func consumeStream(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        for try await line in bytes.lines {
            guard !Task.isCancelled else {
                throw CancellationError()
            }

            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))

            if data == "[DONE]" {
                continuation.finish()
                return
            }

            guard let jsonData = data.data(using: .utf8),
                  let payload = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = payload["choices"] as? [[String: Any]],
                  let choice = choices.first else {
                continue
            }

            if let finishReason = choice["finish_reason"] as? String,
               finishReason == "stop" {
                continuation.finish()
                return
            }

            if let delta = choice["delta"] as? [String: Any],
               let content = delta["content"] as? String,
               !content.isEmpty {
                continuation.yield(content)
            }
        }

        continuation.finish()
    }

    private func validateStreamingResponse(
        response: URLResponse,
        bytes: URLSession.AsyncBytes
    ) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesChatServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var responseBody = ""
            for try await line in bytes.lines {
                responseBody += line
            }
            throw HermesChatServiceError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
        }
    }

    private func validate(response: URLResponse, fallbackBody: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesChatServiceError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let body = String(data: fallbackBody, encoding: .utf8) ?? ""
            throw HermesChatServiceError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }

    private func setAuth(_ request: inout URLRequest) {
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    private func endpointURL(_ path: String) -> URL {
        gatewayURL.appending(path: path)
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

extension HermesChatService: HermesChatServicing {}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
