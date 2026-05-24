import AgentBoardCore
import Foundation
import Testing

@Suite("ConfigBackupService", .serialized)
@MainActor
struct ConfigBackupServiceTests {
    private func makeService() -> (ConfigBackupService, SettingsStore, SettingsRepository) {
        let repo = SettingsRepository(
            suiteName: "ConfigBackupTests-\(UUID().uuidString)",
            serviceName: "ConfigBackupTests-\(UUID().uuidString)"
        )
        let settingsStore = SettingsStore(repository: repo)
        let service = ConfigBackupService(settingsStore: settingsStore, repository: repo)
        return (service, settingsStore, repo)
    }

    // MARK: - Export / Import round-trip

    @Test func exportImportRoundTrip() async throws {
        let (service, settingsStore, _) = makeService()
        settingsStore.hermesGatewayURL = "http://127.0.0.1:9999"
        settingsStore.hermesModelID = "hermes-pro"
        settingsStore.addRepository(owner: "jbcrane13", name: "AgentBoard")

        let data = try await service.exportBackupData()
        #expect(!data.isEmpty)

        let imported = try service.importBackupData(data)
        #expect(imported.version == 1)
        #expect(imported.settings.hermesGatewayURL == "http://127.0.0.1:9999")
        #expect(imported.settings.repositories.count == 1)
        #expect(imported.settings.repositories[0].fullName == "jbcrane13/AgentBoard")
    }

    @Test func exportedDataIsValidJSON() async throws {
        let (service, _, _) = makeService()
        let data = try await service.exportBackupData()
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test func exportedFileHasTimestampedName() async throws {
        let (service, _, _) = makeService()
        let url = try await service.exportBackupToFile()
        #expect(url.lastPathComponent.hasPrefix("agentboard-backup-"))
        #expect(url.pathExtension == "json")
        // Clean up
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - validateBackup

    @Test func validateBackupProducesSummary() async throws {
        let (service, settingsStore, _) = makeService()
        settingsStore.addRepository(owner: "org", name: "repo")
        settingsStore.hermesGatewayURL = "http://127.0.0.1:8642"
        do {
            settingsStore.saveCurrentHermesProfile(named: "Dev")
        }

        let data = try await service.exportBackupData()
        let summary = try service.validateBackup(data)

        #expect(summary.version == 1)
        #expect(summary.repositoryCount == 1)
        #expect(summary.hermesProfileCount == 1)
    }

    @Test func validateBackupRejectsGarbledData() {
        let (service, _, _) = makeService()
        let garbage = Data("not json at all".utf8)
        #expect(throws: (any Error).self) {
            try service.validateBackup(garbage)
        }
    }

    // MARK: - BackupSummary.description

    @Test func backupSummaryDescriptionIncludesRepoCount() async throws {
        let (service, settingsStore, _) = makeService()
        settingsStore.addRepository(owner: "org", name: "repo")
        let data = try await service.exportBackupData()
        let summary = try service.validateBackup(data)
        #expect(summary.description.contains("1 repository"))
    }

    @Test func backupSummaryDescriptionIncludesSecrets() throws {
        let (service, _, repo) = makeService()
        // Directly save a backup that has an API key
        let settings = AgentBoardSettings(
            hermesGatewayURL: "http://127.0.0.1:8642",
            repositories: []
        )
        let secrets = AgentBoardSecrets(
            hermesAPIKey: "key-abc",
            githubToken: "ghp-abc"
        )
        let backup = AgentBoardBackup(settings: settings, secrets: secrets)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let summary = try service.validateBackup(data)
        #expect(summary.hasHermesAPIKey)
        #expect(summary.hasGitHubToken)
        #expect(!summary.hasCompanionToken)
        #expect(summary.description.contains("Hermes API key"))
        #expect(summary.description.contains("GitHub token"))
    }

    // MARK: - restoreFromBackup

    @Test func restoreFromBackupAppliesSettings() async throws {
        let (service, settingsStore, _) = makeService()
        let settings = AgentBoardSettings(
            hermesGatewayURL: "http://restored-host:8642",
            repositories: [ConfiguredRepository(owner: "restored", name: "repo")]
        )
        let backup = AgentBoardBackup(settings: settings, secrets: AgentBoardSecrets())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        try await service.restoreFromBackup(data)

        #expect(settingsStore.hermesGatewayURL == "http://restored-host:8642")
        #expect(settingsStore.repositories.count == 1)
        #expect(settingsStore.repositories[0].fullName == "restored/repo")
    }

    @Test func restoreFromBackupRejectsUnsupportedVersion() async throws {
        let (service, _, _) = makeService()
        let badVersion = """
        {
            "version": 0,
            "exportedAt": "2026-04-01T00:00:00Z",
            "settings": {"hermesGatewayURL": "http://127.0.0.1:8642", "companionURL": "http://127.0.0.1:8742", "repositories": [], "autoRefreshInterval": 30, "designTheme": "blue"},
            "secrets": {}
        }
        """
        await #expect(throws: (any Error).self) {
            try await service.restoreFromBackup(Data(badVersion.utf8))
        }
    }
}
