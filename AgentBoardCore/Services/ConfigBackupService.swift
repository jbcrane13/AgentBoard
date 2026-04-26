import Foundation
import os

/// Exportable backup bundle containing all AgentBoard configuration.
public struct AgentBoardBackup: Codable, Sendable {
    public let version: Int
    public let exportedAt: Date
    public let settings: AgentBoardSettings
    public let secrets: AgentBoardSecrets

    public init(
        version: Int = 1,
        exportedAt: Date = .now,
        settings: AgentBoardSettings,
        secrets: AgentBoardSecrets
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.settings = settings
        self.secrets = secrets
    }
}

/// Handles exporting and importing AgentBoard configuration backups.
@MainActor
public final class ConfigBackupService {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "ConfigBackup")
    private let settingsStore: SettingsStore
    private let repository: SettingsRepository

    public init(settingsStore: SettingsStore, repository: SettingsRepository) {
        self.settingsStore = settingsStore
        self.repository = repository
    }

    /// Create a backup from the current configuration.
    public func createBackup() async -> AgentBoardBackup {
        let settings = await repository.loadSettings()
        let secrets = await repository.loadSecrets()
        return AgentBoardBackup(settings: settings, secrets: secrets)
    }

    /// Export backup to a JSON Data blob.
    public func exportBackupData() async throws -> Data {
        let backup = await createBackup()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    /// Write backup to a file and return the URL.
    public func exportBackupToFile() async throws -> URL {
        let data = try await exportBackupData()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "agentboard-backup-\(formatter.string(from: .now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        logger.info("Backup exported to \(url.path, privacy: .public)")
        return url
    }

    /// Import backup from JSON Data.
    public func importBackupData(_ data: Data) throws -> AgentBoardBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AgentBoardBackup.self, from: data)
    }

    /// Validate and apply a backup.
    public func restoreFromBackup(_ data: Data) async throws {
        let backup = try importBackupData(data)

        guard backup.version >= 1 else {
            throw BackupError.unsupportedVersion(backup.version)
        }

        try await repository.saveSettings(backup.settings)
        try await repository.saveSecrets(backup.secrets)
        await settingsStore.bootstrap()

        logger.info("Backup restored successfully (version \(backup.version))")
    }

    /// Validate a backup without applying it — returns a summary.
    public func validateBackup(_ data: Data) throws -> BackupSummary {
        let backup = try importBackupData(data)

        return BackupSummary(
            exportedAt: backup.exportedAt,
            version: backup.version,
            hermesProfileCount: backup.settings.hermesProfiles?.count ?? 0,
            repositoryCount: backup.settings.repositories.count,
            hasGitHubToken: backup.secrets.githubToken?.isEmpty == false,
            hasHermesAPIKey: backup.secrets.hermesAPIKey?.isEmpty == false,
            hasCompanionToken: backup.secrets.companionToken?.isEmpty == false
        )
    }
}

public struct BackupSummary {
    public let exportedAt: Date
    public let version: Int
    public let hermesProfileCount: Int
    public let repositoryCount: Int
    public let hasGitHubToken: Bool
    public let hasHermesAPIKey: Bool
    public let hasCompanionToken: Bool

    public var description: String {
        var parts: [String] = []
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        parts.append("Exported: \(formatter.string(from: exportedAt))")
        if hermesProfileCount > 0 {
            parts.append("\(hermesProfileCount) Hermes profile\(hermesProfileCount == 1 ? "" : "s")")
        }
        if repositoryCount > 0 {
            parts.append("\(repositoryCount) repositor\(repositoryCount == 1 ? "y" : "ies")")
        }
        var secrets: [String] = []
        if hasHermesAPIKey { secrets.append("Hermes API key") }
        if hasGitHubToken { secrets.append("GitHub token") }
        if hasCompanionToken { secrets.append("Companion token") }
        if !secrets.isEmpty {
            parts.append("Secrets: \(secrets.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}

public enum BackupError: LocalizedError {
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            return "Backup version \(version) is not supported by this version of AgentBoard."
        }
    }
}
