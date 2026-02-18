import CryptoKit
import Foundation

/// Manages a persistent Ed25519 device identity for gateway authentication.
/// The keypair is generated once and stored in ~/.agentboard/device-identity.json.
struct DeviceIdentity: Codable {
    let deviceId: String
    let publicKeyBase64Url: String
    private let privateKeyBase64Url: String

    /// The SPKI-prefixed public key bytes (for Ed25519, 12-byte prefix + 32-byte key).
    private static let ed25519SpkiPrefix = Data([
        0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65,
        0x70, 0x03, 0x21, 0x00
    ])

    /// Load or create the device identity.
    static func loadOrCreate() -> DeviceIdentity {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agentboard", isDirectory: true)
        let identityFile = configDir.appendingPathComponent("device-identity.json")

        if let data = try? Data(contentsOf: identityFile),
           let identity = try? JSONDecoder().decode(DeviceIdentity.self, from: data) {
            return identity
        }

        let identity = DeviceIdentity.generate()
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(identity) {
            try? data.write(to: identityFile, options: .atomic)
        }
        return identity
    }

    /// Generate a new Ed25519 keypair.
    private static func generate() -> DeviceIdentity {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyRaw = privateKey.publicKey.rawRepresentation

        // Device ID = SHA-256 of SPKI-encoded public key (matching gateway's deriveDeviceIdFromPublicKey)
        let spkiBytes = ed25519SpkiPrefix + publicKeyRaw
        let deviceId = SHA256.hash(data: spkiBytes)
            .map { String(format: "%02x", $0) }
            .joined()

        return DeviceIdentity(
            deviceId: deviceId,
            publicKeyBase64Url: publicKeyRaw.base64UrlEncoded,
            privateKeyBase64Url: privateKey.rawRepresentation.base64UrlEncoded
        )
    }

    /// Sign the device auth payload for gateway handshake.
    func sign(payload: String) -> String {
        guard let keyData = Data(base64UrlEncoded: privateKeyBase64Url),
              let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData),
              let signature = try? privateKey.signature(for: Data(payload.utf8)) else {
            return ""
        }
        return signature.base64UrlEncoded
    }

    /// Build the device auth payload string matching the gateway's buildDeviceAuthPayload.
    func buildAuthPayload(
        clientId: String,
        clientMode: String,
        role: String,
        scopes: [String],
        signedAtMs: Int64,
        token: String?,
        nonce: String?
    ) -> String {
        let version = nonce != nil ? "v2" : "v1"
        var parts = [
            version,
            deviceId,
            clientId,
            clientMode,
            role,
            scopes.joined(separator: ","),
            String(signedAtMs),
            token ?? ""
        ]
        if version == "v2" {
            parts.append(nonce ?? "")
        }
        return parts.joined(separator: "|")
    }
}

// MARK: - Base64 URL encoding/decoding

extension Data {
    var base64UrlEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64UrlEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }
}
