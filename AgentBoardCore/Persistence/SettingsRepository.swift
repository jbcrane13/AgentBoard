import Foundation
import Security

private enum SettingsKeys {
    static let snapshot = "modern.agentboard.settings.snapshot"
}

private enum SecretKey: String, CaseIterable {
    case hermesAPIKey
    case dashboardPassword
    case githubToken
    case companionToken
}

private actor KeychainSecretStore {
    private let serviceName: String

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    func read(_ key: SecretKey) -> String? {
        read(account: key.rawValue)
    }

    func write(_ value: String?, for key: SecretKey) throws {
        try write(value, account: key.rawValue)
    }

    /// Reads an arbitrary Keychain account under this store's service, used for per-profile
    /// secrets whose account name is derived from a `HermesProfile.id` rather than a fixed
    /// `SecretKey`.
    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String?, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        if let value, !value.isEmpty {
            let encoded = Data(value.utf8)
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: encoded] as CFDictionary
            )
            if updateStatus == errSecItemNotFound {
                let createStatus = SecItemAdd(
                    query.merging([kSecValueData as String: encoded], uniquingKeysWith: { _, new in new })
                        as CFDictionary,
                    nil
                )
                guard createStatus == errSecSuccess else {
                    throw NSError(
                        domain: NSOSStatusErrorDomain,
                        code: Int(createStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Unable to write secure value."]
                    )
                }
            } else if updateStatus != errSecSuccess {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(updateStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Unable to update secure value."]
                )
            }
        } else {
            SecItemDelete(query as CFDictionary)
        }
    }

    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Derives stable Keychain account names for per-profile secrets from a `HermesProfile.id`.
private enum ProfileSecretAccount {
    static func apiKey(profileID: String) -> String {
        "hermesProfile.\(profileID).apiKey"
    }
}

public actor SettingsRepository {
    private let defaults: UserDefaults
    private let keychain: KeychainSecretStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        serviceName: String = "com.agentboard.modern"
    ) {
        self.defaults = defaults
        keychain = KeychainSecretStore(serviceName: serviceName)
        encoder = Self.makeEncoder()
        decoder = JSONDecoder()
    }

    public init(
        suiteName: String,
        serviceName: String = "com.agentboard.modern"
    ) {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
        keychain = KeychainSecretStore(serviceName: serviceName)
        encoder = Self.makeEncoder()
        decoder = JSONDecoder()
    }

    public func loadSettings() -> AgentBoardSettings {
        guard let data = defaults.data(forKey: SettingsKeys.snapshot),
              let decoded = try? decoder.decode(AgentBoardSettings.self, from: data) else {
            return AgentBoardSettings()
        }
        return decoded
    }

    public func saveSettings(_ settings: AgentBoardSettings) throws {
        let encoded = try encoder.encode(settings)
        defaults.set(encoded, forKey: SettingsKeys.snapshot)
    }

    public func loadSecrets() async -> AgentBoardSecrets {
        await AgentBoardSecrets(
            hermesAPIKey: keychain.read(.hermesAPIKey),
            dashboardPassword: keychain.read(.dashboardPassword),
            githubToken: keychain.read(.githubToken),
            companionToken: keychain.read(.companionToken)
        )
    }

    public func saveSecrets(_ secrets: AgentBoardSecrets) async throws {
        try await keychain.write(secrets.hermesAPIKey, for: .hermesAPIKey)
        try await keychain.write(secrets.dashboardPassword, for: .dashboardPassword)
        try await keychain.write(secrets.githubToken, for: .githubToken)
        try await keychain.write(secrets.companionToken, for: .companionToken)
    }

    /// Loads the Keychain-backed API key for each given profile id. Profiles with no key stored
    /// are omitted from the result.
    public func loadProfileSecrets(profileIDs: [String]) async -> [String: ProfileSecrets] {
        var result: [String: ProfileSecrets] = [:]
        for profileID in profileIDs {
            let apiKey = await keychain.read(account: ProfileSecretAccount.apiKey(profileID: profileID))
            if let apiKey {
                result[profileID] = ProfileSecrets(apiKey: apiKey)
            }
        }
        return result
    }

    /// Writes a profile's Keychain-backed API key. A `nil`/empty value deletes the entry.
    public func saveProfileSecrets(_ secrets: ProfileSecrets, for profileID: String) async throws {
        try await keychain.write(secrets.apiKey, account: ProfileSecretAccount.apiKey(profileID: profileID))
    }

    /// Deletes a profile's Keychain-backed API key, e.g. when the profile itself is removed.
    public func deleteProfileSecrets(for profileID: String) async {
        await keychain.delete(account: ProfileSecretAccount.apiKey(profileID: profileID))
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
