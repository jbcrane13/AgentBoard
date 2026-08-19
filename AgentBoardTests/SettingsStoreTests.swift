import AgentBoardCore
import Foundation
import Testing

@Suite("SettingsStore", .serialized)
@MainActor
struct SettingsStoreTests {
    /// Mirrors the private `SettingsKeys.snapshot` UserDefaults key in
    /// `SettingsRepository.swift`, used only to seed a raw legacy snapshot blob for the
    /// profile-secret migration test below.
    private static let legacySnapshotDefaultsKey = "modern.agentboard.settings.snapshot"

    private func makeStore(requiresRemoteCompanionHost: Bool = false) -> SettingsStore {
        makeStoreWithRepository(requiresRemoteCompanionHost: requiresRemoteCompanionHost).store
    }

    private func makeStoreWithRepository(
        requiresRemoteCompanionHost: Bool = false
    ) -> (store: SettingsStore, repository: SettingsRepository) {
        let repo = SettingsRepository(
            suiteName: "SettingsStoreTests-\(UUID().uuidString)",
            serviceName: "SettingsStoreTests-\(UUID().uuidString)"
        )
        let store = SettingsStore(
            repository: repo,
            requiresRemoteCompanionHost: requiresRemoteCompanionHost
        )
        return (store, repo)
    }

    // MARK: - isGitHubConfigured

    @Test func isGitHubConfiguredRequiresBothTokenAndRepos() {
        let store = makeStore()
        #expect(!store.isGitHubConfigured)

        store.githubToken = "ghp_test"
        #expect(!store.isGitHubConfigured)

        store.repositories = [ConfiguredRepository(owner: "org", name: "repo")]
        #expect(store.isGitHubConfigured)
    }

    @Test func isGitHubConfiguredFalseWhenTokenEmpty() {
        let store = makeStore()
        store.repositories = [ConfiguredRepository(owner: "org", name: "repo")]
        store.githubToken = ""
        #expect(!store.isGitHubConfigured)
    }

    @Test func isGitHubConfiguredFalseWhenTokenWhitespaceOnly() {
        let store = makeStore()
        store.repositories = [ConfiguredRepository(owner: "org", name: "repo")]
        store.githubToken = "   "
        #expect(!store.isGitHubConfigured)
    }

    // MARK: - addRepository

    @Test func addRepositoryAppendsWhenValid() {
        let store = makeStore()
        store.addRepository(owner: "jbcrane13", name: "AgentBoard")
        #expect(store.repositories.count == 1)
        #expect(store.repositories[0].fullName == "jbcrane13/AgentBoard")
        #expect(store.errorMessage == nil)
        #expect(store.statusMessage?.contains("jbcrane13/AgentBoard") == true)
    }

    @Test func addRepositoryRejectsDuplicate() {
        let store = makeStore()
        store.addRepository(owner: "org", name: "repo")
        store.addRepository(owner: "org", name: "repo")
        #expect(store.repositories.count == 1)
        #expect(store.errorMessage?.contains("already connected") == true)
    }

    @Test func addRepositoryTrimsWhitespace() {
        let store = makeStore()
        store.addRepository(owner: "  org  ", name: "  repo  ")
        #expect(store.repositories[0].owner == "org")
        #expect(store.repositories[0].name == "repo")
    }

    @Test func addRepositoryRejectsEmptyOwner() {
        let store = makeStore()
        store.addRepository(owner: "", name: "repo")
        #expect(store.repositories.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func addRepositoryRejectsEmptyName() {
        let store = makeStore()
        store.addRepository(owner: "org", name: "")
        #expect(store.repositories.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func addRepositoryKeepsSortedOrder() {
        let store = makeStore()
        store.addRepository(owner: "z-org", name: "repo")
        store.addRepository(owner: "a-org", name: "repo")
        store.addRepository(owner: "m-org", name: "repo")
        #expect(store.repositories[0].owner == "a-org")
        #expect(store.repositories[1].owner == "m-org")
        #expect(store.repositories[2].owner == "z-org")
    }

    // MARK: - removeRepository

    @Test func removeRepositoryDeletesEntry() {
        let store = makeStore()
        store.addRepository(owner: "org", name: "repo")
        let repo = store.repositories[0]
        store.removeRepository(repo)
        #expect(store.repositories.isEmpty)
        #expect(store.statusMessage?.contains("org/repo") == true)
    }

    // MARK: - Hermes profiles

    @Test func saveCurrentHermesProfileCreatesNew() async {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.hermesModelID = "hermes-agent"
        await store.saveCurrentHermesProfile(named: "Dev")
        #expect(store.hermesProfiles.count == 1)
        #expect(store.hermesProfiles[0].name == "Dev")
        #expect(store.hermesProfiles[0].gatewayURL == "http://127.0.0.1:8642")
        #expect(store.selectedHermesProfileID == store.hermesProfiles[0].id)
        #expect(store.errorMessage == nil)
    }

    @Test func saveCurrentHermesProfileUpdatesExisting() async {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        await store.saveCurrentHermesProfile(named: "Dev")
        let originalID = store.hermesProfiles[0].id

        store.hermesGatewayURL = "http://127.0.0.1:9000"
        await store.saveCurrentHermesProfile(named: "Dev") // same name = update
        #expect(store.hermesProfiles.count == 1)
        #expect(store.hermesProfiles[0].id == originalID)
        #expect(store.hermesProfiles[0].gatewayURL == "http://127.0.0.1:9000")
    }

    @Test func saveCurrentHermesProfileRejectsEmptyName() async {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        await store.saveCurrentHermesProfile(named: "")
        #expect(store.hermesProfiles.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func saveCurrentHermesProfileRejectsEmptyURL() async {
        let store = makeStore()
        store.hermesGatewayURL = ""
        await store.saveCurrentHermesProfile(named: "Dev")
        #expect(store.hermesProfiles.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func selectHermesProfileAppliesURLAndModel() async throws {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.hermesModelID = "hermes-agent"
        await store.saveCurrentHermesProfile(named: "Local")

        store.hermesGatewayURL = "http://127.0.0.1:9000"
        store.hermesModelID = "hermes-pro"
        await store.saveCurrentHermesProfile(named: "Remote")

        let localID = try #require(store.hermesProfiles.first { $0.name == "Local" }?.id)
        store.selectHermesProfile(id: localID)

        #expect(store.hermesGatewayURL == "http://127.0.0.1:8642")
        #expect(store.hermesModelID == "hermes-agent")
        #expect(store.selectedHermesProfileID == localID)
        #expect(store.statusMessage == "Switched to Local.")
    }

    @Test func selectHermesProfileAppliesAPIKeyWhenPresentAndPreservesGlobalWhenNil() async throws {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.hermesAPIKey = ""
        await store.saveCurrentHermesProfile(named: "NoKeyProfile")
        let noKeyID = try #require(store.hermesProfiles.first { $0.name == "NoKeyProfile" }?.id)
        #expect(store.hermesProfiles.first { $0.id == noKeyID }?.apiKey == nil)

        store.hermesGatewayURL = "http://127.0.0.1:9000"
        store.hermesAPIKey = "profile-key"
        await store.saveCurrentHermesProfile(named: "KeyedProfile")
        let keyedID = try #require(store.hermesProfiles.first { $0.name == "KeyedProfile" }?.id)

        store.hermesAPIKey = "typed-before-switch"
        store.selectHermesProfile(id: keyedID)
        #expect(store.hermesAPIKey == "profile-key")

        store.hermesAPIKey = "carried-over-key"
        store.selectHermesProfile(id: noKeyID)
        #expect(store.hermesAPIKey == "carried-over-key")
    }

    @Test func saveCurrentHermesProfileAssignsPaletteColorWhenNilAndPreservesExistingColor() async throws {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        await store.saveCurrentHermesProfile(named: "Dev")
        let devID = try #require(store.hermesProfiles.first { $0.name == "Dev" }?.id)
        let assignedColor = try #require(store.hermesProfiles.first { $0.id == devID }?.colorHex)
        #expect(SettingsStore.hermesProfileColorPalette.contains(assignedColor))

        // Manually override, then re-save (e.g. after a gateway URL change) — the explicit color
        // must survive since saveCurrentHermesProfile only fills in a palette color when nil.
        if let index = store.hermesProfiles.firstIndex(where: { $0.id == devID }) {
            store.hermesProfiles[index].colorHex = "#123456"
        }
        store.hermesGatewayURL = "http://127.0.0.1:9999"
        await store.saveCurrentHermesProfile(named: "Dev")
        #expect(store.hermesProfiles.first { $0.id == devID }?.colorHex == "#123456")
    }

    @Test func bootstrapSilentlyAppliesSelectedHermesProfile() async throws {
        let repository = SettingsRepository(
            suiteName: "SettingsStoreTests-bootstrap-\(UUID().uuidString)",
            serviceName: "SettingsStoreTests-bootstrap-\(UUID().uuidString)"
        )
        let profile = HermesProfile(
            id: "local",
            name: "Local",
            gatewayURL: "http://127.0.0.1:8642",
            modelID: "hermes-local"
        )
        try await repository.saveSettings(AgentBoardSettings(
            hermesGatewayURL: "http://127.0.0.1:9000",
            hermesModelID: "hermes-fallback",
            hermesProfiles: [profile],
            selectedHermesProfileID: profile.id
        ))
        let store = SettingsStore(repository: repository)

        await store.bootstrap()

        #expect(store.hermesGatewayURL == profile.gatewayURL)
        #expect(store.hermesModelID == profile.modelID)
        #expect(store.selectedHermesProfileID == profile.id)
        #expect(store.statusMessage == "Settings loaded.")
    }

    @Test func removeHermesProfileDeletesIt() async {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        await store.saveCurrentHermesProfile(named: "Dev")
        let profile = store.hermesProfiles[0]

        await store.removeHermesProfile(profile)

        #expect(store.hermesProfiles.isEmpty)
        #expect(store.selectedHermesProfileID == nil)
    }

    @Test func removeHermesProfileAutoSelectsNext() async throws {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        await store.saveCurrentHermesProfile(named: "First")
        store.hermesGatewayURL = "http://127.0.0.1:9000"
        await store.saveCurrentHermesProfile(named: "Second")

        let firstProfile = try #require(store.hermesProfiles.first { $0.name == "First" })
        store.selectedHermesProfileID = firstProfile.id
        await store.removeHermesProfile(firstProfile)

        #expect(store.hermesProfiles.count == 1)
        #expect(store.selectedHermesProfileID != nil)
    }

    // MARK: - Per-profile Keychain secrets

    @Test func saveCurrentHermesProfileWritesSecretsToKeychainNotSnapshot() async throws {
        let (store, repository) = makeStoreWithRepository()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.hermesAPIKey = "profile-key"
        store.hermesDashboardPassword = "dash-pass"
        await store.saveCurrentHermesProfile(named: "Dev")
        let profileID = try #require(store.hermesProfiles.first?.id)

        let secrets = await repository.loadProfileSecrets(profileIDs: [profileID])
        #expect(secrets[profileID]?.apiKey == "profile-key")
        #expect(secrets[profileID]?.dashboardPassword == "dash-pass")

        let encoded = try JSONEncoder().encode(store.settingsSnapshot)
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(!json.contains("profile-key"))
        #expect(!json.contains("dash-pass"))
    }

    @Test func removeHermesProfileDeletesKeychainEntries() async throws {
        let (store, repository) = makeStoreWithRepository()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.hermesAPIKey = "profile-key"
        store.hermesDashboardPassword = "dash-pass"
        await store.saveCurrentHermesProfile(named: "Dev")
        let profile = try #require(store.hermesProfiles.first)

        let before = await repository.loadProfileSecrets(profileIDs: [profile.id])
        #expect(before[profile.id]?.apiKey == "profile-key")

        await store.removeHermesProfile(profile)

        let after = await repository.loadProfileSecrets(profileIDs: [profile.id])
        #expect(after[profile.id] == nil)
    }

    @Test func bootstrapMigratesLegacyInlineAPIKeyToKeychainAndDropsPlaintextFromSnapshot() async throws {
        let suiteName = "SettingsStoreTests-migration-\(UUID().uuidString)"
        let serviceName = "SettingsStoreTests-migration-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))

        // Seed a raw legacy snapshot blob, as if written by code that predates per-profile
        // Keychain secrets (HermesProfile.apiKey serialized inline in the JSON).
        let legacyJSON = """
        {
          "hermesGatewayURL": "http://127.0.0.1:8642",
          "hermesProfiles": [
            {
              "id": "legacy-profile",
              "name": "Legacy",
              "gatewayURL": "http://127.0.0.1:8642",
              "apiKey": "legacy-plaintext-key"
            }
          ],
          "selectedHermesProfileID": "legacy-profile"
        }
        """
        defaults.set(Data(legacyJSON.utf8), forKey: Self.legacySnapshotDefaultsKey)

        let repository = SettingsRepository(suiteName: suiteName, serviceName: serviceName)
        let store = SettingsStore(repository: repository)

        await store.bootstrap()

        #expect(store.hermesProfiles.first?.apiKey == "legacy-plaintext-key")

        let migratedSecrets = await repository.loadProfileSecrets(profileIDs: ["legacy-profile"])
        #expect(migratedSecrets["legacy-profile"]?.apiKey == "legacy-plaintext-key")

        let reSavedData = try #require(defaults.data(forKey: Self.legacySnapshotDefaultsKey))
        let reSavedJSON = try #require(String(data: reSavedData, encoding: .utf8))
        #expect(!reSavedJSON.contains("legacy-plaintext-key"))
    }

    // MARK: - availableHermesProfiles

    @Test func availableHermesProfilesReturnsVirtualProfileWhenNoneSaved() {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        let profiles = store.availableHermesProfiles
        #expect(profiles.count == 1)
        #expect(profiles[0].gatewayURL == "http://127.0.0.1:8642")
    }

    @Test func availableHermesProfilesReturnsSavedProfilesWhenPresent() async {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        await store.saveCurrentHermesProfile(named: "Prod")
        store.hermesGatewayURL = "http://127.0.0.1:9000"
        await store.saveCurrentHermesProfile(named: "Staging")

        #expect(store.availableHermesProfiles.count == 2)
    }

    // MARK: - isCompanionConfigured

    @Test func isCompanionConfiguredTrueWhenURLSet() {
        let store = makeStore()
        store.companionURL = "http://127.0.0.1:8742"
        #expect(store.isCompanionConfigured)
    }

    @Test func isCompanionConfiguredFalseWhenURLEmpty() {
        let store = makeStore()
        store.companionURL = ""
        #expect(!store.isCompanionConfigured)
    }

    @Test func isCompanionConfiguredFalseForLoopbackWhenRemoteHostRequired() {
        let store = makeStore(requiresRemoteCompanionHost: true)
        store.companionURL = "http://127.0.0.1:8742"
        #expect(!store.isCompanionConfigured)
        #expect(store.companionConfigurationMessage?.contains("LAN or Tailscale") == true)
    }

    @Test func isCompanionConfiguredTrueForLanHostWhenRemoteHostRequired() {
        let store = makeStore(requiresRemoteCompanionHost: true)
        store.companionURL = "http://192.168.1.40:8742"
        #expect(store.isCompanionConfigured)
        #expect(store.companionConfigurationMessage == nil)
    }

    @Test func isCompanionConfiguredFalseForMalformedURL() {
        let store = makeStore()
        store.companionURL = "not a url"
        #expect(!store.isCompanionConfigured)
        #expect(store.companionConfigurationMessage?.contains("valid companion URL") == true)
    }

    // MARK: - settingsSnapshot / secretsSnapshot

    @Test func settingsSnapshotEncodesRepos() {
        let store = makeStore()
        store.addRepository(owner: "org", name: "repo")
        store.autoRefreshInterval = 60
        let snapshot = store.settingsSnapshot
        #expect(snapshot.repositories.count == 1)
        #expect(snapshot.repositories[0].fullName == "org/repo")
        #expect(snapshot.autoRefreshInterval == 60)
    }

    @Test func settingsSnapshotEnforcesMinimumRefreshInterval() {
        let store = makeStore()
        store.autoRefreshInterval = 5 // below the 30s minimum
        let snapshot = store.settingsSnapshot
        #expect(snapshot.autoRefreshInterval >= 30)
    }

    @Test func secretsSnapshotTrimsEmptyValues() {
        let store = makeStore()
        store.hermesAPIKey = ""
        store.githubToken = "ghp_real"
        let snapshot = store.secretsSnapshot
        #expect(snapshot.hermesAPIKey == nil)
        #expect(snapshot.githubToken == "ghp_real")
    }
}
