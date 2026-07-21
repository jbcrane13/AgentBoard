import Foundation

/// Resolves GitHub repositories to their canonical local checkouts.
///
/// Hermes' project registry is authoritative when it contains a matching
/// `repo:` entry. Repositories that are not registered keep the historical
/// `~/Projects/<repo-name>` fallback.
public struct ProjectPathResolver: Sendable {
    public struct RegistryEntry: Equatable, Sendable {
        public let repo: String
        public let path: String

        public init(repo: String, path: String) {
            self.repo = repo
            self.path = path
        }
    }

    private let homeDirectory: URL
    private let registryURL: URL

    public init(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        registryURL: URL? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.registryURL = registryURL ?? homeDirectory
            .appendingPathComponent(".hermes", isDirectory: true)
            .appendingPathComponent("projects.yaml")
    }

    public func resolve(repoName: String, fullRepo: String) -> String {
        if let contents = try? String(contentsOf: registryURL, encoding: .utf8),
           let entry = Self.parseEntries(contents).first(where: {
               $0.repo.caseInsensitiveCompare(fullRepo) == .orderedSame
           }) {
            let url = expandedURL(for: entry.path)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return url.standardizedFileURL.path
            }
        }

        return homeDirectory
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(repoName, isDirectory: true)
            .standardizedFileURL.path
    }

    public static func parseEntries(_ yaml: String) -> [RegistryEntry] {
        var entries: [RegistryEntry] = []
        var currentRepo: String?
        var currentPath: String?

        func appendCurrent() {
            guard let currentRepo, let currentPath else { return }
            entries.append(RegistryEntry(repo: currentRepo, path: currentPath))
        }

        for line in yaml.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- name:") {
                appendCurrent()
                currentRepo = nil
                currentPath = nil
            } else if trimmed.hasPrefix("repo:") {
                currentRepo = value(after: "repo:", in: trimmed)
            } else if trimmed.hasPrefix("path:") {
                currentPath = value(after: "path:", in: trimmed)
            }
        }
        appendCurrent()
        return entries
    }

    private static func value(after prefix: String, in line: String) -> String {
        let raw = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        guard raw.count >= 2 else { return raw }
        if (raw.hasPrefix("\"") && raw.hasSuffix("\"")) ||
            (raw.hasPrefix("'") && raw.hasSuffix("'")) {
            return String(raw.dropFirst().dropLast())
        }
        return raw
    }

    private func expandedURL(for path: String) -> URL {
        if path == "~" {
            return homeDirectory
        }
        if path.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(path.dropFirst(2)))
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
