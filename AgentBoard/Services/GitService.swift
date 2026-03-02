import Foundation

actor GitService {
    func fetchCommits(projectPath: URL, limit: Int = 250) async throws -> [GitCommitRecord] {
        let format = "%H%x1f%h%x1f%ct%x1f%s%x1f%D%x1e"
        let result = try await ShellCommand.runAsync(
            arguments: [
                "git",
                "log",
                "--all",
                "-n", String(max(limit, 1)),
                "--date=unix",
                "--pretty=format:\(format)"
            ],
            workingDirectory: projectPath
        )

        return parseCommitRecords(from: result.stdout)
    }

    func fetchCurrentBranch(projectPath: URL) async throws -> String {
        let result = try await ShellCommand.runAsync(
            arguments: ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            workingDirectory: projectPath
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchCommitDiff(projectPath: URL, commitSHA: String) async throws -> String {
        let result = try await ShellCommand.runAsync(
            arguments: [
                "git",
                "show",
                "--no-color",
                "--patch",
                "--stat",
                "--date=iso",
                "--pretty=format:%h %s%nAuthor: %an%nDate: %ad%n",
                commitSHA
            ],
            workingDirectory: projectPath
        )
        return result.stdout
    }

    func parseCommitRecords(from output: String) -> [GitCommitRecord] {
        let records = output
            .split(separator: "\u{1e}", omittingEmptySubsequences: true)
            .compactMap { rawRecord -> GitCommitRecord? in
                let fields = rawRecord.split(
                    separator: "\u{1f}",
                    omittingEmptySubsequences: false
                )
                guard fields.count >= 5 else { return nil }

                let sha = String(fields[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let shortSHA = String(fields[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                let timestamp = TimeInterval(fields[2]) ?? 0
                let subject = String(fields[3]).trimmingCharacters(in: .whitespacesAndNewlines)
                let refs = String(fields[4]).trimmingCharacters(in: .whitespacesAndNewlines)

                guard !sha.isEmpty else { return nil }
                return GitCommitRecord(
                    sha: sha,
                    shortSHA: shortSHA,
                    authoredAt: Date(timeIntervalSince1970: timestamp),
                    subject: subject,
                    refs: refs,
                    branch: parseBranch(from: refs),
                    beadIDs: extractBeadIDs(from: subject)
                )
            }

        return records.sorted { lhs, rhs in lhs.authoredAt > rhs.authoredAt }
    }

    private func parseBranch(from refs: String) -> String? {
        let trimmed = refs
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let headRef = parts.first(where: { $0.contains("HEAD ->") }) {
            return headRef.replacingOccurrences(of: "HEAD ->", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let branchRef = parts.first(where: { !$0.hasPrefix("tag:") }) {
            return branchRef
        }

        return parts.first
    }

    private func extractBeadIDs(from text: String) -> [String] {
        let pattern = #"\b[A-Za-z][A-Za-z0-9_-]*-[A-Za-z0-9.]+\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)

        var unique: [String] = []
        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            let value = String(text[swiftRange])
            if !unique.contains(value) {
                unique.append(value)
            }
        }
        return unique
    }
}
