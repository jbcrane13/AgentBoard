import Foundation
import Testing
@testable import AgentBoard

// MARK: - Always-on (no real Keychain access)

@Suite("KeychainError Tests")
struct KeychainErrorTests {
    @Test("KeychainError unhandled errorDescription is non-nil and non-empty")
    func keychainErrorDescriptionIsNonEmpty() {
        let error = KeychainError.unhandled(OSStatus(-25300))
        let description = error.errorDescription
        #expect(description != nil)
        if let description {
            #expect(!description.isEmpty)
        }
    }
}

// MARK: - Real Keychain (set KEYCHAIN_TESTS_ENABLED=1 to run; skipped in unattended mode)

private let keychainTestsEnabled = ProcessInfo.processInfo.environment["KEYCHAIN_TESTS_ENABLED"] == "1"

@Suite("KeychainService Tests", .enabled(if: keychainTestsEnabled,
       "Requires real Keychain access — triggers macOS permission dialog; set KEYCHAIN_TESTS_ENABLED=1 to run"))
struct KeychainServiceTests {
    init() {
        KeychainService.deleteToken()
    }

    @Test("save and load token round trip")
    func saveAndLoadTokenRoundTrip() throws {
        defer { KeychainService.deleteToken() }
        try KeychainService.saveToken("test-secret-token")
        let loaded = KeychainService.loadToken()
        #expect(loaded == "test-secret-token")
    }

    @Test("saving token twice updates the stored value")
    func saveTokenTwiceUpdatesValue() throws {
        defer { KeychainService.deleteToken() }
        try KeychainService.saveToken("first-token")
        try KeychainService.saveToken("second-token")
        let loaded = KeychainService.loadToken()
        #expect(loaded == "second-token")
    }

    @Test("delete token then load returns nil")
    func deleteTokenThenLoadReturnsNil() throws {
        defer { KeychainService.deleteToken() }
        try KeychainService.saveToken("ephemeral-token")
        KeychainService.deleteToken()
        let loaded = KeychainService.loadToken()
        #expect(loaded == nil)
    }

    @Test("load token with no prior save returns nil")
    func loadTokenWithNoPriorSaveReturnsNil() {
        // init() already called deleteToken(); no save here
        let loaded = KeychainService.loadToken()
        #expect(loaded == nil)
    }

}

@Suite("KeychainTokenStorage Tests", .enabled(if: keychainTestsEnabled,
       "Requires real Keychain access — triggers macOS permission dialog; set KEYCHAIN_TESTS_ENABLED=1 to run"))
struct KeychainTokenStorageTests {
    init() {
        KeychainService.deleteToken()
    }

    @Test("KeychainTokenStorage save and load round-trips through real Keychain")
    func keychainTokenStorageSaveLoadRoundTrip() throws {
        defer { KeychainService.deleteToken() }
        let storage = KeychainTokenStorage()
        try storage.saveToken("wrapper-token-abc")
        let loaded = storage.loadToken()
        #expect(loaded == "wrapper-token-abc")
    }

    @Test("KeychainTokenStorage delete removes token")
    func keychainTokenStorageDeleteRemovesToken() throws {
        defer { KeychainService.deleteToken() }
        let storage = KeychainTokenStorage()
        try storage.saveToken("delete-me")
        storage.deleteToken()
        #expect(storage.loadToken() == nil)
    }

    @Test("KeychainTokenStorage loadToken returns nil when no token saved")
    func keychainTokenStorageLoadNilWhenEmpty() {
        let storage = KeychainTokenStorage()
        // init() already deleted any existing token
        #expect(storage.loadToken() == nil)
    }
}
