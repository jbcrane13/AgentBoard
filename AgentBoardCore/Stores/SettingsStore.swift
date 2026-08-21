import Foundation
import Observation
import os

@MainActor
@Observable
public final class SettingsStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "SettingsStore")
    private let repository: SettingsRepository
    private let requiresRemoteCompanionHost: Bool

    public var hermesGatewayURL = HermesGatewayConfiguration.defaultBaseURL
    public var hermesModelID = "hermes-agent"
    public var hermesAPIKey = ""
    public var hermesProfiles: [HermesProfile] = []
    public var selectedHermesProfileID: String?
    public var hermesDashboardURL = ""
    public var hermesDashboardUsername = ""
    public var hermesDashboardPassword = ""

    /// Fixed swatch palette assigned round-robin to Hermes profiles that don't have an explicit
    /// `colorHex`, used to visually distinguish them in the chat header.
    public static let hermesProfileColorPalette: [String] = [
        "#4FC3F7", "#FFB74D", "#81C784", "#BA68C8", "#F06292", "#4DB6AC"
    ]

    public var companionURL = "http://127.0.0.1:8742"
    public var companionToken = ""

    public var githubToken = ""
    public var repositories: [ConfiguredRepository] = []
    public var autoRefreshInterval: TimeInterval = 30

    public var isLoaded = false
    public var statusMessage: String?
    public var errorMessage: String?

    public init(repository: SettingsRepository, requiresRemoteCompanionHost: Bool = false) {
        self.repository = repository
        self.requiresRemoteCompanionHost = requiresRemoteCompanionHost
    }

    public var settingsSnapshot: AgentBoardSettings {
        AgentBoardSettings(
            hermesGatewayURL: hermesGatewayURL.trimmedOrNil ?? HermesGatewayConfiguration.defaultBaseURL,
            hermesModelID: hermesModelID.trimmedOrNil,
            hermesProfiles: hermesProfiles,
            selectedHermesProfileID: selectedHermesProfileID,
            dashboardURL: hermesDashboardURL.trimmedOrNil,
            dashboardUsername: hermesDashboardUsername.trimmedOrNil,
            companionURL: companionURL.trimmedOrNil ?? "http://127.0.0.1:8742",
            repositories: repositories,
            autoRefreshInterval: max(30, autoRefreshInterval)
        )
    }

    public var secretsSnapshot: AgentBoardSecrets {
        AgentBoardSecrets(
            hermesAPIKey: hermesAPIKey.trimmedOrNil,
            dashboardPassword: hermesDashboardPassword.trimmedOrNil,
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
        companionConfigurationMessage == nil
    }

    public var companionConfigurationMessage: String? {
        guard let trimmed = companionURL.trimmedOrNil else {
            return "Enter a valid companion URL."
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host(percentEncoded: false),
              !host.isEmpty else {
            return "Enter a valid companion URL."
        }
        if requiresRemoteCompanionHost, Self.isLoopbackHost(host) {
            return "Companion host must be reachable on LAN or Tailscale, not loopback."
        }
        return nil
    }

    private static func isLoopbackHost(_ host: String) -> Bool {
        let lowered = host.lowercased()
        return lowered == "127.0.0.1" || lowered == "localhost" || lowered == "::1"
    }

    public func bootstrap() async {
        guard !isLoaded else { return }
        errorMessage = nil

        let settings = await repository.loadSettings()
        let secrets = await repository.loadSecrets()
        apply(settings: settings, secrets: secrets)

        let profileSecrets = await repository.loadProfileSecrets(profileIDs: hermesProfiles.map(\.id))
        await hydrateAndMigrateProfileSecrets(profileSecrets)

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

    public func saveCurrentHermesProfile(named name: String) async {
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

        let apiKey = hermesAPIKey.trimmedOrNil
        let paletteColor = Self.hermesProfileColorPalette[hermesProfiles.count % Self.hermesProfileColorPalette.count]

        let profileID: String
        if let existingIndex = hermesProfiles
            .firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            hermesProfiles[existingIndex].gatewayURL = gatewayURL
            hermesProfiles[existingIndex].modelID = hermesModelID.trimmedOrNil
            hermesProfiles[existingIndex].apiKey = apiKey
            if hermesProfiles[existingIndex].colorHex == nil {
                hermesProfiles[existingIndex].colorHex = paletteColor
            }
            profileID = hermesProfiles[existingIndex].id
            selectedHermesProfileID = profileID
            statusMessage = "Updated Hermes profile \(trimmedName)."
        } else {
            let profile = HermesProfile(
                name: trimmedName,
                gatewayURL: gatewayURL,
                modelID: hermesModelID.trimmedOrNil,
                apiKey: apiKey,
                colorHex: paletteColor
            )
            hermesProfiles.append(profile)
            hermesProfiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            profileID = profile.id
            selectedHermesProfileID = profileID
            statusMessage = "Saved Hermes profile \(trimmedName)."
        }

        errorMessage = nil

        do {
            try await repository.saveProfileSecrets(ProfileSecrets(apiKey: apiKey), for: profileID)
        } catch {
            logger.error("Failed to save profile secrets: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        // Saving selects the profile, which may not have been active before — harmless to
        // re-point the (app-global) kanban backend again even though it can't have changed.
        onActiveProfileChanged?()
    }

    /// Invoked whenever the active Hermes profile changes *or its configuration is
    /// re-saved* — i.e. from `selectHermesProfile(id:)` and `saveCurrentHermesProfile(named:)`.
    /// `AgentBoardAppModel` hangs kanban backend re-selection off this. It lives here
    /// rather than at each call site because profile switching is reached from the
    /// Settings "Use" button, the chat header profile menu, and the conversation
    /// auto-switch. The kanban backend is app-global now (see `hermesDashboardURL`), so
    /// profile switches never actually change it, but firing the hook is still harmless —
    /// `AgentBoardAppModel.saveSettingsAndReconnect()` is what actually re-points the backend
    /// when the dashboard URL changes.
    @ObservationIgnored
    public var onActiveProfileChanged: (@MainActor () -> Void)?

    public func selectHermesProfile(id: String, silent: Bool = false) {
        guard let profile = hermesProfiles.first(where: { $0.id == id }) else { return }
        selectedHermesProfileID = profile.id
        hermesGatewayURL = profile.gatewayURL
        if let modelID = profile.modelID {
            hermesModelID = modelID
        }
        hermesAPIKey = profile.apiKey ?? hermesAPIKey
        errorMessage = nil
        if !silent {
            statusMessage = "Switched to \(profile.name)."
        }
        onActiveProfileChanged?()
    }

    public func removeHermesProfile(_ profile: HermesProfile) async {
        hermesProfiles.removeAll { $0.id == profile.id }
        if selectedHermesProfileID == profile.id {
            selectedHermesProfileID = hermesProfiles.first?.id
            if let selectedHermesProfileID {
                selectHermesProfile(id: selectedHermesProfileID)
            }
        }
        errorMessage = nil
        statusMessage = "Removed Hermes profile \(profile.name)."
        await repository.deleteProfileSecrets(for: profile.id)
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
            selectHermesProfile(id: selectedHermesProfileID, silent: true)
        }

        // Dashboard config is app-global, not per-profile — hydrate it directly here rather
        // than from the active profile.
        hermesDashboardURL = settings.dashboardURL ?? ""
        hermesDashboardUsername = settings.dashboardUsername ?? ""
        hermesDashboardPassword = secrets.dashboardPassword ?? ""

        companionURL = settings.companionURL
        companionToken = secrets.companionToken ?? ""

        githubToken = secrets.githubToken ?? ""
        repositories = settings.repositories
        autoRefreshInterval = settings.autoRefreshInterval
    }

    /// Hydrates each profile's Keychain-backed `apiKey`. A profile decoded with a legacy inline
    /// `apiKey` (from a settings snapshot persisted before per-profile secrets moved to the
    /// Keychain) and no matching Keychain entry is migrated: the plaintext value is written to
    /// the Keychain and the settings snapshot is re-saved so it's dropped from UserDefaults.
    private func hydrateAndMigrateProfileSecrets(_ profileSecrets: [String: ProfileSecrets]) async {
        var migratedAny = false

        for index in hermesProfiles.indices {
            let profileID = hermesProfiles[index].id
            let keychainSecrets = profileSecrets[profileID]
            let legacyAPIKey = hermesProfiles[index].apiKey

            if let keychainAPIKey = keychainSecrets?.apiKey {
                hermesProfiles[index].apiKey = keychainAPIKey
            } else if let legacyAPIKey {
                do {
                    try await repository.saveProfileSecrets(ProfileSecrets(apiKey: legacyAPIKey), for: profileID)
                    migratedAny = true
                } catch {
                    logger.error(
                        "Failed to migrate legacy Hermes profile API key: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        if migratedAny {
            logger.info("Migrated legacy plaintext Hermes profile API key(s) to the Keychain.")
            do {
                try await repository.saveSettings(settingsSnapshot)
            } catch {
                let reason = error.localizedDescription
                logger.error("Failed to re-save settings after secret migration: \(reason, privacy: .public)")
            }
        }

        if let selectedHermesProfileID,
           let profile = hermesProfiles.first(where: { $0.id == selectedHermesProfileID }) {
            hermesAPIKey = profile.apiKey ?? hermesAPIKey
        }
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
