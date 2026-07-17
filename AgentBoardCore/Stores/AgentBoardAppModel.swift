import Foundation
import Observation
import os

@MainActor
@Observable
public final class AgentBoardAppModel {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "AgentBoardAppModel")
    private let companionClient: CompanionClient

    public let settingsStore: SettingsStore
    public let settingsRepository: SettingsRepository
    public let chatStore: ChatStore
    public let workStore: WorkStore
    public let agentsStore: AgentsStore
    public let sessionsStore: SessionsStore
    public let sessionLauncher: SessionLauncher

    public var selectedDestination: AppDestination = .dashboard
    public private(set) var isBootstrapping = false
    public private(set) var didBootstrap = false
    public var statusMessage: String?

    private var eventTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    public init(
        settingsRepository: SettingsRepository,
        settingsStore: SettingsStore,
        chatStore: ChatStore,
        workStore: WorkStore,
        agentsStore: AgentsStore,
        sessionsStore: SessionsStore,
        sessionLauncher: SessionLauncher,
        companionClient: CompanionClient
    ) {
        self.settingsRepository = settingsRepository
        self.settingsStore = settingsStore
        self.chatStore = chatStore
        self.workStore = workStore
        self.agentsStore = agentsStore
        self.sessionsStore = sessionsStore
        self.sessionLauncher = sessionLauncher
        self.companionClient = companionClient
    }

    public func bootstrap() async {
        guard !didBootstrap, !isBootstrapping else { return }
        isBootstrapping = true

        await settingsStore.bootstrap()
        await applyCompanionConfiguration()
        await chatStore.bootstrap()
        await workStore.bootstrap()
        await agentsStore.bootstrap()
        await sessionsStore.bootstrap()
        agentsStore.updateActiveSessionCounts(Self.activeSessionCounts(
            from: sessionsStore.sessions,
            tasks: agentsStore.tasks
        ))

        didBootstrap = true
        isBootstrapping = false
        statusMessage = "Hermes-first workspace ready."

        startCompanionEvents()
        startRefreshLoop()
    }

    public func refreshAll() async {
        await chatStore.refreshConnection()
        await chatStore.refreshModels()
        await workStore.refresh()
        await agentsStore.refresh()
        await sessionsStore.refresh()
        agentsStore.updateActiveSessionCounts(Self.activeSessionCounts(
            from: sessionsStore.sessions,
            tasks: agentsStore.tasks
        ))
    }

    public func saveSettingsAndReconnect() async {
        await settingsStore.persist()
        await applyCompanionConfiguration()
        await refreshAll()
        startCompanionEvents()
        startRefreshLoop()
    }

    /// Apply the current companion URL + token to the shared CompanionClient.
    ///
    /// `SettingsStore.companionConfigurationMessage` intentionally mirrors
    /// `CompanionClient.configure` URL validation, so a configured settings
    /// state should not fail here and leave a previous client configuration in
    /// place. If validation still fails, reset the client to its safe loopback
    /// default so subsequent store calls cannot hit a stale endpoint.
    private func applyCompanionConfiguration() async {
        guard settingsStore.isCompanionConfigured else {
            await companionClient.resetConfiguration()
            return
        }
        do {
            try await companionClient.configure(
                baseURL: settingsStore.companionURL,
                bearerToken: settingsStore.companionToken.trimmedOrNil
            )
        } catch {
            await companionClient.resetConfiguration()
            logger.error("Companion configure failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Companion configuration failed."
        }
    }

    private func startCompanionEvents() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard self.settingsStore.isCompanionConfigured else {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }

                do {
                    try await self.companionClient.configure(
                        baseURL: self.settingsStore.companionURL,
                        bearerToken: self.settingsStore.companionToken.trimmedOrNil
                    )
                    let stream = try await self.companionClient.events()
                    for try await event in stream {
                        await self.handle(event: event)
                    }
                } catch {
                    self.logger.error("Companion event stream ended: \(error.localizedDescription, privacy: .public)")
                    self.statusMessage = "Companion live updates paused. Reconnecting..."
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let base = max(60.0, self.settingsStore.autoRefreshInterval)
                // Add 0-15s jitter to avoid thundering herd on reconnect
                let jitter = Double(Int.random(in: 0 ... 15))
                try? await Task.sleep(for: .seconds(base + jitter))
                guard !Task.isCancelled else { return }
                await self.workStore.refresh()
                await self.agentsStore.refresh()
                await self.sessionsStore.refresh()
                self.agentsStore.updateActiveSessionCounts(Self.activeSessionCounts(
                    from: self.sessionsStore.sessions,
                    tasks: self.agentsStore.tasks
                ))
            }
        }
    }

    private func handle(event: CompanionEvent) async {
        statusMessage = "Companion update: \(event.kind.rawValue)"
        await sessionsStore.handle(event: event.kind)
        agentsStore.updateActiveSessionCounts(Self.activeSessionCounts(
            from: sessionsStore.sessions,
            tasks: agentsStore.tasks
        ))

        // Route conversation sync events to ChatStore for cross-device sync
        if event.kind == .conversationsChanged {
            await chatStore.refreshConversationsFromCompanion()
        }
    }

    // MARK: - Session Counts

    /// Derive per-agent active session counts by joining each session's
    /// `linkedTaskID` to the kanban task it references, then keying by that
    /// task's (trimmed) assignee — the same namespace `AgentsStore` groups
    /// tasks by. `source` (machine name) and `model` (tool name, e.g. "Codex")
    /// are NOT agent identity in this sense, so they can't be used directly;
    /// the task assignee is the only field session and task share meaning
    /// for. "Active" means the session's status is `.running`. Sessions with
    /// no `linkedTaskID`, or whose linked task has no assignee, contribute to
    /// no agent's count.
    nonisolated static func activeSessionCounts(
        from sessions: [AgentSession],
        tasks: [KanbanTask]
    ) -> [String: Int] {
        let assigneeByTaskID = Dictionary(
            uniqueKeysWithValues: tasks.compactMap { task -> (String, String)? in
                guard let assignee = task.assignee?.trimmedOrNil else { return nil }
                return (task.id, assignee)
            }
        )

        var counts: [String: Int] = [:]
        for session in sessions where session.status == .running {
            guard let taskID = session.linkedTaskID, let assignee = assigneeByTaskID[taskID] else { continue }
            counts[assignee, default: 0] += 1
        }
        return counts
    }
}

@MainActor
public enum AgentBoardBootstrap {
    public static func makeLiveAppModel() -> AgentBoardAppModel {
        let cache: any AgentBoardCacheProtocol

        do {
            cache = try AgentBoardCache()
        } catch {
            do {
                cache = try AgentBoardCache(inMemory: true)
            } catch {
                Logger(subsystem: "com.agentboard.modern", category: "AgentBoardBootstrap")
                    .fault("Cache unavailable, running cache-less: \(error.localizedDescription)")
                cache = NoopAgentBoardCache()
            }
        }

        let settingsRepository = SettingsRepository()
        let settingsStore = SettingsStore(repository: settingsRepository)

        let hermesClient = HermesGatewayClient()
        let gitHubService = GitHubWorkService()
        let companionClient = CompanionClient()

        let chatStore = ChatStore(
            hermesClient: hermesClient,
            cache: cache,
            settingsStore: settingsStore,
            companionClient: companionClient
        )
        let workStore = WorkStore(
            service: gitHubService,
            cache: cache,
            settingsStore: settingsStore
        )
        let agentsStore = AgentsStore(cache: cache, settingsStore: settingsStore)
        let sessionsStore = SessionsStore(
            companionClient: companionClient,
            cache: cache,
            settingsStore: settingsStore
        )
        let sessionLauncher = SessionLauncher()

        // Pre-warm the shell-environment probe in the background so it's ready
        // by the time the user launches a session — replaces the previous
        // synchronous static-initializer that could hang the UI for up to 5s.
        #if os(macOS)
            ShellEnvironment.warm()
        #endif

        return AgentBoardAppModel(
            settingsRepository: settingsRepository,
            settingsStore: settingsStore,
            chatStore: chatStore,
            workStore: workStore,
            agentsStore: agentsStore,
            sessionsStore: sessionsStore,
            sessionLauncher: sessionLauncher,
            companionClient: companionClient
        )
    }
}
