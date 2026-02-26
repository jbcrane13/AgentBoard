import Foundation
import Testing
@testable import AgentBoard

@Suite("Settings Persistence Tests")
@MainActor
struct SettingsPersistenceTests {

    // Each test gets its own temp directory — never touches ~/.agentboard/
    private func makeTempStore() throws -> (AppConfigStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ABSettingsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (AppConfigStore(directory: dir), dir)
    }

    // MARK: - Gateway URL Persistence

    @Test("updateOpenClaw persists gateway URL to AppConfig")
    func updateOpenClawPersistsGatewayURL() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let state = AppState(configStore: store)

        state.updateOpenClaw(
            gatewayURL: "http://192.168.1.100:18789",
            token: "",
            source: "manual"
        )

        #expect(state.appConfig.openClawGatewayURL == "http://192.168.1.100:18789")
        #expect(state.appConfig.gatewayConfigSource == "manual")
        #expect(state.statusMessage == "Saved OpenClaw settings.")

        let freshStore = AppConfigStore(directory: dir)
        let loaded = try freshStore.loadOrCreate()
        #expect(loaded.openClawGatewayURL == "http://192.168.1.100:18789")
        #expect(loaded.gatewayConfigSource == "manual")
    }

    @Test("updateOpenClaw with empty gateway URL sets to nil")
    func updateOpenClawEmptyGatewaySetsNil() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let state = AppState(configStore: store)

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

    // MARK: - Token Persistence

    @Test("updateOpenClaw stores token in appConfig")
    func updateOpenClawTokenStored() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let state = AppState(configStore: store)

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
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let state = AppState(configStore: store)

        state.updateOpenClaw(
            gatewayURL: "http://localhost:18789",
            token: "",
            source: "manual"
        )

        #expect(state.appConfig.isGatewayManual == true)

        let freshStore = AppConfigStore(directory: dir)
        let loaded = try freshStore.loadOrCreate()
        #expect(loaded.isGatewayManual == true)
    }

    @Test("Auto mode sets gatewayConfigSource to auto")
    func autoModePersists() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let state = AppState(configStore: store)

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
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let state1 = AppState(configStore: store)
        state1.updateOpenClaw(
            gatewayURL: "http://custom-host:9999",
            token: "test-token-abc",
            source: "manual"
        )

        let state2 = AppState(configStore: AppConfigStore(directory: dir))

        #expect(state2.appConfig.openClawGatewayURL == "http://custom-host:9999")
        #expect(state2.appConfig.gatewayConfigSource == "manual")
    }

    // MARK: - Projects Directory Persistence

    @Test("updateProjectsDirectory persists to config")
    func updateProjectsDirectoryPersists() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let tempProjects = FileManager.default.temporaryDirectory
            .appendingPathComponent("ABProjects-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempProjects, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempProjects) }

        let state = AppState(configStore: store)
        state.updateProjectsDirectory(tempProjects.path)

        #expect(state.appConfig.projectsDirectory == tempProjects.path)
        #expect(state.statusMessage == "Projects directory updated.")

        let freshStore = AppConfigStore(directory: dir)
        let loaded = try freshStore.loadOrCreate()
        #expect(loaded.projectsDirectory == tempProjects.path)
    }
}
