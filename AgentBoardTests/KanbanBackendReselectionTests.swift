import AgentBoardCore
import Foundation
import Testing

/// Regression cover for a shipped bug: `AgentBoardAppModel` re-selected the
/// kanban backend only from `bootstrap()` and `saveSettingsAndReconnect()`, so
/// the three call sites that switch the active Hermes profile without saving
/// settings — the Settings "Use" button, the chat header profile menu, and
/// `ChatStore`'s conversation auto-switch — left the board reading the previous
/// profile's backend until the app restarted.
///
/// The fix hangs re-selection off `SettingsStore.onActiveProfileChanged`, which
/// `selectHermesProfile(id:)` fires for every caller. These tests pin that
/// contract rather than the individual call sites, since the whole point is
/// that a *new* caller cannot reintroduce the bug.
@Suite("Kanban backend re-selection", .serialized)
@MainActor
struct KanbanBackendReselectionTests {
    private func makeStore() -> SettingsStore {
        SettingsStore(
            repository: SettingsRepository(
                suiteName: "BackendReselect-\(UUID().uuidString)",
                serviceName: "BackendReselect-\(UUID().uuidString)"
            )
        )
    }

    private func profile(
        id: String,
        name: String,
        dashboardURL: String?
    ) -> HermesProfile {
        HermesProfile(
            id: id,
            name: name,
            gatewayURL: "http://127.0.0.1:8641",
            dashboardURL: dashboardURL,
            dashboardUsername: dashboardURL == nil ? nil : "admin",
            dashboardPassword: dashboardURL == nil ? nil : "pw"
        )
    }

    // MARK: - The hook fires for every caller

    @Test func selectingAProfileNotifiesTheActiveProfileObserver() {
        let store = makeStore()
        store.hermesProfiles = [
            profile(id: "local", name: "Local", dashboardURL: nil),
            profile(id: "remote", name: "Remote", dashboardURL: "http://100.120.154.96:9119")
        ]

        var notifications = 0
        store.onActiveProfileChanged = { notifications += 1 }

        store.selectHermesProfile(id: "remote")
        #expect(notifications == 1)

        store.selectHermesProfile(id: "local")
        #expect(notifications == 2)
    }

    @Test func selectingAnUnknownProfileDoesNotNotify() {
        let store = makeStore()
        store.hermesProfiles = [profile(id: "local", name: "Local", dashboardURL: nil)]

        var notifications = 0
        store.onActiveProfileChanged = { notifications += 1 }

        store.selectHermesProfile(id: "does-not-exist")
        #expect(notifications == 0)
    }

    /// The chat header and the conversation auto-switch both pass `silent: true`
    /// or the default; neither suppresses the hook.
    @Test func silentSelectionStillNotifies() {
        let store = makeStore()
        store.hermesProfiles = [profile(id: "remote", name: "Remote", dashboardURL: "http://100.64.1.2:9119")]

        var notifications = 0
        store.onActiveProfileChanged = { notifications += 1 }

        store.selectHermesProfile(id: "remote", silent: true)
        #expect(notifications == 1)
    }

    // MARK: - The hook actually re-points the backend

    @Test func switchingProfilesFlipsBackendLocalityWithoutSavingSettings() {
        let store = makeStore()
        store.hermesProfiles = [
            profile(id: "local", name: "Local", dashboardURL: nil),
            profile(id: "remote", name: "Remote", dashboardURL: "http://100.120.154.96:9119")
        ]

        let agents = AgentsStore(
            kanbanData: KanbanDataService(databasePath: "/dev/null"),
            cache: NoopAgentBoardCache(),
            settingsStore: store
        )

        // Mirrors AgentBoardAppModel.init's wiring.
        store.onActiveProfileChanged = { [weak store] in
            guard let store else { return }
            let active = store.activeHermesProfile
            let (backend, locality) = KanbanBackendFactory.makeBackend(
                dashboardURL: active?.dashboardURL,
                dashboardUsername: active?.dashboardUsername,
                dashboardPassword: active?.dashboardPassword
            )
            agents.updateBackend(backend, locality: locality)
        }

        #expect(agents.backendLocality == .local)

        store.selectHermesProfile(id: "remote")
        #expect(agents.backendLocality == .remote)

        store.selectHermesProfile(id: "local")
        #expect(agents.backendLocality == .local)
    }

    /// A profile pointing at a loopback dashboard still uses the local SQLite
    /// path — reading the file is cheaper than HTTP to the same machine.
    @Test func loopbackDashboardProfileStaysOnTheLocalBackend() {
        let store = makeStore()
        store.hermesProfiles = [profile(id: "loopback", name: "Loopback", dashboardURL: "http://127.0.0.1:9119")]

        var observed: KanbanBackendLocality?
        store.onActiveProfileChanged = { [weak store] in
            let active = store?.activeHermesProfile
            observed = KanbanBackendFactory.makeBackend(
                dashboardURL: active?.dashboardURL,
                dashboardUsername: active?.dashboardUsername,
                dashboardPassword: active?.dashboardPassword
            ).locality
        }

        store.selectHermesProfile(id: "loopback")
        #expect(observed == .local)
    }
}
