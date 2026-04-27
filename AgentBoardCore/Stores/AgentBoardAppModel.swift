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

    public var selectedDestination: AppDestination = .chat
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
        await chatStore.bootstrap()
        await workStore.bootstrap()
        await agentsStore.bootstrap()
        await sessionsStore.bootstrap()

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
    }

    public func saveSettingsAndReconnect() async {
        await settingsStore.persist()
        await refreshAll()
        startCompanionEvents()
        startRefreshLoop()
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
            }
        }
    }

    private func handle(event: CompanionEvent) async {
        statusMessage = "Companion update: \(event.kind.rawValue)"
        await agentsStore.handle(event: event.kind)
        await sessionsStore.handle(event: event.kind)
    }
}

@MainActor
public enum AgentBoardBootstrap {
    public static func makeLiveAppModel() -> AgentBoardAppModel {
        let cache: AgentBoardCache

        do {
            cache = try AgentBoardCache()
        } catch {
            do {
                cache = try AgentBoardCache(inMemory: true)
            } catch {
                fatalError("Unable to create AgentBoard cache: \(error.localizedDescription)")
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
            settingsStore: settingsStore
        )
        let workStore = WorkStore(
            service: gitHubService,
            cache: cache,
            settingsStore: settingsStore
        )
        let agentsStore = AgentsStore(
            companionClient: companionClient,
            cache: cache,
            settingsStore: settingsStore
        )
        let sessionsStore = SessionsStore(
            companionClient: companionClient,
            cache: cache,
            settingsStore: settingsStore
        )
        let sessionLauncher = SessionLauncher()

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
