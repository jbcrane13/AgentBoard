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
            let config = try decoder.decode(AppConfig.self, from: data)
            return hydrateOpenClawIfNeeded(config)
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
        try save(config)
        return config
    }

    func save(_ config: AppConfig) throws {
        let dirURL = configURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dirURL.path) {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
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
