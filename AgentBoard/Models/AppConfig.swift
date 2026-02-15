import Foundation

struct AppConfig: Codable, Sendable {
    var projects: [ConfiguredProject]
    var selectedProjectPath: String?
    var openClawGatewayURL: String?
    var openClawToken: String?

    static let empty = AppConfig(
        projects: [],
        selectedProjectPath: nil,
        openClawGatewayURL: nil,
        openClawToken: nil
    )
}

struct ConfiguredProject: Codable, Hashable, Identifiable, Sendable {
    let path: String
    var icon: String

    var id: String { path }
}
