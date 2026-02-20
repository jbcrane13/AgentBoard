import Foundation

struct AppConfigStore {
    private let fileManager = FileManager.default

    private var configURL: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".agentboard", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    func loadOrCreate() throws -> AppConfig {
        if fileManager.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            var config = try decoder.decode(AppConfig.self, from: data)

            // Migrate: if token exists in JSON, move it to Keychain
            if let jsonToken = config.openClawToken, !jsonToken.isEmpty {
                try? KeychainService.saveToken(jsonToken)
                config.openClawToken = nil
                try? save(config) // Strip token from JSON
            }

            config = hydrateOpenClawIfNeeded(config)

            // Hydrate token from Keychain (unless auto-discover already set one)
            if config.openClawToken == nil || config.openClawToken?.isEmpty == true {
                config.openClawToken = KeychainService.loadToken()
            }

            return config
        }

        var config = AppConfig(
            projects: discoverProjects(in: nil),
            selectedProjectPath: nil,
            openClawGatewayURL: nil,
            openClawToken: nil,
            gatewayConfigSource: nil,
            projectsDirectory: nil
        )
        config.selectedProjectPath = config.projects.first?.path
        config = hydrateOpenClawIfNeeded(config)

        // Hydrate token from Keychain
        if config.openClawToken == nil || config.openClawToken?.isEmpty == true {
            config.openClawToken = KeychainService.loadToken()
        }

        try save(config)
        return config
    }

    func save(_ config: AppConfig) throws {
        let dirURL = configURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dirURL.path) {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }

        // Save token to Keychain instead of config JSON
        if let token = config.openClawToken, !token.isEmpty {
            try? KeychainService.saveToken(token)
        }

        // Strip token before writing JSON
        var stripped = config
        stripped.openClawToken = nil

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(stripped)
        try data.write(to: configURL, options: .atomic)
    }

    func discoverProjects(in directory: URL? = nil) -> [ConfiguredProject] {
        let projectsRoot = directory ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Projects", isDirectory: true)
        guard let projectURLs = try? fileManager.contentsOfDirectory(
            at: projectsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let configured = projectURLs.compactMap { url -> ConfiguredProject? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }
            let beadsDir = url.appendingPathComponent(".beads", isDirectory: true)
            guard fileManager.fileExists(atPath: beadsDir.path) else {
                return nil
            }
            return ConfiguredProject(path: url.path, icon: "📁")
        }

        return configured.sorted { lhs, rhs in
            URL(fileURLWithPath: lhs.path).lastPathComponent.localizedCaseInsensitiveCompare(
                URL(fileURLWithPath: rhs.path).lastPathComponent
            ) == .orderedAscending
        }
    }

    private func hydrateOpenClawIfNeeded(_ config: AppConfig) -> AppConfig {
        // If user manually configured gateway settings, don't overwrite
        guard !config.isGatewayManual else { return config }

        guard let openClaw = discoverOpenClawConfig() else {
            return config
        }

        // Always sync from openclaw.json in auto mode
        var updated = config
        if let url = openClaw.gatewayURL {
            updated.openClawGatewayURL = url
        }
        if let token = openClaw.token {
            updated.openClawToken = token
        }
        return updated
    }

    func discoverOpenClawConfig() -> (gatewayURL: String?, token: String?)? {
        let url = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw", isDirectory: true)
            .appendingPathComponent("openclaw.json", isDirectory: false)

        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let gateway = object["gateway"] as? [String: Any]
        let auth = gateway?["auth"] as? [String: Any]
        let token = auth?["token"] as? String

        // Construct gateway URL from port + bind (gateway.url doesn't exist in config)
        let port = gateway?["port"] as? Int ?? 18789
        let bind = gateway?["bind"] as? String ?? "loopback"
        let host: String
        switch bind {
        case "loopback", "localhost", "127.0.0.1":
            host = "127.0.0.1"
        case "0.0.0.0", "all":
            host = "127.0.0.1"
        default:
            host = bind
        }
        let gatewayURL = "http://\(host):\(port)"

        return (gatewayURL, token)
    }
}
