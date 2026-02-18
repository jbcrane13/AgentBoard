import Foundation

struct AppConfig: Codable, Sendable {
    var projects: [ConfiguredProject]
    var selectedProjectPath: String?
    var openClawGatewayURL: String?
    var openClawToken: String?
    /// "auto" = re-read from openclaw.json every launch; "manual" = user-entered, don't overwrite
    var gatewayConfigSource: String?
    /// Root directory for auto-discovering projects with .beads/ folders. Defaults to ~/Projects.
    var projectsDirectory: String?

    var isGatewayManual: Bool {
        gatewayConfigSource == "manual"
    }

    var resolvedProjectsDirectory: URL {
        if let dir = projectsDirectory, !dir.isEmpty {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Projects", isDirectory: true)
    }

    static let empty = AppConfig(
        projects: [],
        selectedProjectPath: nil,
        openClawGatewayURL: nil,
        openClawToken: nil,
        gatewayConfigSource: nil,
        projectsDirectory: nil
    )
}

struct ConfiguredProject: Codable, Hashable, Identifiable, Sendable {
    let path: String
    var icon: String

    var id: String { path }
}
