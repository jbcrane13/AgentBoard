import Foundation

/// Where the active kanban backend reads from — drives both which
/// `KanbanDataReading` conformer `AgentsStore` uses and how aggressively its
/// live-update poll runs (`AgentsStore`'s local vs. remote poll cadence).
public enum KanbanBackendLocality: Sendable, Equatable {
    case local
    case remote
}

/// Selects the `KanbanDataReading` backend for a Hermes profile's dashboard
/// configuration: local SQLite (`KanbanDataService`, reading
/// `~/.hermes/kanban.db` directly) when there's no configured dashboard URL
/// or that URL's host is loopback (same machine — reading the file directly
/// is cheaper than a network round trip); the dashboard's HTTP API
/// (`HTTPKanbanBackend`) otherwise.
public enum KanbanBackendFactory {
    /// - Parameters:
    ///   - dashboardURL: e.g. `http://100.120.154.96:9119`. `nil`, empty, or
    ///     unparseable -> local SQLite.
    ///   - dashboardUsername: paired with `dashboardPassword` for gated
    ///     remote dashboards. Either present without the other yields no
    ///     credentials (the client then only works against an ungated or
    ///     unauthenticated host).
    ///   - dashboardPassword: Keychain-backed on the caller's side, never
    ///     persisted to disk with the rest of the profile.
    public static func makeBackend(
        dashboardURL: String?,
        dashboardUsername: String?,
        dashboardPassword: String?
    ) -> (backend: any KanbanDataReading, locality: KanbanBackendLocality) {
        guard let rawURL = dashboardURL?.trimmedOrNil,
              let url = URL(string: rawURL),
              let host = url.host else {
            return (KanbanDataService(), .local)
        }

        guard !isLoopbackHost(host) else {
            return (KanbanDataService(), .local)
        }

        let credentials = makeCredentials(username: dashboardUsername, password: dashboardPassword)
        let client = HermesDashboardClient(baseURL: url, credentials: credentials)
        return (HTTPKanbanBackend(client: client), .remote)
    }

    /// Pulled out of `makeBackend` as a pure function so credential pairing
    /// (both present, or neither used) is directly testable without
    /// reaching into `HermesDashboardClient`'s private auth state.
    public static func makeCredentials(
        username: String?,
        password: String?
    ) -> HermesDashboardClient.Credentials? {
        guard let username = username?.trimmedOrNil, let password = password?.trimmedOrNil else { return nil }
        return HermesDashboardClient.Credentials(username: username, password: password)
    }

    /// Narrow loopback-only check for backend selection — deliberately
    /// **not** `ChatEndpointValidator.isLocalOrPrivateHost`, which also
    /// classifies RFC1918 and the Tailscale `100.64.0.0/10` CGNAT range as
    /// "private". Those ranges are exactly the remote hosts this factory
    /// needs to route over HTTP (a Tailscale-reachable Hermes host has no
    /// local `~/.hermes/kanban.db` on this machine), so reusing that helper
    /// here would silently misroute them to the local SQLite path.
    public static func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        return normalized == "localhost" || normalized == "::1" || normalized.hasPrefix("127.")
    }
}
