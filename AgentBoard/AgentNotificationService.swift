import Foundation

// MARK: - Models

/// Represents a notification agent that can be assigned tasks
public struct NotificationAgent: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let telegramUserId: String?

    public init(id: String, name: String, telegramUserId: String? = nil) {
        self.id = id
        self.name = name
        self.telegramUserId = telegramUserId
    }
}

/// Represents a notification agent task that can be assigned to an agent
public struct NotificationAgentTask: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let priority: Priority

    public enum Priority: String, Codable, Sendable {
        case low
        case medium
        case high
        case critical

        var emoji: String {
            switch self {
            case .low: return "🔵"
            case .medium: return "🟡"
            case .high: return "🟠"
            case .critical: return "🔴"
            }
        }
    }

    public init(id: String, title: String, description: String, priority: Priority = .medium) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
    }
}

/// Result of a notification operation
public enum NotificationResult: Sendable {
    case success(messageId: Int?)
    case failure(Error)
}

// MARK: - Errors

/// Errors that can occur during Telegram notification operations
public enum TelegramNotificationError: Error, LocalizedError {
    case invalidBotToken
    case invalidChatId
    case networkError(underlying: Error)
    case apiError(statusCode: Int, description: String)
    case encodingError
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .invalidBotToken:
            return "Invalid or missing Telegram bot token"
        case .invalidChatId:
            return "Invalid or missing Telegram chat ID"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .apiError(let statusCode, let description):
            return "Telegram API error (\(statusCode)): \(description)"
        case .encodingError:
            return "Failed to encode request payload"
        case .decodingError:
            return "Failed to decode Telegram API response"
        }
    }
}

// MARK: - Configuration

/// Configuration for the Telegram notification service
public struct TelegramConfiguration: Sendable {
    public let botToken: String
    public let defaultChatId: String
    public let parseMode: String

    public init(botToken: String, defaultChatId: String, parseMode: String = "HTML") {
        self.botToken = botToken
        self.defaultChatId = defaultChatId
        self.parseMode = parseMode
    }
}

// MARK: - AgentNotificationService

/// Service for sending Telegram notifications related to notification agent task assignments
public final class AgentNotificationService: Sendable {

    private let configuration: TelegramConfiguration
    private let session: URLSession
    private let baseURL: URL

    /// Initialize the notification service
    /// - Parameters:
    ///   - configuration: Telegram bot configuration
    ///   - session: URLSession to use (defaults to shared)
    public init(configuration: TelegramConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.baseURL = URL(string: "https://api.telegram.org/bot\(configuration.botToken)/")!
    }

    // MARK: - Public Methods

    /// Notify that a task has been assigned to a notification agent
    /// - Parameters:
    ///   - agent: The notification agent being assigned
    ///   - task: The notification agent task being assigned
    ///   - chatId: Optional override chat ID (uses default if nil)
    /// - Returns: NotificationResult with the message ID on success
    public func notifyAssignment(
        agent: NotificationAgent,
        task: NotificationAgentTask,
        chatId: String? = nil
    ) async -> NotificationResult {
        let message = formatAssignmentMessage(agent: agent, task: task)
        return await sendMessage(text: message, chatId: chatId ?? configuration.defaultChatId)
    }

    /// Notify that a notification agent has completed a task
    /// - Parameters:
    ///   - agent: The notification agent who completed the task
    ///   - task: The completed notification agent task
    ///   - notes: Optional completion notes
    ///   - chatId: Optional override chat ID (uses default if nil)
    /// - Returns: NotificationResult with the message ID on success
    public func notifyCompletion(
        agent: NotificationAgent,
        task: NotificationAgentTask,
        notes: String? = nil,
        chatId: String? = nil
    ) async -> NotificationResult {
        let message = formatCompletionMessage(agent: agent, task: task, notes: notes)
        return await sendMessage(text: message, chatId: chatId ?? configuration.defaultChatId)
    }

    /// Acknowledge a task assignment (notification agent confirms receipt)
    /// - Parameters:
    ///   - agent: The notification agent acknowledging
    ///   - task: The notification agent task being acknowledged
    ///   - estimatedCompletion: Optional estimated completion time string
    ///   - chatId: Optional override chat ID (uses default if nil)
    /// - Returns: NotificationResult with the message ID on success
    public func acknowledgeAssignment(
        agent: NotificationAgent,
        task: NotificationAgentTask,
        estimatedCompletion: String? = nil,
        chatId: String? = nil
    ) async -> NotificationResult {
        let message = formatAcknowledgmentMessage(
            agent: agent,
            task: task,
            estimatedCompletion: estimatedCompletion
        )
        return await sendMessage(text: message, chatId: chatId ?? configuration.defaultChatId)
    }

    /// Send a custom notification message
    /// - Parameters:
    ///   - text: The message text (HTML formatted)
    ///   - chatId: Target chat ID
    /// - Returns: NotificationResult with the message ID on success
    public func sendCustomNotification(
        text: String,
        chatId: String? = nil
    ) async -> NotificationResult {
        return await sendMessage(text: text, chatId: chatId ?? configuration.defaultChatId)
    }

    // MARK: - Private Methods

    private func sendMessage(text: String, chatId: String) async -> NotificationResult {
        let endpoint = baseURL.appendingPathComponent("sendMessage")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": configuration.parseMode
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            return .failure(TelegramNotificationError.encodingError)
        }
        request.httpBody = jsonData

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(TelegramNotificationError.apiError(
                    statusCode: -1,
                    description: "Invalid response type"
                ))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let description = extractErrorDescription(from: data)
                return .failure(TelegramNotificationError.apiError(
                    statusCode: httpResponse.statusCode,
                    description: description
                ))
            }

            let messageId = extractMessageId(from: data)
            return .success(messageId: messageId)

        } catch {
            return .failure(TelegramNotificationError.networkError(underlying: error))
        }
    }

    private func extractMessageId(from data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let messageId = result["message_id"] as? Int else {
            return nil
        }
        return messageId
    }

    private func extractErrorDescription(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let description = json["description"] as? String else {
            return "Unknown error"
        }
        return description
    }

    // MARK: - Message Formatting

    private func formatAssignmentMessage(agent: NotificationAgent, task: NotificationAgentTask) -> String {
        var message = """
        <b>📋 New Task Assignment</b>

        <b>Agent:</b> \(agent.name)
        <b>Task:</b> \(task.title)
        <b>Priority:</b> \(task.priority.emoji) \(task.priority.rawValue.capitalized)
        <b>Task ID:</b> \(task.id)
        """
        if !task.description.isEmpty {
            message += "\n\n<b>Description:</b>\n\(task.description)"
        }
        message += "\n\n<i>Task assigned at \(formattedTimestamp())</i>"
        return message
    }

    private func formatCompletionMessage(agent: NotificationAgent, task: NotificationAgentTask, notes: String?) -> String {
        var message = """
        <b>✅ Task Completed</b>

        <b>Agent:</b> \(agent.name)
        <b>Task:</b> \(task.title)
        <b>Task ID:</b> \(task.id)
        """
        if let notes = notes, !notes.isEmpty {
            message += "\n\n<b>Notes:</b>\n\(notes)"
        }
        message += "\n\n<i>Completed at \(formattedTimestamp())</i>"
        return message
    }

    private func formatAcknowledgmentMessage(
        agent: NotificationAgent,
        task: NotificationAgentTask,
        estimatedCompletion: String?
    ) -> String {
        var message = """
        <b>👍 Assignment Acknowledged</b>

        <b>Agent:</b> \(agent.name)
        <b>Task:</b> \(task.title)
        <b>Task ID:</b> \(task.id)
        """
        if let eta = estimatedCompletion, !eta.isEmpty {
            message += "\n\n<b>Estimated Completion:</b> \(eta)"
        }
        message += "\n\n<i>Acknowledged at \(formattedTimestamp())</i>"
        return message
    }

    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}
