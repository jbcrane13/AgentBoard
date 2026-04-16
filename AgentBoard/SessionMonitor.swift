import Foundation
import os

/// Monitors ralphy tmux sessions for completion and sends Telegram notifications.
///
/// Features:
/// - Polls tmux sessions to detect when ralphy sessions finish
/// - Parses session names to extract issue numbers
/// - Sends formatted Telegram notifications on session completion
/// - Tracks monitored sessions to avoid duplicate notifications
///
/// Usage:
/// ```swift
/// let monitor = SessionMonitor(notificationService: notificationService)
/// monitor.startMonitoring()
/// ```
public final class SessionMonitor: Sendable {
    
    // MARK: - Types
    
    /// Information about a completed session
    public struct CompletedSession: Sendable {
        public let sessionName: String
        public let issueNumber: Int?
        public let completedAt: Date
        
        public init(sessionName: String, issueNumber: Int?, completedAt: Date = Date()) {
            self.sessionName = sessionName
            self.issueNumber = issueNumber
            self.completedAt = completedAt
        }
    }
    
    /// Status of a tmux session
    private enum SessionStatus: Sendable {
        case running
        case exited
        case notFound
    }
    
    // MARK: - Properties
    
    private let notificationService: AgentNotificationService
    private let checkInterval: TimeInterval
    private let socketPath: String
    
    // Thread-safe tracking of sessions we've already notified about
    private let notifiedSessions = OSAllocatedUnfairLock(initialState: Set<String>())
    private let monitoredSessions = OSAllocatedUnfairLock(initialState: Set<String>())
    
    private let processQueue = DispatchQueue(label: "com.agentboard.sessionmonitor", qos: .utility)
    
    // MARK: - Initialization
    
    /// Initialize the session monitor
    /// - Parameters:
    ///   - notificationService: Service for sending Telegram notifications
    ///   - checkInterval: How often to check for session completion (default: 30 seconds)
    ///   - socketPath: Path to tmux socket (default: ~/.tmux/sock)
    public init(
        notificationService: AgentNotificationService,
        checkInterval: TimeInterval = 30,
        socketPath: String = "\(NSHomeDirectory())/.tmux/sock"
    ) {
        self.notificationService = notificationService
        self.checkInterval = checkInterval
        self.socketPath = socketPath
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring tmux sessions for completion
    /// Call this to begin periodic checking
    public func startMonitoring() {
        processQueue.async { [weak self] in
            self?.monitoringLoop()
        }
    }
    
    /// Add a session name to monitor
    /// - Parameter sessionName: The tmux session name (e.g., "ralphy-issue-123")
    public func addSession(_ sessionName: String) {
        monitoredSessions.withLock { sessions in
            sessions.insert(sessionName)
        }
    }
    
    /// Remove a session from monitoring
    /// - Parameter sessionName: The tmux session name to stop monitoring
    public func removeSession(_ sessionName: String) {
        monitoredSessions.withLock { sessions in
            sessions.remove(sessionName)
        }
        notifiedSessions.withLock { sessions in
            sessions.remove(sessionName)
        }
    }
    
    /// Check all monitored sessions immediately
    public func checkNow() {
        processQueue.async { [weak self] in
            self?.checkSessions()
        }
    }
    
    // MARK: - Private Methods
    
    private func monitoringLoop() {
        while true {
            checkSessions()
            Thread.sleep(forTimeInterval: checkInterval)
        }
    }
    
    private func checkSessions() {
        let sessions = monitoredSessions.withLock { Array($0) }
        
        for sessionName in sessions {
            let status = getSessionStatus(sessionName)
            
            switch status {
            case .exited:
                handleCompletedSession(sessionName)
            case .running, .notFound:
                break
            }
        }
    }
    
    private func getSessionStatus(_ sessionName: String) -> SessionStatus {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/tmux")
        task.arguments = ["-S", socketPath, "has-session", "-t", sessionName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                // Session exists, check if it's exited
                return checkIfExited(sessionName)
            } else {
                // Session doesn't exist (likely exited and cleaned up)
                return .notFound
            }
        } catch {
            return .notFound
        }
    }
    
    private func checkIfExited(_ sessionName: String) -> SessionStatus {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/tmux")
        task.arguments = ["-S", socketPath, "list-panes", "-t", sessionName, "-F", "#{pane_dead}"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // pane_dead == 1 means the process in the pane has exited
                if output.contains("1") {
                    return .exited
                }
            }
            return .running
        } catch {
            return .running
        }
    }
    
    private func handleCompletedSession(_ sessionName: String) {
        // Check if we've already notified for this session
        let alreadyNotified = notifiedSessions.withLock { $0.contains(sessionName) }
        guard !alreadyNotified else { return }
        
        // Mark as notified
        notifiedSessions.withLock { $0.insert(sessionName) }
        
        // Parse issue number from session name
        let issueNumber = parseIssueNumber(from: sessionName)
        
        // Send Telegram notification
        sendCompletionNotification(
            sessionName: sessionName,
            issueNumber: issueNumber
        )
        
        // Remove from monitored sessions
        removeSession(sessionName)
    }
    
    // MARK: - Session Name Parsing
    
    /// Extract issue number from a ralphy session name
    /// Expected formats: "ralphy-issue-123", "ralphy-123", "issue-123", etc.
    /// - Parameter sessionName: The session name to parse
    /// - Returns: The extracted issue number, or nil if not found
    public func parseIssueNumber(from sessionName: String) -> Int? {
        // Pattern 1: "ralphy-issue-123" or "issue-123"
        if let range = sessionName.range(of: "issue-(\\d+)", options: .regularExpression) {
            let numberString = sessionName[range]
                .replacingOccurrences(of: "issue-", with: "")
            return Int(numberString)
        }
        
        // Pattern 2: "ralphy-123" (number after ralphy-)
        if let range = sessionName.range(of: "ralphy-(\\d+)", options: .regularExpression) {
            let numberString = sessionName[range]
                .replacingOccurrences(of: "ralphy-", with: "")
            return Int(numberString)
        }
        
        // Pattern 3: Any trailing number
        if let range = sessionName.range(of: "(\\d+)$", options: .regularExpression) {
            return Int(sessionName[range])
        }
        
        return nil
    }
    
    // MARK: - Notification
    
    private func sendCompletionNotification(
        sessionName: String,
        issueNumber: Int?
    ) {
        Task {
            let message = formatCompletionMessage(
                sessionName: sessionName,
                issueNumber: issueNumber
            )
            
            let result = await notificationService.sendCustomNotification(text: message)
            
            switch result {
            case .success:
                print("[SessionMonitor] Notification sent for session: \(sessionName)")
            case .failure(let error):
                print("[SessionMonitor] Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatCompletionMessage(
        sessionName: String,
        issueNumber: Int?
    ) -> String {
        var message = "<b>🎉 Ralphy Session Completed</b>\n\n"
        
        if let issueNumber = issueNumber {
            message += "<b>Issue:</b> #\(issueNumber)\n"
        }
        
        message += "<b>Session:</b> \(sessionName)\n"
        message += "<b>Status:</b> ✅ Finished\n\n"
        message += "<i>Completed at \(formattedTimestamp())</i>"
        
        return message
    }
    
    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Convenience Extensions

extension SessionMonitor {
    
    /// Create a session name for a ralphy issue
    /// - Parameter issueNumber: The GitHub issue number
    /// - Returns: A formatted session name
    public static func sessionName(for issueNumber: Int) -> String {
        "ralphy-issue-\(issueNumber)"
    }
    
    /// Create a session name for a ralphy task
    /// - Parameter taskId: A unique task identifier
    /// - Returns: A formatted session name
    public static func sessionName(forTask taskId: String) -> String {
        "ralphy-\(taskId)"
    }
}
