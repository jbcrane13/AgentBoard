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
            return hydrateOpenClawIfNeeded(config)
        }

        var config = AppConfig(
            projects: discoverProjects(),
            selectedProjectPath: nil,
            openClawGatewayURL: nil,
            openClawToken: nil
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

    func discoverProjects() -> [ConfiguredProject] {
        let projectsRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Projects", isDirectory: true)
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
        guard let openClaw = discoverOpenClawConfig() else {
            return config
        }

        var updated = config
        if updated.openClawGatewayURL == nil {
            updated.openClawGatewayURL = openClaw.gatewayURL
        }
        if updated.openClawToken == nil {
            updated.openClawToken = openClaw.token
        }
        return updated
    }

    private func discoverOpenClawConfig() -> (gatewayURL: String?, token: String?)? {
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
        let gatewayURL = gateway?["url"] as? String
        return (gatewayURL, token)
    }
}
