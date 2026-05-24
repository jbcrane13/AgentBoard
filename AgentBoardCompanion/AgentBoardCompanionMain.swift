import AgentBoardCompanionKit
import Foundation

@main
struct AgentBoardCompanionMain {
    static func main() async throws {
        let configurationURL = defaultConfigURL()
        let configuration = try loadConfiguration(at: configurationURL)
        let databaseURL = URL(fileURLWithPath: NSString(string: configuration.databasePath).expandingTildeInPath)

        let store = try CompanionSQLiteStore(databaseURL: databaseURL)
        try await store.initializeSchema()

        let server = CompanionServer(configuration: configuration, store: store)
        try server.start()

        print("AgentBoard Companion listening at \(configuration.baseURL)")
        if let token = configuration.bearerToken?.trimmedOrNil {
            print("Bearer token: \(token)")
        }

        while true {
            try await Task.sleep(for: .seconds(86400))
        }
    }

    private static func defaultConfigURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appending(path: ".agentboard-companion", directoryHint: .isDirectory)
            .appending(path: "config.json")
    }

    private static func loadConfiguration(at url: URL) throws -> CompanionServerConfiguration {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            return try decoder.decode(CompanionServerConfiguration.self, from: data)
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let configuration = CompanionServerConfiguration(
            bearerToken: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            databasePath: home
                .appending(path: ".agentboard-companion", directoryHint: .isDirectory)
                .appending(path: "state.sqlite")
                .path
        )

        try encoder.encode(configuration).write(to: url)
        return configuration
    }
}
