import Foundation
import Security

private enum SettingsKeys {
    static let snapshot = "modern.agentboard.settings.snapshot"
}

private enum SecretKey: String, CaseIterable {
    case hermesAPIKey
    case githubToken
    case companionToken
}

private actor KeychainSecretStore {
    private let serviceName: String

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    func read(_ key: SecretKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
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

    func write(_ value: String?, for key: SecretKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
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
            githubToken: keychain.read(.githubToken),
            companionToken: keychain.read(.companionToken)
        )
    }

    public func saveSecrets(_ secrets: AgentBoardSecrets) async throws {
        try await keychain.write(secrets.hermesAPIKey, for: .hermesAPIKey)
        try await keychain.write(secrets.githubToken, for: .githubToken)
        try await keychain.write(secrets.companionToken, for: .companionToken)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
