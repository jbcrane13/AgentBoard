import Foundation
import Observation
import os

@MainActor
@Observable
public final class SessionsStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "SessionsStore")
    private let companionClient: CompanionClient
    private let cache: AgentBoardCache
    private let settingsStore: SettingsStore

    public private(set) var sessions: [AgentSession] = []
    public private(set) var isLoading = false
    public var errorMessage: String?
    public var statusMessage: String?

    private var didBootstrap = false

    public init(
        companionClient: CompanionClient,
        cache: AgentBoardCache,
        settingsStore: SettingsStore
    ) {
        self.companionClient = companionClient
        self.cache = cache
        self.settingsStore = settingsStore
    }

    public func bootstrap() async {
        guard !didBootstrap else { return }

        do {
            sessions = try cache.loadSessions()
        } catch {
            logger.error("Failed to load sessions cache: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        if settingsStore.isCompanionConfigured {
            await refresh()
        }

        didBootstrap = true
    }

    public func refresh() async {
        guard settingsStore.isCompanionConfigured else {
            if sessions.isEmpty {
                statusMessage = "Connect the companion service in Settings to load sessions."
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await companionClient.configure(
                baseURL: settingsStore.companionURL,
                bearerToken: settingsStore.companionToken.trimmedOrNil
            )
            sessions = try await companionClient.listSessions().sorted { lhs, rhs in
                lhs.lastSeenAt > rhs.lastSeenAt
            }
            try cache.replaceSessions(sessions)
            statusMessage = "Loaded \(sessions.count) live sessions."
        } catch {
            logger.error("Failed to refresh sessions: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func stopSession(id: String) async {
        guard settingsStore.isCompanionConfigured else { return }
        do {
            try await companionClient.configure(
                baseURL: settingsStore.companionURL,
                bearerToken: settingsStore.companionToken.trimmedOrNil
            )
            try await companionClient.stopSession(id: id)
            await refresh()
            statusMessage = "Session stopped."
        } catch {
            logger.error("Failed to stop session: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func nudgeSession(id: String) async {
        guard settingsStore.isCompanionConfigured else { return }
        do {
            try await companionClient.configure(
                baseURL: settingsStore.companionURL,
                bearerToken: settingsStore.companionToken.trimmedOrNil
            )
            try await companionClient.nudgeSession(id: id)
            statusMessage = "Session nudged."
        } catch {
            logger.error("Failed to nudge session: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func fetchOutput(sessionID: String) async -> String? {
        guard settingsStore.isCompanionConfigured else { return nil }
        do {
            try await companionClient.configure(
                baseURL: settingsStore.companionURL,
                bearerToken: settingsStore.companionToken.trimmedOrNil
            )
            return try await companionClient.fetchSessionOutput(id: sessionID)
        } catch {
            logger.error("Failed to fetch session output: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func handle(event: CompanionEventKind) async {
        switch event {
        case .sessionsChanged, .snapshotRefreshed:
            await refresh()
        case .tasksChanged, .agentsChanged:
            break
        }
    }
}
