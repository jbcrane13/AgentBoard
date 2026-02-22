import Foundation
import Testing
@testable import AgentBoard

// MARK: - State Query Helpers for Unit Tests

/// Helper for querying and validating AppState in tests
@MainActor
final class StateQueryHelpers {
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Bead Queries
    
    /// Count total beads on the board
    func countBeadsOnBoard() -> Int {
        appState.beads.count
    }
    
    /// Count beads in a specific status
    func countBeads(withStatus status: BeadStatus) -> Int {
        appState.beads.filter { $0.status == status }.count
    }
    
    /// Check if a bead with the given title exists
    func beadExists(title: String) -> Bool {
        appState.beads.contains { $0.title == title }
    }
    
    /// Check if a bead with the given ID exists
    func beadExists(id: String) -> Bool {
        appState.beads.contains { $0.id == id }
    }
    
    /// Find a bead by title
    func findBead(title: String) -> Bead? {
        appState.beads.first { $0.title == title }
    }
    
    /// Find a bead by ID
    func findBead(id: String) -> Bead? {
        appState.beads.first { $0.id == id }
    }
    
    /// Get all beads in a specific status
    func beadsInStatus(_ status: BeadStatus) -> [Bead] {
        appState.beads.filter { $0.status == status }
    }
    
    // MARK: - Session Queries
    
    /// Count coding sessions
    func countSessions() -> Int {
        appState.sessions.count
    }
    
    /// Check if a session with the given ID exists
    func sessionExists(id: String) -> Bool {
        appState.sessions.contains { $0.id == id }
    }
    
    /// Find a session by ID
    func findSession(id: String) -> CodingSession? {
        appState.sessions.first { $0.id == id }
    }
    
    /// Get sessions with a specific status
    func sessionsWithStatus(_ status: SessionStatus) -> [CodingSession] {
        appState.sessions.filter { $0.status == status }
    }
    
    // MARK: - Chat Queries
    
    /// Count chat messages
    func countChatMessages() -> Int {
        appState.chatMessages.count
    }
    
    /// Count messages by role
    func countMessages(role: MessageRole) -> Int {
        appState.chatMessages.filter { $0.role == role }.count
    }
    
    /// Get last message
    func lastMessage() -> ChatMessage? {
        appState.chatMessages.last
    }
    
    /// Get last user message
    func lastUserMessage() -> ChatMessage? {
        appState.chatMessages.last(where: { $0.role == .user })
    }
    
    /// Get last assistant message
    func lastAssistantMessage() -> ChatMessage? {
        appState.chatMessages.last(where: { $0.role == .assistant })
    }
    
    /// Check if thinking level is set
    func thinkingLevel() -> String? {
        appState.chatThinkingLevel
    }
    
    /// Get current session key
    func currentSessionKey() -> String {
        appState.currentSessionKey
    }
    
    // MARK: - Settings Queries
    
    /// Get gateway URL
    func gatewayURL() -> String? {
        appState.appConfig.openClawGatewayURL
    }
    
    /// Get token (note: may be stored in keychain)
    func gatewayToken() -> String? {
        appState.appConfig.openClawToken
    }
    
    /// Get projects count
    func projectsCount() -> Int {
        appState.projects.count
    }
    
    /// Get selected project
    func selectedProject() -> Project? {
        appState.selectedProject
    }
    
    // MARK: - Connection State Queries
    
    /// Get connection state
    func connectionState() -> OpenClawConnectionState {
        appState.chatConnectionState
    }
    
    /// Check if connected
    func isConnected() -> Bool {
        appState.chatConnectionState == .connected
    }
    
    /// Check if streaming
    func isStreaming() -> Bool {
        appState.isChatStreaming
    }
    
    /// Get error message
    func errorMessage() -> String? {
        appState.errorMessage
    }
    
    /// Get status message
    func statusMessage() -> String? {
        appState.statusMessage
    }
    
    // MARK: - Canvas Queries
    
    /// Get canvas content count
    func canvasContentCount() -> Int {
        appState.canvasHistory.count
    }
    
    /// Get current canvas content
    func currentCanvasContent() -> CanvasContent? {
        appState.currentCanvasContent
    }
    
    /// Check if can go back in canvas history
    func canGoCanvasBack() -> Bool {
        appState.canGoCanvasBack
    }
    
    /// Check if can go forward in canvas history
    func canGoCanvasForward() -> Bool {
        appState.canGoCanvasForward
    }
    
    // MARK: - Navigation Queries
    
    /// Get selected tab
    func selectedTab() -> CenterTab {
        appState.selectedTab
    }
    
    /// Get right panel mode
    func rightPanelMode() -> RightPanelMode {
        appState.rightPanelMode
    }
    
    /// Get sidebar selection
    func sidebarNavSelection() -> SidebarNavItem? {
        appState.sidebarNavSelection
    }
    
    /// Get active session ID
    func activeSessionID() -> String? {
        appState.activeSessionID
    }
}

// MARK: - Async Wait Helpers

/// Helper for waiting on async state changes
@MainActor
final class AsyncWaitHelpers {
    private let appState: AppState
    private let defaultTimeout: TimeInterval
    
    init(appState: AppState, defaultTimeout: TimeInterval = 5.0) {
        self.appState = appState
        self.defaultTimeout = defaultTimeout
    }
    
    /// Wait for bead count to change
    func waitForBeadCount(
        expected: Int,
        timeout: TimeInterval? = nil
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if appState.beads.count == expected {
                return true
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.beads.count == expected
    }
    
    /// Wait for bead with title to appear
    func waitForBead(
        title: String,
        timeout: TimeInterval? = nil
    ) async throws -> Bead? {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if let bead = appState.beads.first(where: { $0.title == title }) {
                return bead
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.beads.first(where: { $0.title == title })
    }
    
    /// Wait for session with ID to appear
    func waitForSession(
        id: String,
        timeout: TimeInterval? = nil
    ) async throws -> CodingSession? {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if let session = appState.sessions.first(where: { $0.id == id }) {
                return session
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.sessions.first(where: { $0.id == id })
    }
    
    /// Wait for session count to change
    func waitForSessionCount(
        expected: Int,
        timeout: TimeInterval? = nil
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if appState.sessions.count == expected {
                return true
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.sessions.count == expected
    }
    
    /// Wait for connection state
    func waitForConnectionState(
        expected: OpenClawConnectionState,
        timeout: TimeInterval? = nil
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if appState.chatConnectionState == expected {
                return true
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.chatConnectionState == expected
    }
    
    /// Wait for streaming to start
    func waitForStreaming(
        timeout: TimeInterval? = nil
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if appState.isChatStreaming {
                return true
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.isChatStreaming
    }
    
    /// Wait for streaming to stop
    func waitForStreamingEnd(
        timeout: TimeInterval? = nil
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if !appState.isChatStreaming {
                return true
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return !appState.isChatStreaming
    }
    
    /// Wait for message count to reach expected
    func waitForMessageCount(
        expected: Int,
        timeout: TimeInterval? = nil
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if appState.chatMessages.count >= expected {
                return true
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.chatMessages.count >= expected
    }
    
    /// Wait for error message to appear
    func waitForError(
        timeout: TimeInterval? = nil
    ) async throws -> String? {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if appState.errorMessage != nil {
                return appState.errorMessage
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.errorMessage
    }
    
    /// Wait for status message to appear
    func waitForStatus(
        timeout: TimeInterval? = nil
    ) async throws -> String? {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if appState.statusMessage != nil {
                return appState.statusMessage
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.statusMessage
    }
    
    /// Wait for canvas content to appear
    func waitForCanvasContent(
        timeout: TimeInterval? = nil
    ) async throws -> CanvasContent? {
        let deadline = Date().addingTimeInterval(timeout ?? defaultTimeout)
        while Date() < deadline {
            if appState.currentCanvasContent != nil {
                return appState.currentCanvasContent
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return appState.currentCanvasContent
    }
}

// MARK: - Test Data Builder

/// Helper for creating test data
final class TestDataBuilder {
    /// Create a test bead draft
    static func createBeadDraft(
        title: String = "Test Bead \(UUID().uuidString.prefix(8))",
        description: String = "Test description",
        kind: BeadKind = .task,
        status: BeadStatus = .open,
        priority: Int = 2,
        assignee: String = "",
        labels: [String] = [],
        epicId: String? = nil
    ) -> BeadDraft {
        BeadDraft(
            title: title,
            description: description,
            kind: kind,
            status: status,
            priority: priority,
            assignee: assignee,
            labelsText: labels.joined(separator: ", "),
            epicId: epicId
        )
    }
    
    /// Create a test project
    static func createProject(
        name: String = "TestProject",
        path: URL? = nil
    ) -> Project {
        let url = path ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("TestProject-\(UUID().uuidString)")
        return Project(
            id: UUID(),
            name: name,
            path: url,
            beadsPath: url.appendingPathComponent(".beads"),
            icon: "📁",
            isActive: false,
            openCount: 0,
            inProgressCount: 0,
            totalCount: 0
        )
    }
}

// MARK: - Test Cleanup Helper

/// Helper for cleaning up test data
@MainActor
final class TestCleanupHelper {
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Clear all chat messages
    func clearChatMessages() {
        appState.chatMessages = []
    }
    
    /// Clear canvas history
    func clearCanvasHistory() {
        appState.canvasHistory = []
        appState.canvasHistoryIndex = -1
    }
    
    /// Reset error message
    func clearError() {
        appState.errorMessage = nil
    }
    
    /// Reset status message
    func clearStatus() {
        appState.statusMessage = nil
    }
    
    /// Clear all test state
    func clearAll() {
        clearChatMessages()
        clearCanvasHistory()
        clearError()
        clearStatus()
    }
}