import Foundation
import Testing
@testable import AgentBoard

@Suite("ConnectionError Tests")
struct ConnectionErrorTests {

    // MARK: - userMessage and briefLabel

    @Test("deviceMismatch has correct userMessage and briefLabel")
    func deviceMismatchMessages() {
        let error = ConnectionError.deviceMismatch
        #expect(error.userMessage.contains("device-identity.json"))
        #expect(error.briefLabel == "Device Mismatch")
        #expect(error.isNonRetryable == true)
    }

    @Test("pairingRequired has correct userMessage and briefLabel")
    func pairingRequiredMessages() {
        let error = ConnectionError.pairingRequired
        #expect(error.userMessage.lowercased().contains("pairing"))
        #expect(error.briefLabel == "Pairing Required")
        #expect(error.isNonRetryable == true)
    }

    @Test("connectionRefused includes URL in userMessage")
    func connectionRefusedIncludesURL() {
        let error = ConnectionError.connectionRefused("http://127.0.0.1:18789")
        #expect(error.userMessage.contains("http://127.0.0.1:18789"))
        #expect(error.briefLabel == "Connection Refused")
        #expect(error.isNonRetryable == false)
    }

    @Test("authFailed has correct userMessage and is non-retryable")
    func authFailedMessages() {
        let error = ConnectionError.authFailed
        #expect(error.userMessage.lowercased().contains("token") || error.userMessage.lowercased().contains("auth"))
        #expect(error.briefLabel == "Auth Failed")
        #expect(error.isNonRetryable == true)
    }

    @Test("generic error includes message in userMessage")
    func genericErrorIncludesMessage() {
        let error = ConnectionError.generic("Something went wrong")
        #expect(error.userMessage.contains("Something went wrong"))
        #expect(error.briefLabel == "Connection Error")
        #expect(error.isNonRetryable == false)
    }

    // MARK: - classify

    @Test("classify maps 'device identity mismatch' error to deviceMismatch")
    func classifyDeviceMismatch() {
        let error = GatewayClientError.connectionFailed("device identity mismatch")
        let classified = ConnectionError.classify(error, gatewayURL: nil)
        #expect(classified == .deviceMismatch)
    }

    @Test("classify maps 'pairing required' error to pairingRequired")
    func classifyPairingRequired() {
        let error = GatewayClientError.connectionFailed("pairing required")
        let classified = ConnectionError.classify(error, gatewayURL: nil)
        #expect(classified == .pairingRequired)
    }

    @Test("classify maps 'unauthorized' error to authFailed")
    func classifyUnauthorized() {
        let error = GatewayClientError.connectionFailed("unauthorized: bad credentials")
        let classified = ConnectionError.classify(error, gatewayURL: nil)
        #expect(classified == .authFailed)
    }

    @Test("classify maps 'token missing' error to authFailed")
    func classifyTokenMissing() {
        let error = GatewayClientError.connectionFailed("gateway token missing")
        let classified = ConnectionError.classify(error, gatewayURL: nil)
        #expect(classified == .authFailed)
    }

    @Test("classify maps URLError.cannotConnectToHost to connectionRefused")
    func classifyURLErrorCannotConnect() {
        let error = URLError(.cannotConnectToHost)
        let classified = ConnectionError.classify(error, gatewayURL: "http://127.0.0.1:18789")
        #expect(classified == .connectionRefused("http://127.0.0.1:18789"))
    }

    @Test("classify maps URLError.cannotFindHost to connectionRefused")
    func classifyURLErrorCannotFindHost() {
        let error = URLError(.cannotFindHost)
        let classified = ConnectionError.classify(error, gatewayURL: "http://bad-host:9999")
        #expect(classified == .connectionRefused("http://bad-host:9999"))
    }

    @Test("classify falls back to generic for unknown error messages")
    func classifyFallsBackToGeneric() {
        let error = GatewayClientError.requestFailed("some unexpected error xyz")
        let classified = ConnectionError.classify(error, gatewayURL: nil)
        if case .generic = classified {
            #expect(true)
        } else {
            Issue.record("Expected generic classification, got: \(classified)")
        }
    }

    @Test("classify connectionRefused uses 'unknown' when gatewayURL is nil")
    func classifyConnectionRefusedNilURLFallsBack() {
        let error = URLError(.cannotConnectToHost)
        let classified = ConnectionError.classify(error, gatewayURL: nil)
        #expect(classified == .connectionRefused("unknown"))
    }

    // MARK: - Equatable

    @Test("ConnectionError equatable works for same cases")
    func connectionErrorEquatable() {
        #expect(ConnectionError.deviceMismatch == .deviceMismatch)
        #expect(ConnectionError.pairingRequired == .pairingRequired)
        #expect(ConnectionError.authFailed == .authFailed)
        #expect(ConnectionError.connectionRefused("a") == .connectionRefused("a"))
        #expect(ConnectionError.generic("x") == .generic("x"))
    }

    @Test("ConnectionError equatable is false for different cases")
    func connectionErrorNotEqual() {
        #expect(ConnectionError.deviceMismatch != .authFailed)
        #expect(ConnectionError.connectionRefused("a") != .connectionRefused("b"))
        #expect(ConnectionError.generic("x") != .generic("y"))
    }
}
