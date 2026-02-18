import Foundation

struct AppConfig: Codable, Sendable {
    var projects: [ConfiguredProject]
    var selectedProjectPath: String?
    var openClawGatewayURL: String?
    var openClawToken: String?
    /// "auto" = re-read from openclaw.json every launch; "manual" = user-entered, don't overwrite
    var gatewayConfigSource: String?

    var isGatewayManual: Bool {
        gatewayConfigSource == "manual"
    }

    static let empty = AppConfig(
        projects: [],
        selectedProjectPath: nil,
        openClawGatewayURL: nil,
        openClawToken: nil,
        gatewayConfigSource: nil
    )
}

struct ConfiguredProject: Codable, Hashable, Identifiable, Sendable {
    let path: String
    var icon: String

    var id: String { path }
}
