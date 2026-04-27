import AgentBoardCore
import Foundation
import Testing

@Suite("SettingsStore", .serialized)
@MainActor
struct SettingsStoreTests {
    private func makeStore() -> SettingsStore {
        let repo = SettingsRepository(
            suiteName: "SettingsStoreTests-\(UUID().uuidString)",
            serviceName: "SettingsStoreTests-\(UUID().uuidString)"
        )
        return SettingsStore(repository: repo)
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

    @Test func saveCurrentHermesProfileCreatesNew() {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.hermesModelID = "hermes-agent"
        store.saveCurrentHermesProfile(named: "Dev")
        #expect(store.hermesProfiles.count == 1)
        #expect(store.hermesProfiles[0].name == "Dev")
        #expect(store.hermesProfiles[0].gatewayURL == "http://127.0.0.1:8642")
        #expect(store.selectedHermesProfileID == store.hermesProfiles[0].id)
        #expect(store.errorMessage == nil)
    }

    @Test func saveCurrentHermesProfileUpdatesExisting() {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.saveCurrentHermesProfile(named: "Dev")
        let originalID = store.hermesProfiles[0].id

        store.hermesGatewayURL = "http://127.0.0.1:9000"
        store.saveCurrentHermesProfile(named: "Dev") // same name = update
        #expect(store.hermesProfiles.count == 1)
        #expect(store.hermesProfiles[0].id == originalID)
        #expect(store.hermesProfiles[0].gatewayURL == "http://127.0.0.1:9000")
    }

    @Test func saveCurrentHermesProfileRejectsEmptyName() {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.saveCurrentHermesProfile(named: "")
        #expect(store.hermesProfiles.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func saveCurrentHermesProfileRejectsEmptyURL() {
        let store = makeStore()
        store.hermesGatewayURL = ""
        store.saveCurrentHermesProfile(named: "Dev")
        #expect(store.hermesProfiles.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func selectHermesProfileAppliesURLAndModel() throws {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.hermesModelID = "hermes-agent"
        store.saveCurrentHermesProfile(named: "Local")

        store.hermesGatewayURL = "http://127.0.0.1:9000"
        store.hermesModelID = "hermes-pro"
        store.saveCurrentHermesProfile(named: "Remote")

        let localID = try #require(store.hermesProfiles.first { $0.name == "Local" }?.id)
        store.selectHermesProfile(id: localID)

        #expect(store.hermesGatewayURL == "http://127.0.0.1:8642")
        #expect(store.hermesModelID == "hermes-agent")
        #expect(store.selectedHermesProfileID == localID)
    }

    @Test func removeHermesProfileDeletesIt() {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.saveCurrentHermesProfile(named: "Dev")
        let profile = store.hermesProfiles[0]

        store.removeHermesProfile(profile)

        #expect(store.hermesProfiles.isEmpty)
        #expect(store.selectedHermesProfileID == nil)
    }

    @Test func removeHermesProfileAutoSelectsNext() throws {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.saveCurrentHermesProfile(named: "First")
        store.hermesGatewayURL = "http://127.0.0.1:9000"
        store.saveCurrentHermesProfile(named: "Second")

        let firstProfile = try #require(store.hermesProfiles.first { $0.name == "First" })
        store.selectedHermesProfileID = firstProfile.id
        store.removeHermesProfile(firstProfile)

        #expect(store.hermesProfiles.count == 1)
        #expect(store.selectedHermesProfileID != nil)
    }

    // MARK: - availableHermesProfiles

    @Test func availableHermesProfilesReturnsVirtualProfileWhenNoneSaved() {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        let profiles = store.availableHermesProfiles
        #expect(profiles.count == 1)
        #expect(profiles[0].gatewayURL == "http://127.0.0.1:8642")
    }

    @Test func availableHermesProfilesReturnsSavedProfilesWhenPresent() {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8642"
        store.saveCurrentHermesProfile(named: "Prod")
        store.hermesGatewayURL = "http://127.0.0.1:9000"
        store.saveCurrentHermesProfile(named: "Staging")

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
