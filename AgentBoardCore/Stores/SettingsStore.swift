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
    public var hermesProfiles: [HermesProfile] = []
    public var selectedHermesProfileID: String?

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
            hermesProfiles: hermesProfiles,
            selectedHermesProfileID: selectedHermesProfileID,
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

    public var activeHermesProfile: HermesProfile? {
        guard let selectedHermesProfileID else { return nil }
        return hermesProfiles.first { $0.id == selectedHermesProfileID }
    }

    public var availableHermesProfiles: [HermesProfile] {
        if hermesProfiles.isEmpty {
            return [
                HermesProfile(
                    id: "current",
                    name: currentHermesProfileName,
                    gatewayURL: hermesGatewayURL,
                    modelID: hermesModelID.trimmedOrNil
                )
            ]
        }
        return hermesProfiles
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

    public func saveCurrentHermesProfile(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Give the Hermes profile a name."
            return
        }

        let gatewayURL = hermesGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gatewayURL.isEmpty else {
            errorMessage = "Set a Hermes gateway URL before saving a profile."
            return
        }

        if let existingIndex = hermesProfiles.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            hermesProfiles[existingIndex].gatewayURL = gatewayURL
            hermesProfiles[existingIndex].modelID = hermesModelID.trimmedOrNil
            selectedHermesProfileID = hermesProfiles[existingIndex].id
            statusMessage = "Updated Hermes profile \(trimmedName)."
        } else {
            let profile = HermesProfile(
                name: trimmedName,
                gatewayURL: gatewayURL,
                modelID: hermesModelID.trimmedOrNil
            )
            hermesProfiles.append(profile)
            hermesProfiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            selectedHermesProfileID = profile.id
            statusMessage = "Saved Hermes profile \(trimmedName)."
        }

        errorMessage = nil
    }

    public func selectHermesProfile(id: String) {
        guard let profile = hermesProfiles.first(where: { $0.id == id }) else { return }
        selectedHermesProfileID = profile.id
        hermesGatewayURL = profile.gatewayURL
        if let modelID = profile.modelID {
            hermesModelID = modelID
        }
        errorMessage = nil
        statusMessage = "Switched to \(profile.name)."
    }

    public func removeHermesProfile(_ profile: HermesProfile) {
        hermesProfiles.removeAll { $0.id == profile.id }
        if selectedHermesProfileID == profile.id {
            selectedHermesProfileID = hermesProfiles.first?.id
            if let selectedHermesProfileID {
                selectHermesProfile(id: selectedHermesProfileID)
            }
        }
        errorMessage = nil
        statusMessage = "Removed Hermes profile \(profile.name)."
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
        hermesProfiles = settings.hermesProfiles ?? []
        selectedHermesProfileID = settings.selectedHermesProfileID
        if let selectedHermesProfileID,
           hermesProfiles.contains(where: { $0.id == selectedHermesProfileID }) {
            selectHermesProfile(id: selectedHermesProfileID)
        }

        companionURL = settings.companionURL
        companionToken = secrets.companionToken ?? ""

        githubToken = secrets.githubToken ?? ""
        repositories = settings.repositories
        autoRefreshInterval = settings.autoRefreshInterval
    }

    private var currentHermesProfileName: String {
        if let activeHermesProfile {
            return activeHermesProfile.name
        }

        if let url = URL(string: hermesGatewayURL),
           let port = url.port {
            return "Port \(port)"
        }

        return "Current"
    }
}
