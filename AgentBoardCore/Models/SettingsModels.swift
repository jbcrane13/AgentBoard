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
    public var companionURL: String
    public var repositories: [ConfiguredRepository]
    public var autoRefreshInterval: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case hermesGatewayURL
        case hermesModelID
        case hermesProfiles
        case selectedHermesProfileID
        case companionURL
        case repositories
        case autoRefreshInterval
    }

    public init(
        hermesGatewayURL: String = HermesGatewayConfiguration.defaultBaseURL,
        hermesModelID: String? = "hermes-agent",
        hermesProfiles: [HermesProfile]? = nil,
        selectedHermesProfileID: String? = nil,
        companionURL: String = "http://127.0.0.1:8742",
        repositories: [ConfiguredRepository] = [],
        autoRefreshInterval: TimeInterval = 30
    ) {
        self.hermesGatewayURL = hermesGatewayURL
        self.hermesModelID = hermesModelID
        self.hermesProfiles = hermesProfiles
        self.selectedHermesProfileID = selectedHermesProfileID
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
        companionURL = try container.decodeIfPresent(String.self, forKey: .companionURL)
            ?? "http://127.0.0.1:8742"
        repositories = try container.decodeIfPresent([ConfiguredRepository].self, forKey: .repositories) ?? []
        autoRefreshInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .autoRefreshInterval) ?? 30
    }
}

public struct AgentBoardSecrets: Codable, Equatable, Sendable {
    public var hermesAPIKey: String?
    public var githubToken: String?
    public var companionToken: String?

    public init(
        hermesAPIKey: String? = nil,
        githubToken: String? = nil,
        companionToken: String? = nil
    ) {
        self.hermesAPIKey = hermesAPIKey
        self.githubToken = githubToken
        self.companionToken = companionToken
    }
}

/// Keychain-backed secrets for a single `HermesProfile`, keyed by profile id. Never part of the
/// UserDefaults settings snapshot — see `SettingsRepository.loadProfileSecrets(profileIDs:)`.
public struct ProfileSecrets: Equatable, Sendable {
    public var apiKey: String?
    public var dashboardPassword: String?

    public init(apiKey: String? = nil, dashboardPassword: String? = nil) {
        self.apiKey = apiKey
        self.dashboardPassword = dashboardPassword
    }
}
