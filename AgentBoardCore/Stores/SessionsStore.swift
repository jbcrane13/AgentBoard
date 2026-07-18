import Foundation
import Observation
import os

@MainActor
public protocol SessionsCacheStoring {
    func loadSessions() throws -> [AgentSession]
    func replaceSessions(_ sessions: [AgentSession]) throws
}

extension AgentBoardCache: SessionsCacheStoring {}

@MainActor
@Observable
public final class SessionsStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "SessionsStore")
    private let companionClient: CompanionClient
    private let cache: any SessionsCacheStoring
    private let settingsStore: SettingsStore

    public private(set) var sessions: [AgentSession] = []
    public private(set) var isLoading = false
    public private(set) var syncStatus: SessionsSyncStatus = .offline
    public private(set) var lastSyncedAt: Date?
    public var errorMessage: String?
    public var statusMessage: String?

    private var didBootstrap = false
    private var lastFingerprint: String = ""

    public init(
        companionClient: CompanionClient,
        cache: any SessionsCacheStoring,
        settingsStore: SettingsStore
    ) {
        self.companionClient = companionClient
        self.cache = cache
        self.settingsStore = settingsStore
    }

    public func bootstrap() async {
        guard !didBootstrap else { return }

        if settingsStore.isCompanionConfigured {
            syncStatus = .loading
            do {
                let fetched = try await companionClient.listSessions()
                sessions = fetched.sorted { $0.lastSeenAt > $1.lastSeenAt }
                lastFingerprint = fingerprint(sessions)
                persistSessions(sessions)
                syncStatus = .live
                lastSyncedAt = .now
                didBootstrap = true
                return
            } catch {
                logger
                    .error(
                        "Companion unreachable during bootstrap — falling back to local cache: \(error.localizedDescription, privacy: .public)"
                    )
            }
        }

        do {
            sessions = try cache.loadSessions()
            lastFingerprint = fingerprint(sessions)
        } catch {
            logger.error("Failed to load sessions cache: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        if settingsStore.isCompanionConfigured {
            syncStatus = .cached
            await refresh()
        } else {
            syncStatus = .offline
        }

        didBootstrap = true
    }

    public func refresh() async {
        guard settingsStore.isCompanionConfigured else {
            syncStatus = .offline
            if sessions.isEmpty {
                statusMessage = "Connect the companion service in Settings to load sessions."
            }
            return
        }

        isLoading = true

        do {
            let newSessions = try await companionClient.listSessions().sorted { lhs, rhs in
                lhs.lastSeenAt > rhs.lastSeenAt
            }
            let newFingerprint = fingerprint(newSessions)
            if newFingerprint != lastFingerprint {
                sessions = newSessions
                lastFingerprint = newFingerprint
                persistSessions(sessions)
            }
            syncStatus = .live
            lastSyncedAt = .now
        } catch {
            logger.error("Failed to refresh sessions: \(error.localizedDescription, privacy: .public)")
            syncStatus = .cached
            if sessions.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    public func stopSession(id: String) async {
        guard settingsStore.isCompanionConfigured else { return }
        do {
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
            return try await companionClient.fetchSessionOutput(id: sessionID)
        } catch {
            logger.error("Failed to fetch session output: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func fetchTranscript(sessionID: String) async -> SessionTranscript? {
        guard settingsStore.isCompanionConfigured else { return nil }
        do {
            return try await companionClient.fetchTranscript(sessionID: sessionID)
        } catch {
            logger.error("Failed to fetch session transcript: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func handle(event: CompanionEventKind) async {
        switch event {
        case .sessionsChanged, .snapshotRefreshed:
            await refresh()
        case .agentsChanged:
            break
        case .conversationsChanged:
            break // routed via AgentBoardAppModel → ChatStore
        }
    }

    private func fingerprint(_ sessions: [AgentSession]) -> String {
        sessions.map { "\($0.id):\($0.status.rawValue):\($0.lastSeenAt)" }.joined(separator: "|")
    }

    private func persistSessions(_ sessions: [AgentSession]) {
        do {
            try cache.replaceSessions(sessions)
        } catch {
            logger.error("Failed to persist sessions to cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
