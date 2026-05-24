import Foundation

public enum ChatEndpointValidationError: LocalizedError, Equatable {
    case hermesEndpointMatchesCompanion(String)
    case hermesLocalEndpointUsesHTTPS(String)

    public var errorDescription: String? {
        switch self {
        case let .hermesEndpointMatchesCompanion(endpoint):
            return """
            Chat is pointed at the companion service at \(
                endpoint
            ). Companion handles tasks and sessions; set this profile's \
            Hermes Gateway URL to that profile's API server port.
            """
        case let .hermesLocalEndpointUsesHTTPS(endpoint):
            return """
            Hermes Gateway URL is using HTTPS at \(endpoint), but Hermes' API server is HTTP by default. Use \
            http://<host>:<profile-port>, or put a TLS proxy in front of Hermes.
            """
        }
    }
}

public struct ChatEndpointValidator: Sendable {
    public init() {}

    public func validate(hermesGatewayURL: String, companionURL: String) throws {
        try validateHermesScheme(hermesGatewayURL)

        guard let hermesEndpoint = Self.normalizedEndpoint(hermesGatewayURL),
              let companionEndpoint = Self.normalizedEndpoint(companionURL),
              hermesEndpoint == companionEndpoint else {
            return
        }

        throw ChatEndpointValidationError.hermesEndpointMatchesCompanion(hermesGatewayURL)
    }

    public func uploadEndpointURL(hermesGatewayURL: String) -> URL {
        normalizedHermesGatewayURL(hermesGatewayURL).appendingPathComponent("v1/upload")
    }

    public func normalizedHermesGatewayURL(_ rawValue: String) -> URL {
        let baseURL = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackURL = URL(string: "http://127.0.0.1:8642")!
        guard let url = URL(string: baseURL) else {
            return fallbackURL
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var pathComponents = url.pathComponents.filter { $0 != "/" }
        if pathComponents.last == "v1" {
            pathComponents.removeLast()
        }
        components?.path = pathComponents.isEmpty ? "" : "/" + pathComponents.joined(separator: "/")
        return components?.url ?? url
    }

    public static func normalizedEndpoint(_ rawValue: String) -> String? {
        guard let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased()
        else { return nil }

        let defaultPort = scheme == "https" ? 443 : 80
        let port = url.port ?? defaultPort
        return "\(scheme)://\(host):\(port)"
    }

    public static func isLocalOrPrivateHost(_ host: String) -> Bool {
        let normalizedHost = host.lowercased()
        if ["localhost", "::1"].contains(normalizedHost) || normalizedHost.hasPrefix("127.") {
            return true
        }

        let octets = normalizedHost.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else { return false }

        if octets[0] == 10 || octets[0] == 127 || octets[0] == 192 && octets[1] == 168 {
            return true
        }

        if octets[0] == 172, (16 ... 31).contains(octets[1]) {
            return true
        }

        return octets[0] == 100 && (64 ... 127).contains(octets[1])
    }

    private func validateHermesScheme(_ rawValue: String) throws {
        guard let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              Self.isLocalOrPrivateHost(host) else {
            return
        }

        throw ChatEndpointValidationError.hermesLocalEndpointUsesHTTPS(rawValue)
    }
}
