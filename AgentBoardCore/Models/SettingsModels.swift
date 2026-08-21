import Foundation

/// Persisted settings snapshot and the secrets that deliberately do **not**
/// live in it. `AgentBoardSettings` is encoded into UserDefaults; anything
/// secret belongs in `AgentBoardSecrets` / `ProfileSecrets`, which are stored
/// in the Keychain by `SettingsRepository`.

public struct AgentBoardSettings: Codable, Hashable, Sendable {
    public var hermesGatewayURL: String
    public var hermesModelID: String?
    public var hermesProfiles: [HermesProfile]?
    public var selectedHermesProfileID: String?
    /// App-global dashboard base URL (`http://<host>:9119`) used to drive the remote kanban
    /// board. Leaving this empty keeps kanban reads on the local `~/.hermes/kanban.db`. This is
    /// distinct from any `HermesProfile` — the dashboard is the kanban board's own server, not
    /// part of a chat identity.
    public var dashboardURL: String?
    /// Dashboard Basic-auth username, paired with `AgentBoardSecrets.dashboardPassword`.
    public var dashboardUsername: String?
    public var companionURL: String
    public var repositories: [ConfiguredRepository]
    public var autoRefreshInterval: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case hermesGatewayURL
        case hermesModelID
        case hermesProfiles
        case selectedHermesProfileID
        case dashboardURL
        case dashboardUsername
        case companionURL
        case repositories
        case autoRefreshInterval
    }

    public init(
        hermesGatewayURL: String = HermesGatewayConfiguration.defaultBaseURL,
        hermesModelID: String? = "hermes-agent",
        hermesProfiles: [HermesProfile]? = nil,
        selectedHermesProfileID: String? = nil,
        dashboardURL: String? = nil,
        dashboardUsername: String? = nil,
        companionURL: String = "http://127.0.0.1:8742",
        repositories: [ConfiguredRepository] = [],
        autoRefreshInterval: TimeInterval = 30
    ) {
        self.hermesGatewayURL = hermesGatewayURL
        self.hermesModelID = hermesModelID
        self.hermesProfiles = hermesProfiles
        self.selectedHermesProfileID = selectedHermesProfileID
        self.dashboardURL = dashboardURL
        self.dashboardUsername = dashboardUsername
        self.companionURL = companionURL
        self.repositories = repositories
        self.autoRefreshInterval = autoRefreshInterval
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hermesGatewayURL = try container.decodeIfPresent(String.self, forKey: .hermesGatewayURL)
            ?? HermesGatewayConfiguration.defaultBaseURL
        hermesModelID = try container.decodeIfPresent(String.self, forKey: .hermesModelID)
        hermesProfiles = try container.decodeIfPresent([HermesProfile].self, forKey: .hermesProfiles)
        selectedHermesProfileID = try container.decodeIfPresent(String.self, forKey: .selectedHermesProfileID)
        // Absent from snapshots persisted before dashboard config became app-global.
        dashboardURL = try container.decodeIfPresent(String.self, forKey: .dashboardURL)
        dashboardUsername = try container.decodeIfPresent(String.self, forKey: .dashboardUsername)
        companionURL = try container.decodeIfPresent(String.self, forKey: .companionURL)
            ?? "http://127.0.0.1:8742"
        repositories = try container.decodeIfPresent([ConfiguredRepository].self, forKey: .repositories) ?? []
        autoRefreshInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .autoRefreshInterval) ?? 30
    }
}

public struct AgentBoardSecrets: Codable, Equatable, Sendable {
    public var hermesAPIKey: String?
    /// App-global dashboard Basic-auth password, paired with `AgentBoardSettings.dashboardUsername`.
    public var dashboardPassword: String?
    public var githubToken: String?
    public var companionToken: String?

    public init(
        hermesAPIKey: String? = nil,
        dashboardPassword: String? = nil,
        githubToken: String? = nil,
        companionToken: String? = nil
    ) {
        self.hermesAPIKey = hermesAPIKey
        self.dashboardPassword = dashboardPassword
        self.githubToken = githubToken
        self.companionToken = companionToken
    }
}

/// Keychain-backed secrets for a single `HermesProfile`, keyed by profile id. Never part of the
/// UserDefaults settings snapshot — see `SettingsRepository.loadProfileSecrets(profileIDs:)`.
public struct ProfileSecrets: Equatable, Sendable {
    public var apiKey: String?

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }
}
