import AgentBoardCore
import Foundation
import Testing

/// Regression cover for a shipped bug: `AgentBoardAppModel` re-selected the
/// kanban backend only from `bootstrap()` and `saveSettingsAndReconnect()`, so
/// the three call sites that switch the active Hermes profile without saving
/// settings — the Settings "Use" button, the chat header profile menu, and
/// `ChatStore`'s conversation auto-switch — left the board reading a stale
/// backend until the app restarted.
///
/// The fix hangs re-selection off `SettingsStore.onActiveProfileChanged`, which
/// `selectHermesProfile(id:)` fires for every caller. Dashboard configuration
/// later became app-global (it's the kanban board's own server, not part of a
/// chat identity), so profile switches can no longer actually change the
/// backend — but the hook still fires for every caller since that's harmless,
/// and `AgentBoardAppModel.saveSettingsAndReconnect()` is what actually
/// re-points the backend when the app-global dashboard URL changes.
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

    private func profile(id: String, name: String) -> HermesProfile {
        HermesProfile(id: id, name: name, gatewayURL: "http://127.0.0.1:8641")
    }

    // MARK: - The hook fires for every caller

    @Test func selectingAProfileNotifiesTheActiveProfileObserver() {
        let store = makeStore()
        store.hermesProfiles = [
            profile(id: "local", name: "Local"),
            profile(id: "remote", name: "Remote")
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
        store.hermesProfiles = [profile(id: "local", name: "Local")]

        var notifications = 0
        store.onActiveProfileChanged = { notifications += 1 }

        store.selectHermesProfile(id: "does-not-exist")
        #expect(notifications == 0)
    }

    /// The chat header and the conversation auto-switch both pass `silent: true`
    /// or the default; neither suppresses the hook.
    @Test func silentSelectionStillNotifies() {
        let store = makeStore()
        store.hermesProfiles = [profile(id: "remote", name: "Remote")]

        var notifications = 0
        store.onActiveProfileChanged = { notifications += 1 }

        store.selectHermesProfile(id: "remote", silent: true)
        #expect(notifications == 1)
    }

    @Test func savingAProfileAlsoNotifies() async {
        let store = makeStore()
        store.hermesGatewayURL = "http://127.0.0.1:8641"

        var notifications = 0
        store.onActiveProfileChanged = { notifications += 1 }

        await store.saveCurrentHermesProfile(named: "Edited")
        #expect(notifications == 1)
    }

    // MARK: - Dashboard config is app-global: profile switches never change it

    /// Mirrors `AgentBoardAppModel.init`'s wiring, but re-derives the backend from the store's
    /// app-global dashboard fields rather than from whichever profile is active — which is the
    /// point: dashboard config no longer lives on `HermesProfile`.
    @Test func switchingProfilesNeverChangesTheAppGlobalDashboardBackend() {
        let store = makeStore()
        store.hermesProfiles = [
            profile(id: "local", name: "Local"),
            profile(id: "remote", name: "Remote")
        ]
        store.hermesDashboardURL = "http://100.120.154.96:9119"

        let agents = AgentsStore(
            kanbanData: KanbanDataService(databasePath: "/dev/null"),
            cache: NoopAgentBoardCache(),
            settingsStore: store
        )

        store.onActiveProfileChanged = { [weak store] in
            guard let store else { return }
            let (backend, writer, locality) = KanbanBackendFactory.makeBackend(
                dashboardURL: store.hermesDashboardURL,
                dashboardUsername: store.hermesDashboardUsername,
                dashboardPassword: store.hermesDashboardPassword
            )
            agents.updateBackend(backend, writer: writer, locality: locality)
        }

        store.selectHermesProfile(id: "remote")
        #expect(agents.backendLocality == .remote)

        store.selectHermesProfile(id: "local")
        #expect(
            agents.backendLocality == .remote,
            "the dashboard backend is app-global; switching profiles must not change it"
        )
    }
}
