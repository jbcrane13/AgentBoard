import Foundation

struct AppConfigStore {
    private let fileManager = FileManager.default
    private let configDir: URL

    /// Production initializer — uses ~/.agentboard/
    init() {
        self.configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agentboard", isDirectory: true)
    }

    /// Test initializer — uses a custom directory so tests never touch real config.
    init(directory: URL) {
        self.configDir = directory
    }

    // Kept for backward compatibility; token storage is no longer used.
    init(tokenStorage _: any TokenStorage) {
        self.init()
    }

    private var configURL: URL {
        configDir.appendingPathComponent("config.json", isDirectory: false)
    }

    func loadOrCreate() throws -> AppConfig {
        if fileManager.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            var config = try decoder.decode(AppConfig.self, from: data)

            config = hydrateOpenClawIfNeeded(config)

            // Auto-discover projects if none configured
            if config.projects.isEmpty {
                var updatedConfig = config
                updatedConfig.projects = discoverProjects(in: config.resolvedProjectsDirectory)
                updatedConfig.selectedProjectPath = updatedConfig.projects.first?.path
                config = updatedConfig
                try? save(config)
            }

            return config
        }

        var config = AppConfig(
            projects: discoverProjects(in: nil),
            selectedProjectPath: nil,
            openClawGatewayURL: nil,
            openClawToken: nil,
            gatewayConfigSource: "auto",
            projectsDirectory: nil
        )
        config.selectedProjectPath = config.projects.first?.path
        config = hydrateOpenClawIfNeeded(config)

        try save(config)
        return config
    }

    func save(_ config: AppConfig) throws {
        if !fileManager.fileExists(atPath: configDir.path) {
            try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
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
