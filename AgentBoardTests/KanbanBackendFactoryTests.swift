@testable import AgentBoardCore
import Foundation
import Testing

/// Contract tests for `KanbanBackendFactory` — the local/remote kanban
/// backend selector wired into `AgentBoardAppModel`. These deliberately
/// guard against reusing `ChatEndpointValidator.isLocalOrPrivateHost`, which
/// classifies Tailscale/RFC1918 hosts as "private" — exactly the hosts this
/// factory must route over HTTP rather than treat as local.
@Suite("KanbanBackendFactory")
struct KanbanBackendFactoryTests {
    // MARK: - Loopback classification

    @Test(arguments: ["127.0.0.1", "localhost", "LOCALHOST", "::1", "127.0.0.2"])
    func isLoopbackHostAcceptsLoopbackAddresses(_ host: String) {
        #expect(KanbanBackendFactory.isLoopbackHost(host))
    }

    @Test(arguments: ["100.120.154.96", "192.168.2.63", "hermes.example.com", "10.0.0.5"])
    func isLoopbackHostRejectsTailscalePrivateAndPublicHosts(_ host: String) {
        #expect(!KanbanBackendFactory.isLoopbackHost(host))
    }

    // MARK: - Backend selection

    @Test
    func noDashboardURLSelectsLocalSQLiteBackend() {
        let (backend, _, locality) = KanbanBackendFactory.makeBackend(
            dashboardURL: nil,
            dashboardUsername: nil,
            dashboardPassword: nil
        )
        #expect(locality == .local)
        #expect(backend is KanbanDataService)
    }

    @Test
    func blankDashboardURLSelectsLocalSQLiteBackend() {
        let (backend, _, locality) = KanbanBackendFactory.makeBackend(
            dashboardURL: "   ",
            dashboardUsername: nil,
            dashboardPassword: nil
        )
        #expect(locality == .local)
        #expect(backend is KanbanDataService)
    }

    @Test
    func loopbackDashboardURLSelectsLocalSQLiteBackend() {
        let (backend, _, locality) = KanbanBackendFactory.makeBackend(
            dashboardURL: "http://127.0.0.1:9119",
            dashboardUsername: "admin",
            dashboardPassword: "secret"
        )
        #expect(locality == .local)
        #expect(backend is KanbanDataService)
    }

    @Test
    func tailscaleDashboardURLSelectsHTTPBackend() {
        let (backend, _, locality) = KanbanBackendFactory.makeBackend(
            dashboardURL: "http://100.120.154.96:9119",
            dashboardUsername: nil,
            dashboardPassword: nil
        )
        #expect(locality == .remote)
        #expect(backend is HTTPKanbanBackend)
    }

    // MARK: - Writer locality (issue #207 — read/write locality must never drift)

    @Test
    func localBranchSelectsLocalCLIWriter() {
        let (_, writer, _) = KanbanBackendFactory.makeBackend(
            dashboardURL: nil,
            dashboardUsername: nil,
            dashboardPassword: nil
        )
        #expect(writer is KanbanCLIWriter)
    }

    @Test
    func tailscaleDashboardURLSelectsHTTPWriter() {
        let (_, writer, _) = KanbanBackendFactory.makeBackend(
            dashboardURL: "http://100.120.154.96:9119",
            dashboardUsername: nil,
            dashboardPassword: nil
        )
        #expect(writer is HTTPKanbanWriter)
    }

    // MARK: - Credential pairing

    @Test
    func makeCredentialsPairsUsernameAndPassword() {
        let credentials = KanbanBackendFactory.makeCredentials(username: "admin", password: "hunter2")
        #expect(credentials?.username == "admin")
        #expect(credentials?.password == "hunter2")
    }

    @Test
    func makeCredentialsReturnsNilWhenPasswordMissing() {
        #expect(KanbanBackendFactory.makeCredentials(username: "admin", password: nil) == nil)
        #expect(KanbanBackendFactory.makeCredentials(username: "admin", password: "  ") == nil)
    }

    @Test
    func makeCredentialsReturnsNilWhenUsernameMissing() {
        #expect(KanbanBackendFactory.makeCredentials(username: nil, password: "hunter2") == nil)
    }
}
