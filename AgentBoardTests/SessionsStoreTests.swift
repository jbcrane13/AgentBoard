import AgentBoardCore
import Foundation
import os
import Testing

@Suite(.serialized)
struct SessionsStoreTests {
    @Test
    @MainActor
    func bootstrapMarksLiveWhenCompanionResponds() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = AgentSession(
            id: "remote-1",
            source: "Tailscale Mac",
            status: .running,
            model: "Codex",
            startedAt: now,
            lastSeenAt: now
        )

        let companionClient = CompanionClient(session: makeMockSession { request in
            #expect(request.url?.path == "/v1/sessions")
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try (response, encoder.encode([session]))
        })

        let store = try await makeStore(
            companionClient: companionClient,
            companionURL: "http://test.local:8742"
        )

        await store.bootstrap()

        #expect(store.syncStatus == .live)
        #expect(store.lastSyncedAt != nil)
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.id == "remote-1")
    }

    @Test
    @MainActor
    func bootstrapFallsBackToCachedWhenCompanionFails() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cachedSession = AgentSession(
            id: "cached-1",
            source: "Local cache",
            status: .idle,
            startedAt: now,
            lastSeenAt: now
        )

        let cache = try AgentBoardCache(inMemory: true)
        try cache.replaceSessions([cachedSession])

        let companionClient = CompanionClient(session: makeMockSession { _ in
            throw URLError(.cannotConnectToHost)
        })

        let store = try await makeStore(
            cache: cache,
            companionClient: companionClient,
            companionURL: "http://test.local:8742"
        )

        await store.bootstrap()

        #expect(store.syncStatus == .cached)
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.id == "cached-1")
        #expect(store.lastSyncedAt == nil)
    }

    @Test
    @MainActor
    func bootstrapMarksOfflineWhenCompanionNotConfigured() async throws {
        let store = try await makeStore(companionURL: "")

        await store.bootstrap()

        #expect(store.syncStatus == .offline)
        #expect(store.lastSyncedAt == nil)
    }

    @Test
    @MainActor
    func refreshTransitionsCachedToLiveWhenCompanionRecovers() async throws {
        let session = AgentSession(
            id: "remote-2",
            source: "Tailscale Mac",
            status: .running,
            startedAt: .now,
            lastSeenAt: .now
        )

        // Bootstrap calls listSessions twice on failure path
        // (companion-first then refresh fallback). Fail both, succeed on the 3rd call.
        let counter = SyncCounter()
        let companionClient = CompanionClient(session: makeMockSession { request in
            let attempt = counter.increment()
            if attempt <= 2 {
                throw URLError(.cannotConnectToHost)
            }
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try (response, encoder.encode([session]))
        })

        let store = try await makeStore(
            companionClient: companionClient,
            companionURL: "http://test.local:8742"
        )

        await store.bootstrap()
        #expect(store.syncStatus == .cached)

        await store.refresh()
        #expect(store.syncStatus == .live)
        #expect(store.lastSyncedAt != nil)
        #expect(store.sessions.first?.id == "remote-2")
    }

    @Test
    @MainActor
    func bootstrapStaysLiveWhenCacheWriteFails() async throws {
        // If the companion responds with fresh data but the local cache write
        // fails (e.g. SwiftData under disk pressure), we should still mark the
        // store as .live and surface the fetched data — losing persistence is
        // not a reason to discard known-fresh in-memory state.
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = AgentSession(
            id: "remote-1",
            source: "Tailscale Mac",
            status: .running,
            model: "Codex",
            startedAt: now,
            lastSeenAt: now
        )

        let companionClient = CompanionClient(session: makeMockSession { request in
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try (response, encoder.encode([session]))
        })

        let cache = FailingSessionsCache(failOnReplace: true)
        let store = try await makeStore(
            cache: cache,
            companionClient: companionClient,
            companionURL: "http://test.local:8742"
        )

        await store.bootstrap()

        #expect(store.syncStatus == .live)
        #expect(store.lastSyncedAt != nil)
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.id == "remote-1")
    }

    @Test
    @MainActor
    func refreshMarksCachedWhenCompanionDropsAfterLive() async throws {
        let session = AgentSession(
            id: "remote-3",
            source: "Tailscale Mac",
            status: .running,
            startedAt: .now,
            lastSeenAt: .now
        )

        let shouldFail = SyncFlag(value: false)
        let companionClient = CompanionClient(session: makeMockSession { request in
            if shouldFail.snapshot() {
                throw URLError(.cannotConnectToHost)
            }
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try (response, encoder.encode([session]))
        })

        let store = try await makeStore(
            companionClient: companionClient,
            companionURL: "http://test.local:8742"
        )

        await store.bootstrap()
        #expect(store.syncStatus == .live)

        shouldFail.set(true)
        await store.refresh()

        #expect(store.syncStatus == .cached)
        #expect(store.sessions.first?.id == "remote-3")
    }

    // MARK: - Helpers

    @MainActor
    private func makeStore(
        cache: (any SessionsCacheStoring)? = nil,
        companionClient: CompanionClient = CompanionClient(),
        companionURL: String
    ) async throws -> SessionsStore {
        let suiteName = "SessionsStoreTests-\(UUID().uuidString)"
        let repository = SettingsRepository(
            suiteName: suiteName,
            serviceName: "SessionsStoreTests-\(UUID().uuidString)"
        )
        let settingsStore = SettingsStore(repository: repository)
        settingsStore.companionURL = companionURL
        settingsStore.companionToken = ""

        let resolvedCache: any SessionsCacheStoring = try cache ?? AgentBoardCache(inMemory: true)
        return SessionsStore(
            companionClient: companionClient,
            cache: resolvedCache,
            settingsStore: settingsStore
        )
    }
}

@MainActor
private final class FailingSessionsCache: SessionsCacheStoring {
    private var stored: [AgentSession]
    private let failOnReplace: Bool

    init(stored: [AgentSession] = [], failOnReplace: Bool) {
        self.stored = stored
        self.failOnReplace = failOnReplace
    }

    func loadSessions() throws -> [AgentSession] {
        stored
    }

    func replaceSessions(_ sessions: [AgentSession]) throws {
        if failOnReplace {
            throw CocoaError(.fileWriteOutOfSpace)
        }
        stored = sessions
    }
}

private struct SyncFlag: Sendable {
    private let storage: OSAllocatedUnfairLock<Bool>

    init(value: Bool) {
        storage = OSAllocatedUnfairLock(initialState: value)
    }

    func snapshot() -> Bool {
        storage.withLock { $0 }
    }

    func set(_ newValue: Bool) {
        storage.withLock { $0 = newValue }
    }
}

private struct SyncCounter: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: 0)

    func increment() -> Int {
        storage.withLock { count in
            count += 1
            return count
        }
    }
}
