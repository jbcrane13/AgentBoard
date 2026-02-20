import Foundation
import Testing
@testable import AgentBoard

@Suite("KeychainService Tests")
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
