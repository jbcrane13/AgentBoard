import CryptoKit
import Foundation
import Testing
@testable import AgentBoard

@Suite("DeviceIdentity Tests")
struct DeviceIdentityTests {

    // MARK: - loadOrCreate

    @Test("loadOrCreate returns non-empty deviceId")
    func loadOrCreateHasNonEmptyDeviceId() {
        let identity = DeviceIdentity.loadOrCreate()
        #expect(!identity.deviceId.isEmpty)
    }

    @Test("loadOrCreate returns non-empty publicKeyBase64Url")
    func loadOrCreateHasNonEmptyPublicKey() {
        let identity = DeviceIdentity.loadOrCreate()
        #expect(!identity.publicKeyBase64Url.isEmpty)
    }

    @Test("loadOrCreate returns the same identity on repeated calls")
    func loadOrCreateIsConsistent() {
        let first = DeviceIdentity.loadOrCreate()
        let second = DeviceIdentity.loadOrCreate()
        #expect(first.deviceId == second.deviceId)
        #expect(first.publicKeyBase64Url == second.publicKeyBase64Url)
    }

    @Test("loadOrCreate deviceId is 64 lowercase hex characters (SHA-256 output)")
    func loadOrCreateDeviceIdIs64HexChars() {
        let identity = DeviceIdentity.loadOrCreate()
        #expect(identity.deviceId.count == 64)
        let hexCharset = CharacterSet(charactersIn: "0123456789abcdef")
        #expect(identity.deviceId.unicodeScalars.allSatisfy { hexCharset.contains($0) })
    }

    // MARK: - buildAuthPayload

    @Test("buildAuthPayload without nonce produces v1 format with 8 pipe-separated parts")
    func buildAuthPayloadV1Format() {
        let identity = DeviceIdentity.loadOrCreate()
        let payload = identity.buildAuthPayload(
            clientId: "webchat",
            clientMode: "webchat",
            role: "operator",
            scopes: ["operator.read"],
            signedAtMs: 1_700_000_000_000,
            token: "tok",
            nonce: nil
        )
        #expect(payload.hasPrefix("v1|"))
        let parts = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        // v1|deviceId|clientId|clientMode|role|scopes|signedAt|token
        #expect(parts.count == 8)
        #expect(parts[0] == "v1")
        #expect(parts[1] == identity.deviceId)
        #expect(parts[2] == "webchat")
        #expect(parts[3] == "webchat")
        #expect(parts[4] == "operator")
        #expect(parts[6] == "1700000000000")
        #expect(parts[7] == "tok")
    }

    @Test("buildAuthPayload with nonce produces v2 format with 9 pipe-separated parts")
    func buildAuthPayloadV2Format() {
        let identity = DeviceIdentity.loadOrCreate()
        let nonce = "test-nonce-12345"
        let payload = identity.buildAuthPayload(
            clientId: "webchat",
            clientMode: "webchat",
            role: "operator",
            scopes: ["operator.read", "operator.write"],
            signedAtMs: 1_700_000_000_000,
            token: nil,
            nonce: nonce
        )
        #expect(payload.hasPrefix("v2|"))
        #expect(payload.hasSuffix("|\(nonce)"))
        let parts = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        // v2|deviceId|clientId|clientMode|role|scopes|signedAt|token|nonce
        #expect(parts.count == 9)
        #expect(parts[0] == "v2")
        #expect(parts[8] == nonce)
    }

    @Test("buildAuthPayload v2 joins multiple scopes with comma")
    func buildAuthPayloadScopesJoined() {
        let identity = DeviceIdentity.loadOrCreate()
        let scopes = ["operator.read", "operator.write", "operator.admin"]
        let payload = identity.buildAuthPayload(
            clientId: "webchat",
            clientMode: "webchat",
            role: "operator",
            scopes: scopes,
            signedAtMs: 1_000,
            token: nil,
            nonce: "nonce"
        )
        #expect(payload.contains("operator.read,operator.write,operator.admin"))
    }

    @Test("buildAuthPayload includes empty string for nil token")
    func buildAuthPayloadNilTokenBecomesEmptyString() {
        let identity = DeviceIdentity.loadOrCreate()
        let payload = identity.buildAuthPayload(
            clientId: "webchat",
            clientMode: "webchat",
            role: "operator",
            scopes: [],
            signedAtMs: 1_000,
            token: nil,
            nonce: nil
        )
        // v1 format: parts[7] should be empty string
        let parts = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        #expect(parts[7] == "")
    }

    // MARK: - sign

    @Test("sign produces non-empty signature for any payload string")
    func signProducesNonEmptySignature() {
        let identity = DeviceIdentity.loadOrCreate()
        let signature = identity.sign(payload: "v2|test|payload")
        #expect(!signature.isEmpty)
    }

    @Test("sign returns base64url string with no +, /, or = characters")
    func signOutputIsBase64Url() {
        let identity = DeviceIdentity.loadOrCreate()
        let signature = identity.sign(payload: "v2|some|payload|string")
        #expect(!signature.contains("+"))
        #expect(!signature.contains("/"))
        #expect(!signature.contains("="))
    }

    // MARK: - Data base64Url extensions

    @Test("base64UrlEncoded replaces + with -, / with _, and strips = padding")
    func base64UrlEncodedTransforms() {
        // 0xFB, 0xEF produce +/ chars in standard base64 for these bytes
        let data = Data([0xFB, 0xEF, 0x00])
        let encoded = data.base64UrlEncoded
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }

    @Test("base64UrlEncoded and base64UrlDecoded are a round-trip")
    func base64UrlRoundTrip() {
        let original = Data((0..<32).map { UInt8($0) })
        let encoded = original.base64UrlEncoded
        let decoded = Data(base64UrlEncoded: encoded)
        #expect(decoded == original)
    }

    @Test("Data(base64UrlEncoded:) decodes url-safe - and _ characters correctly")
    func base64UrlDecodingHandlesUrlSafeChars() {
        let data = Data([0xFB, 0xFF, 0xFE])
        let urlSafe = data.base64UrlEncoded
        // Verify decode succeeds and returns original bytes
        let decoded = Data(base64UrlEncoded: urlSafe)
        #expect(decoded == data)
    }

    @Test("Data(base64UrlEncoded:) with completely invalid string returns nil")
    func base64UrlDecodingInvalidStringReturnsNil() {
        let result = Data(base64UrlEncoded: "!!!not-valid!!!")
        #expect(result == nil)
    }
}
