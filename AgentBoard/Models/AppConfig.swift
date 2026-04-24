import Foundation

struct AppConfig: Codable, Sendable {
    var projects: [ConfiguredProject]
    var selectedProjectPath: String?
    var chatBackend: String?
    var hermesGatewayURL: String?
    var hermesAPIKey: String?
    var openClawGatewayURL: String?
    var openClawToken: String?
    /// "auto" = re-read from openclaw.json every launch; "manual" = user-entered, don't overwrite
    var gatewayConfigSource: String?
    /// Root directory for auto-discovering projects with .beads/ folders. Defaults to ~/Projects.
    var projectsDirectory: String?
    /// Show detailed tool/subagent output in chat. Default: false (suppressed)
    var showToolOutputInChat: Bool?
    /// Shared GitHub API token for loading issues from GitHub Issues API.
    /// Stored in JSON (same pattern as openClawToken). Optional — JSONL fallback used if nil.
    var githubToken: String?

    var isGatewayManual: Bool {
        gatewayConfigSource == "manual"
    }

    var resolvedChatBackend: ChatBackend {
        guard let chatBackend,
              let backend = ChatBackend(rawValue: chatBackend) else {
            return ChatBackend.platformDefault
        }
        return backend
    }

    var resolvedProjectsDirectory: URL {
        if let dir = projectsDirectory, !dir.isEmpty {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        #if os(macOS)
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Projects", isDirectory: true)
        #else
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Projects", isDirectory: true)
        #endif
    }

    static let empty = AppConfig(
        projects: [],
        selectedProjectPath: nil,
        chatBackend: ChatBackend.platformDefault.rawValue,
        hermesGatewayURL: nil,
        hermesAPIKey: nil,
        openClawGatewayURL: nil,
        openClawToken: nil,
        gatewayConfigSource: "auto",
        projectsDirectory: nil,
        showToolOutputInChat: nil,
        githubToken: nil
    )
}

struct ConfiguredProject: Codable, Hashable, Identifiable, Sendable {
    let path: String
    var icon: String
    /// GitHub owner (user or org) for GitHub Issues integration.
    var githubOwner: String?
    /// GitHub repository name for GitHub Issues integration.
    var githubRepo: String?

    var id: String {
        path
    }

    init(path: String, icon: String, githubOwner: String? = nil, githubRepo: String? = nil) {
        self.path = path
        self.icon = icon
        self.githubOwner = githubOwner
        self.githubRepo = githubRepo
    }
}
