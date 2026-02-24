import Foundation
import Testing
@testable import AgentBoard

@Suite("Settings Persistence Tests")
@MainActor
struct SettingsPersistenceTests {

    // MARK: - Gateway URL Persistence

    @Test("updateOpenClaw persists gateway URL to AppConfig")
    func updateOpenClawPersistsGatewayURL() throws {
        let state = AppState()
        
        // Set gateway URL
        state.updateOpenClaw(
            gatewayURL: "http://192.168.1.100:18789",
            token: "",
            source: "manual"
        )
        
        // Verify in-memory state
        #expect(state.appConfig.openClawGatewayURL == "http://192.168.1.100:18789")
        #expect(state.appConfig.gatewayConfigSource == "manual")
        #expect(state.statusMessage == "Saved OpenClaw settings.")
        
        // Verify persistence via AppConfigStore
        let store = AppConfigStore(tokenStorage: InMemoryTokenStorage())
        let loaded = try store.loadOrCreate()
        #expect(loaded.openClawGatewayURL == "http://192.168.1.100:18789")
        #expect(loaded.gatewayConfigSource == "manual")
    }

    @Test("updateOpenClaw with empty gateway URL sets to nil")
    func updateOpenClawEmptyGatewaySetsNil() throws {
        let state = AppState()
        
        // First set a non-empty value
        state.updateOpenClaw(
            gatewayURL: "http://localhost:8080",
            token: "test-token",
            source: "manual"
        )
        
        // Then set to empty
        state.updateOpenClaw(
            gatewayURL: "",
            token: "",
            source: "manual"
        )
        
        // Verify nil
        #expect(state.appConfig.openClawGatewayURL == nil)
        #expect(state.appConfig.openClawToken == nil)
    }

    // MARK: - Token Persistence (via Keychain)

    @Test("updateOpenClaw stores token in appConfig (migrated to Keychain by store)")
    func updateOpenClawTokenStored() {
        let state = AppState()
        
        // Set token
        state.updateOpenClaw(
            gatewayURL: "http://localhost:18789",
            token: "my-secret-token",
            source: "manual"
        )
        
        // Token is stored but will be migrated to Keychain on next load
        #expect(state.appConfig.openClawToken == "my-secret-token")
        #expect(state.appConfig.gatewayConfigSource == "manual")
    }

    // MARK: - Manual Mode Toggle

    @Test("Manual mode toggle sets gatewayConfigSource to manual")
    func manualModeTogglePersists() throws {
        let state = AppState()
        
        // Set to manual mode
        state.updateOpenClaw(
            gatewayURL: "http://localhost:18789",
            token: "",
            source: "manual"
        )
        
        // Verify manual mode
        #expect(state.appConfig.isGatewayManual == true)
        
        // Verify persistence
        let store = AppConfigStore(tokenStorage: InMemoryTokenStorage())
        let loaded = try store.loadOrCreate()
        #expect(loaded.isGatewayManual == true)
    }

    @Test("Auto mode sets gatewayConfigSource to auto")
    func autoModePersists() throws {
        let state = AppState()
        
        // Set to auto mode
        state.updateOpenClaw(
            gatewayURL: "",
            token: "",
            source: "auto"
        )
        
        // Verify auto mode (not manual)
        #expect(state.appConfig.isGatewayManual == false)
        #expect(state.appConfig.gatewayConfigSource == "auto")
    }

    // MARK: - Config Reload Simulation

    @Test("Settings load on fresh AppState instance")
    func settingsLoadOnFreshInstance() throws {
        // First instance sets values
        let state1 = AppState()
        state1.updateOpenClaw(
            gatewayURL: "http://custom-host:9999",
            token: "test-token-abc",
            source: "manual"
        )
        
        // Simulate app relaunch by creating new AppState
        // Note: This tests that the config is persisted to disk
        let state2 = AppState()
        
        // Verify values were loaded from persisted config
        #expect(state2.appConfig.openClawGatewayURL == "http://custom-host:9999")
        #expect(state2.appConfig.gatewayConfigSource == "manual")
    }

    // MARK: - Projects Directory Persistence

    @Test("updateProjectsDirectory persists to config")
    func updateProjectsDirectoryPersists() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let state = AppState()
        state.updateProjectsDirectory(tempDir.path)
        
        // Verify in-memory state
        #expect(state.appConfig.projectsDirectory == tempDir.path)
        #expect(state.statusMessage == "Projects directory updated.")
        
        // Verify persistence
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
