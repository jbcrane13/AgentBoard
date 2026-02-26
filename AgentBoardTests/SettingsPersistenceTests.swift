import Foundation
import Testing
@testable import AgentBoard

@Suite("Settings Persistence Tests")
@MainActor
struct SettingsPersistenceTests {

    // MARK: - Config backup/restore helpers
    // All tests that mutate ~/.agentboard/config.json must backup before
    // and restore after, so they don't pollute the real user config.

    private var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agentboard", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    private func backupConfig() throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: configURL.path) else { return nil }
        let backup = configURL.deletingLastPathComponent()
            .appendingPathComponent("config.json.bak-\(UUID().uuidString)")
        try fm.copyItem(at: configURL, to: backup)
        return backup
    }

    private func restoreConfig(from backup: URL?) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: configURL.path) {
            try fm.removeItem(at: configURL)
        }
        if let backup {
            try fm.moveItem(at: backup, to: configURL)
        }
    }

    // MARK: - Gateway URL Persistence

    @Test("updateOpenClaw persists gateway URL to AppConfig")
    func updateOpenClawPersistsGatewayURL() throws {
        let backup = try backupConfig()
        defer { try? restoreConfig(from: backup) }

        let state = AppState()

        state.updateOpenClaw(
            gatewayURL: "http://192.168.1.100:18789",
            token: "",
            source: "manual"
        )

        #expect(state.appConfig.openClawGatewayURL == "http://192.168.1.100:18789")
        #expect(state.appConfig.gatewayConfigSource == "manual")
        #expect(state.statusMessage == "Saved OpenClaw settings.")

        let store = AppConfigStore(tokenStorage: InMemoryTokenStorage())
        let loaded = try store.loadOrCreate()
        #expect(loaded.openClawGatewayURL == "http://192.168.1.100:18789")
        #expect(loaded.gatewayConfigSource == "manual")
    }

    @Test("updateOpenClaw with empty gateway URL sets to nil")
    func updateOpenClawEmptyGatewaySetsNil() throws {
        let backup = try backupConfig()
        defer { try? restoreConfig(from: backup) }

        let state = AppState()

        state.updateOpenClaw(
            gatewayURL: "http://localhost:8080",
            token: "test-token",
            source: "manual"
        )
        state.updateOpenClaw(
            gatewayURL: "",
            token: "",
            source: "manual"
        )

        #expect(state.appConfig.openClawGatewayURL == nil)
        #expect(state.appConfig.openClawToken == nil)
    }

    // MARK: - Token Persistence (via Keychain)

    @Test("updateOpenClaw stores token in appConfig (migrated to Keychain by store)")
    func updateOpenClawTokenStored() throws {
        let backup = try backupConfig()
        defer { try? restoreConfig(from: backup) }

        let state = AppState()

        state.updateOpenClaw(
            gatewayURL: "http://localhost:18789",
            token: "my-secret-token",
            source: "manual"
        )

        #expect(state.appConfig.openClawToken == "my-secret-token")
        #expect(state.appConfig.gatewayConfigSource == "manual")
    }

    // MARK: - Manual Mode Toggle

    @Test("Manual mode toggle sets gatewayConfigSource to manual")
    func manualModeTogglePersists() throws {
        let backup = try backupConfig()
        defer { try? restoreConfig(from: backup) }

        let state = AppState()

        state.updateOpenClaw(
            gatewayURL: "http://localhost:18789",
            token: "",
            source: "manual"
        )

        #expect(state.appConfig.isGatewayManual == true)

        let store = AppConfigStore(tokenStorage: InMemoryTokenStorage())
        let loaded = try store.loadOrCreate()
        #expect(loaded.isGatewayManual == true)
    }

    @Test("Auto mode sets gatewayConfigSource to auto")
    func autoModePersists() throws {
        let backup = try backupConfig()
        defer { try? restoreConfig(from: backup) }

        let state = AppState()

        state.updateOpenClaw(
            gatewayURL: "",
            token: "",
            source: "auto"
        )

        #expect(state.appConfig.isGatewayManual == false)
        #expect(state.appConfig.gatewayConfigSource == "auto")
    }

    // MARK: - Config Reload Simulation

    @Test("Settings load on fresh AppState instance")
    func settingsLoadOnFreshInstance() throws {
        let backup = try backupConfig()
        defer { try? restoreConfig(from: backup) }

        let state1 = AppState()
        state1.updateOpenClaw(
            gatewayURL: "http://custom-host:9999",
            token: "test-token-abc",
            source: "manual"
        )

        let state2 = AppState()

        #expect(state2.appConfig.openClawGatewayURL == "http://custom-host:9999")
        #expect(state2.appConfig.gatewayConfigSource == "manual")
    }

    // MARK: - Projects Directory Persistence

    @Test("updateProjectsDirectory persists to config")
    func updateProjectsDirectoryPersists() throws {
        let backup = try backupConfig()
        defer { try? restoreConfig(from: backup) }

        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let state = AppState()
        state.updateProjectsDirectory(tempDir.path)

        #expect(state.appConfig.projectsDirectory == tempDir.path)
        #expect(state.statusMessage == "Projects directory updated.")

        let store = AppConfigStore(tokenStorage: InMemoryTokenStorage())
        let loaded = try store.loadOrCreate()
        #expect(loaded.projectsDirectory == tempDir.path)
    }

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ABSettingsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
