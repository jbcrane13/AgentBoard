import Foundation
import Observation
import os

@MainActor
@Observable
public final class SettingsStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "SettingsStore")
    private let repository: SettingsRepository

    public var hermesGatewayURL = "http://127.0.0.1:8642"
    public var hermesModelID = "hermes-agent"
    public var hermesAPIKey = ""

    public var companionURL = "http://127.0.0.1:8742"
    public var companionToken = ""

    public var githubToken = ""
    public var repositories: [ConfiguredRepository] = []
    public var autoRefreshInterval: TimeInterval = 30

    public var isLoaded = false
    public var statusMessage: String?
    public var errorMessage: String?

    public init(repository: SettingsRepository) {
        self.repository = repository
    }

    public var settingsSnapshot: AgentBoardSettings {
        AgentBoardSettings(
            hermesGatewayURL: hermesGatewayURL.trimmedOrNil ?? "http://127.0.0.1:8642",
            hermesModelID: hermesModelID.trimmedOrNil,
            companionURL: companionURL.trimmedOrNil ?? "http://127.0.0.1:8742",
            repositories: repositories,
            autoRefreshInterval: max(15, autoRefreshInterval)
        )
    }

    public var secretsSnapshot: AgentBoardSecrets {
        AgentBoardSecrets(
            hermesAPIKey: hermesAPIKey.trimmedOrNil,
            githubToken: githubToken.trimmedOrNil,
            companionToken: companionToken.trimmedOrNil
        )
    }

    public var isGitHubConfigured: Bool {
        !repositories.isEmpty && !(githubToken.trimmedOrNil == nil)
    }

    public var isCompanionConfigured: Bool {
        companionURL.trimmedOrNil != nil
    }

    public func bootstrap() async {
        guard !isLoaded else { return }
        errorMessage = nil

        let settings = await repository.loadSettings()
        let secrets = await repository.loadSecrets()
        apply(settings: settings, secrets: secrets)
        isLoaded = true
        statusMessage = "Settings loaded."
    }

    public func persist() async {
        errorMessage = nil

        do {
            try await repository.saveSettings(settingsSnapshot)
            try await repository.saveSecrets(secretsSnapshot)
            statusMessage = "Settings saved."
        } catch {
            logger.error("Failed to persist settings: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func addRepository(owner: String, name: String) {
        let repository = ConfiguredRepository(owner: owner, name: name)
        guard !repository.owner.isEmpty, !repository.name.isEmpty else {
            errorMessage = "Add both the repo owner and repo name."
            return
        }

        guard !repositories.contains(repository) else {
            errorMessage = "\(repository.fullName) is already connected."
            return
        }

        repositories.append(repository)
        repositories.sort {
            $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
        errorMessage = nil
        statusMessage = "Added \(repository.fullName)."
    }

    public func removeRepository(_ repository: ConfiguredRepository) {
        repositories.removeAll { $0 == repository }
        statusMessage = "Removed \(repository.fullName)."
        errorMessage = nil
    }

    private func apply(settings: AgentBoardSettings, secrets: AgentBoardSecrets) {
        hermesGatewayURL = settings.hermesGatewayURL
        hermesModelID = settings.hermesModelID ?? "hermes-agent"
        hermesAPIKey = secrets.hermesAPIKey ?? ""

        companionURL = settings.companionURL
        companionToken = secrets.companionToken ?? ""

        githubToken = secrets.githubToken ?? ""
        repositories = settings.repositories
        autoRefreshInterval = settings.autoRefreshInterval
    }
}
