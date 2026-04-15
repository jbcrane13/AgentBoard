import Foundation

// MARK: - Models

/// Status of a review session
public enum ReviewStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case approved
    case rejected
    case revisionRequested

    public var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .inProgress: return "🔍"
        case .approved: return "✅"
        case .rejected: return "❌"
        case .revisionRequested: return "🔄"
        }
    }
}

/// Represents a finding or comment from the reviewer
public struct ReviewFinding: Codable, Identifiable, Sendable {
    public let id: String
    public let lineNumber: Int?
    public let comment: String
    public let severity: Severity
    public let createdAt: Date

    public enum Severity: String, Codable, Sendable {
        case info
        case suggestion
        case warning
        case critical
    }

    public init(
        id: String = UUID().uuidString,
        lineNumber: Int? = nil,
        comment: String,
        severity: Severity = .suggestion,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.lineNumber = lineNumber
        self.comment = comment
        self.severity = severity
        self.createdAt = createdAt
    }
}

/// Represents a cross-review session between two agents
public struct ReviewSession: Codable, Identifiable, Sendable {
    public let id: String
    public let reviewerAgent: String
    public let authorAgent: String
    public let codeSnippet: String
    public let filePath: String?
    public var status: ReviewStatus
    public var findings: [ReviewFinding]
    public var summary: String?
    public let createdAt: Date
    public var completedAt: Date?
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        reviewerAgent: String,
        authorAgent: String,
        codeSnippet: String,
        filePath: String? = nil,
        status: ReviewStatus = .pending,
        findings: [ReviewFinding] = [],
        summary: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.reviewerAgent = reviewerAgent
        self.authorAgent = authorAgent
        self.codeSnippet = codeSnippet
        self.filePath = filePath
        self.status = status
        self.findings = findings
        self.summary = summary
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.updatedAt = createdAt
    }

    /// Whether this review session is still active
    public var isActive: Bool {
        status == .pending || status == .inProgress
    }

    /// Duration of the review (if completed)
    public var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(createdAt)
    }
}

// MARK: - Errors

/// Errors that can occur during cross-review operations
public enum CrossReviewError: Error, LocalizedError {
    case sessionNotFound(sessionId: String)
    case sessionAlreadyCompleted(sessionId: String)
    case invalidReviewerAgent
    case invalidAuthorAgent
    case noFindings

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound(let sessionId):
            return "Review session not found: \(sessionId)"
        case .sessionAlreadyCompleted(let sessionId):
            return "Review session already completed: \(sessionId)"
        case .invalidReviewerAgent:
            return "Invalid reviewer agent specified"
        case .invalidAuthorAgent:
            return "Invalid author agent specified"
        case .noFindings:
            return "Cannot complete review without any findings"
        }
    }
}

// MARK: - Result Types

/// Result of a cross-review operation
public enum CrossReviewResult: Sendable {
    case success(session: ReviewSession)
    case failure(CrossReviewError)
}

/// Result of listing review sessions
public enum ReviewListResult: Sendable {
    case success(sessions: [ReviewSession])
    case failure(CrossReviewError)
}

// MARK: - CrossReviewService

/// Service for managing cross-agent code reviews
/// Enables agents like Codex to review Claude's work and vice versa
public final class CrossReviewService: @unchecked Sendable {

    private var sessions: [String: ReviewSession] = [:]
    private let lock = NSLock()

    /// Initialize the cross-review service
    public init() {}

    // MARK: - Public Methods

    /// Start a new cross-review session
    /// - Parameters:
    ///   - reviewerAgent: The agent performing the review (e.g., "Codex")
    ///   - authorAgent: The agent whose code is being reviewed (e.g., "Claude")
    ///   - codeSnippet: The code to be reviewed
    ///   - filePath: Optional file path for context
    /// - Returns: CrossReviewResult with the created session on success
    public func startReview(
        reviewerAgent: String,
        authorAgent: String,
        codeSnippet: String,
        filePath: String? = nil
    ) -> CrossReviewResult {
        guard !reviewerAgent.isEmpty else {
            return .failure(.invalidReviewerAgent)
        }
        guard !authorAgent.isEmpty else {
            return .failure(.invalidAuthorAgent)
        }
        guard reviewerAgent != authorAgent else {
            return .failure(.invalidReviewerAgent)
        }

        let session = ReviewSession(
            reviewerAgent: reviewerAgent,
            authorAgent: authorAgent,
            codeSnippet: codeSnippet,
            filePath: filePath,
            status: .inProgress
        )

        lock.lock()
        sessions[session.id] = session
        lock.unlock()

        return .success(session: session)
    }

    /// Add a finding to an active review session
    /// - Parameters:
    ///   - sessionId: The review session ID
    ///   - finding: The finding to add
    /// - Returns: CrossReviewResult with the updated session
    public func addFinding(
        sessionId: String,
        finding: ReviewFinding
    ) -> CrossReviewResult {
        lock.lock()
        guard var session = sessions[sessionId] else {
            lock.unlock()
            return .failure(.sessionNotFound(sessionId: sessionId))
        }

        guard session.isActive else {
            lock.unlock()
            return .failure(.sessionAlreadyCompleted(sessionId: sessionId))
        }

        session.findings.append(finding)
        session.updatedAt = Date()
        sessions[sessionId] = session
        lock.unlock()

        return .success(session: session)
    }

    /// Complete a review session with a final verdict
    /// - Parameters:
    ///   - sessionId: The review session ID
    ///   - status: The final status (approved, rejected, or revisionRequested)
    ///   - summary: Optional summary of the review
    /// - Returns: CrossReviewResult with the completed session
    public func completeReview(
        sessionId: String,
        status: ReviewStatus,
        summary: String? = nil
    ) -> CrossReviewResult {
        lock.lock()
        guard var session = sessions[sessionId] else {
            lock.unlock()
            return .failure(.sessionNotFound(sessionId: sessionId))
        }

        guard session.isActive else {
            lock.unlock()
            return .failure(.sessionAlreadyCompleted(sessionId: sessionId))
        }

        session.status = status
        session.summary = summary
        session.completedAt = Date()
        session.updatedAt = Date()
        sessions[sessionId] = session
        lock.unlock()

        return .success(session: session)
    }

    /// Get a review session by ID
    /// - Parameter sessionId: The review session ID
    /// - Returns: CrossReviewResult with the session if found
    public func getSession(sessionId: String) -> CrossReviewResult {
        lock.lock()
        guard let session = sessions[sessionId] else {
            lock.unlock()
            return .failure(.sessionNotFound(sessionId: sessionId))
        }
        lock.unlock()

        return .success(session: session)
    }

    /// List all review sessions, optionally filtered
    /// - Parameters:
    ///   - reviewerAgent: Filter by reviewer agent (optional)
    ///   - authorAgent: Filter by author agent (optional)
    ///   - status: Filter by status (optional)
    /// - Returns: ReviewListResult with matching sessions
    public func listSessions(
        reviewerAgent: String? = nil,
        authorAgent: String? = nil,
        status: ReviewStatus? = nil
    ) -> ReviewListResult {
        lock.lock()
        var results = Array(sessions.values)
        lock.unlock()

        if let reviewer = reviewerAgent {
            results = results.filter { $0.reviewerAgent == reviewer }
        }
        if let author = authorAgent {
            results = results.filter { $0.authorAgent == author }
        }
        if let status = status {
            results = results.filter { $0.status == status }
        }

        results.sort { $0.createdAt > $1.createdAt }

        return .success(sessions: results)
    }

    /// Get active (non-completed) review sessions
    /// - Returns: ReviewListResult with active sessions
    public func getActiveSessions() -> ReviewListResult {
        lock.lock()
        let activeSessions = sessions.values.filter { $0.isActive }
        lock.unlock()

        let sorted = activeSessions.sorted { $0.createdAt > $1.createdAt }
        return .success(sessions: sorted)
    }

    /// Delete a review session
    /// - Parameter sessionId: The review session ID to delete
    /// - Returns: true if deleted, false if not found
    public func deleteSession(sessionId: String) -> Bool {
        lock.lock()
        let removed = sessions.removeValue(forKey: sessionId) != nil
        lock.unlock()
        return removed
    }
}
