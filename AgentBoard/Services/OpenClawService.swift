import Foundation

struct OpenClawRemoteSession: Identifiable, Sendable {
    let id: String
    let name: String
}

enum OpenClawServiceError: LocalizedError {
    case invalidGatewayURL
    case missingResponseData
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidGatewayURL:
            return "Invalid OpenClaw gateway URL."
        case .missingResponseData:
            return "OpenClaw returned no response data."
        case .requestFailed(let message):
            return message
        }
    }
}

actor OpenClawService {
    private var gatewayURL: URL = URL(string: "http://127.0.0.1:18789")!
    private var webSocketURL: URL = URL(string: "ws://127.0.0.1:18789/ws")!
    private var authToken: String?

    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func configure(gatewayURLString: String?, token: String?) throws {
        let normalizedGateway = (gatewayURLString?.isEmpty == false)
            ? gatewayURLString!
            : "http://127.0.0.1:18789"

        guard let resolvedGateway = URL(string: normalizedGateway) else {
            throw OpenClawServiceError.invalidGatewayURL
        }

        gatewayURL = resolvedGateway
        authToken = token?.isEmpty == true ? nil : token

        var webSocketComponents = URLComponents(url: gatewayURL, resolvingAgainstBaseURL: false)
        switch webSocketComponents?.scheme {
        case "https":
            webSocketComponents?.scheme = "wss"
        default:
            webSocketComponents?.scheme = "ws"
        }
        webSocketComponents?.path = "/ws"
        webSocketURL = webSocketComponents?.url ?? URL(string: "ws://127.0.0.1:18789/ws")!
    }

    func connectWebSocket() async throws {
        disconnectWebSocket()

        var request = URLRequest(url: webSocketURL)
        if let authToken {
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let task = session.webSocketTask(with: request)
        task.resume()
        try await sendPing(task)
        webSocketTask = task
    }

    func pingWebSocket() async throws {
        guard let webSocketTask else {
            throw OpenClawServiceError.requestFailed("WebSocket not connected.")
        }
        try await sendPing(webSocketTask)
    }

    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    func fetchSessions() async throws -> [OpenClawRemoteSession] {
        let url = gatewayURL.appending(path: "api/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        if let authToken {
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return parseSessions(from: data)
    }

    func streamChat(
        messages: [ChatMessage],
        beadContext: String?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let payloadMessages = makePayloadMessages(from: messages, beadContext: beadContext)

        do {
            return try await streamViaSSE(payloadMessages: payloadMessages, onDelta: onDelta)
        } catch {
            return try await streamViaFallback(payloadMessages: payloadMessages, onDelta: onDelta)
        }
    }

    private func streamViaSSE(
        payloadMessages: [[String: Any]],
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let url = gatewayURL.appending(path: "v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "openclaw",
            "stream": true,
            "messages": payloadMessages,
        ])

        let (bytes, response) = try await session.bytes(for: request)
        try validateHTTPResponse(response, data: nil)

        var output = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !payload.isEmpty else { continue }
            if payload == "[DONE]" { break }

            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let delta = parseDeltaContent(from: json)
            guard !delta.isEmpty else { continue }

            output += delta
            onDelta(delta)
        }

        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw OpenClawServiceError.missingResponseData
        }

        return output
    }

    private func streamViaFallback(
        payloadMessages: [[String: Any]],
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let url = gatewayURL.appending(path: "v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "openclaw",
            "stream": false,
            "messages": payloadMessages,
        ])

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = parseNonStreamingContent(from: json),
              !content.isEmpty else {
            throw OpenClawServiceError.missingResponseData
        }

        var streamed = ""
        let pieces = content.split(separator: " ", omittingEmptySubsequences: false)
        for (index, piece) in pieces.enumerated() {
            let delta = index == pieces.startIndex ? String(piece) : " \(piece)"
            streamed += delta
            onDelta(delta)
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        return streamed
    }

    private func parseSessions(from data: Data) -> [OpenClawRemoteSession] {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        let rows: [[String: Any]]
        if let array = root as? [[String: Any]] {
            rows = array
        } else if let dictionary = root as? [String: Any],
                  let array = dictionary["sessions"] as? [[String: Any]] {
            rows = array
        } else {
            rows = []
        }

        return rows.enumerated().compactMap { index, row in
            let fallbackID = "session-\(index)"
            let id = (row["id"] as? String)
                ?? (row["session_id"] as? String)
                ?? fallbackID
            let name = (row["name"] as? String)
                ?? (row["title"] as? String)
                ?? id
            return OpenClawRemoteSession(id: id, name: name)
        }
    }

    private func makePayloadMessages(from messages: [ChatMessage], beadContext: String?) -> [[String: Any]] {
        var payload: [[String: Any]] = []
        if let beadContext {
            payload.append([
                "role": "system",
                "content": "Active bead context: \(beadContext). Reference this bead ID when discussing related tasks.",
            ])
        }

        let recentMessages = messages.suffix(24).filter { !$0.content.isEmpty }
        for message in recentMessages {
            payload.append([
                "role": message.role.rawValue,
                "content": message.content,
            ])
        }
        return payload
    }

    private func parseDeltaContent(from json: [String: Any]) -> String {
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first else {
            return ""
        }

        if let delta = first["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            return content
        }

        if let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        if let text = first["text"] as? String {
            return text
        }

        return ""
    }

    private func parseNonStreamingContent(from json: [String: Any]) -> String? {
        if let choices = json["choices"] as? [[String: Any]],
           let first = choices.first {
            if let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
            if let text = first["text"] as? String {
                return text
            }
        }

        if let outputText = json["output_text"] as? String {
            return outputText
        }
        return nil
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
            throw OpenClawServiceError.requestFailed(detail)
        }
    }

    private func sendPing(_ task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
