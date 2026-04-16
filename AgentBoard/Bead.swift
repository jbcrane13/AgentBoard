import Foundation

/// Represents a bead (node/connection point) in the agent board system
public struct Bead: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let createdAt: Date
    public var updatedAt: Date
    
    // Session tracking properties
    public var activeSessionId: String?
    public var sessionHistory: [SessionRecord]
    
    /// Initialize a new bead
    /// - Parameters:
    ///   - id: Unique identifier for the bead
    ///   - name: Display name
    ///   - description: Optional description
    ///   - activeSessionId: Currently active session ID (if any)
    ///   - sessionHistory: History of sessions
    public init(
        id: String,
        name: String,
        description: String? = nil,
        activeSessionId: String? = nil,
        sessionHistory: [SessionRecord] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = Date()
        self.updatedAt = Date()
        self.activeSessionId = activeSessionId
        self.sessionHistory = sessionHistory
    }
    
    /// Start a new session for this bead
    /// - Parameter sessionId: The session ID to start
    /// - Returns: Updated bead with the new session
    public func startingSession(_ sessionId: String) -> Bead {
        var copy = self
        copy.activeSessionId = sessionId
        let record = SessionRecord(sessionId: sessionId, startedAt: Date())
        copy.sessionHistory.append(record)
        copy.updatedAt = Date()
        return copy
    }
    
    /// End the current active session
    /// - Returns: Updated bead with session ended
    public func endingCurrentSession() -> Bead {
        var copy = self
        if let activeId = copy.activeSessionId {
            if let lastIndex = copy.sessionHistory.lastIndex(where: { $0.sessionId == activeId && $0.endedAt == nil }) {
                copy.sessionHistory[lastIndex].endedAt = Date()
            }
            copy.activeSessionId = nil
            copy.updatedAt = Date()
        }
        return copy
    }
}

/// Record of a session associated with a bead
public struct SessionRecord: Codable, Identifiable, Sendable {
    public let id: String
    public let sessionId: String
    public let startedAt: Date
    public var endedAt: Date?
    
    /// Initialize a session record
    /// - Parameters:
    ///   - id: Unique identifier for the record
    ///   - sessionId: The session identifier
    ///   - startedAt: When the session started
    ///   - endedAt: When the session ended (nil if ongoing)
    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        startedAt: Date,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
    
    /// Whether this session is currently active
    public var isActive: Bool {
        endedAt == nil
    }
    
    /// Duration of the session (if ended)
    public var duration: TimeInterval? {
        guard let endedAt = endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}