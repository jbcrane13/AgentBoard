import Foundation
import Security

// MARK: - Protocol

/// Abstraction over token storage — swap for InMemoryTokenStorage in tests.
protocol TokenStorage: Sendable {
    func saveToken(_ token: String) throws
    func loadToken() -> String?
    func deleteToken()
}

// MARK: - Real Keychain implementation

/// Stores and retrieves the gateway auth token in the macOS Keychain.
enum KeychainService {
    private static let service = "com.agentboard.gateway"
    private static let account = "gateway-token"

    static func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { return }

        // Try update first, then add
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let update: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandled(updateStatus)
            }
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(addStatus)
            }
        }
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

}

// MARK: - KeychainTokenStorage (TokenStorage conformance wrapping static KeychainService)

/// Production token storage backed by macOS Keychain.
/// Inject this in the app; use InMemoryTokenStorage in tests.
struct KeychainTokenStorage: TokenStorage {
    func saveToken(_ token: String) throws { try KeychainService.saveToken(token) }
    func loadToken() -> String? { KeychainService.loadToken() }
    func deleteToken() { KeychainService.deleteToken() }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            if let message = SecCopyErrorMessageString(status, nil) {
                return message as String
            }
            return "Keychain error: \(status)"
        }
    }
}
