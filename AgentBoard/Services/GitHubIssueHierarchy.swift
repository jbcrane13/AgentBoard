import Foundation

enum GitHubIssueHierarchy {
    private static let childSectionTitles: Set<String> = ["child issues", "sub-issues"]
    static let canonicalChildSectionTitle = "Child issues"

    static func childIssueNumbers(in body: String?) -> [Int] {
        guard let body, !body.isEmpty else { return [] }

        var childNumbers: [Int] = []
        var seenNumbers = Set<Int>()
        var isInChildSection = false

        for line in body.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let headingTitle = markdownHeadingTitle(from: trimmed) {
                let normalizedTitle = headingTitle.lowercased()
                if childSectionTitles.contains(normalizedTitle) {
                    isInChildSection = true
                } else if isInChildSection {
                    break
                }
                continue
            }

            guard isInChildSection else { continue }
            guard isMarkdownListItem(trimmed) else {
                if trimmed.isEmpty { continue }
                continue
            }

            guard let childNumber = referencedIssueNumber(in: trimmed), childNumber > 0 else { continue }
            if seenNumbers.insert(childNumber).inserted {
                childNumbers.append(childNumber)
            }
        }

        return childNumbers
    }

    static func applyingParentRelationships(to beads: [Bead]) -> [Bead] {
        let parentNumbersByChildNumber = parentNumbersByChildNumber(in: beads)

        return beads.map { bead in
            guard let issueNumber = GitHubIssuesService.issueNumber(from: bead.id),
                  let parentIssueNumber = parentNumbersByChildNumber[issueNumber]
            else {
                return bead
            }

            var updatedBead = bead
            updatedBead.parentIssueNumber = parentIssueNumber
            updatedBead = Bead(
                id: updatedBead.id,
                title: updatedBead.title,
                body: updatedBead.body,
                status: updatedBead.status,
                kind: updatedBead.kind,
                priority: updatedBead.priority,
                epicId: "GH-\(parentIssueNumber)",
                labels: updatedBead.labels,
                assignee: updatedBead.assignee,
                milestoneNumber: updatedBead.milestoneNumber,
                milestoneTitle: updatedBead.milestoneTitle,
                createdAt: updatedBead.createdAt,
                updatedAt: updatedBead.updatedAt,
                dependencies: updatedBead.dependencies,
                gitBranch: updatedBead.gitBranch,
                lastCommit: updatedBead.lastCommit,
                parentIssueNumber: parentIssueNumber
            )
            return updatedBead
        }
    }

    private static func parentNumbersByChildNumber(in beads: [Bead]) -> [Int: Int] {
        let parentCandidates = beads.sorted { lhs, rhs in
            if lhs.kind == rhs.kind {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.kind == .epic && rhs.kind != .epic
        }

        var parentNumbersByChildNumber: [Int: Int] = [:]

        for parent in parentCandidates {
            guard let parentNumber = GitHubIssuesService.issueNumber(from: parent.id) else { continue }
            for childNumber in childIssueNumbers(in: parent.body) where childNumber != parentNumber {
                parentNumbersByChildNumber[childNumber] = parentNumbersByChildNumber[childNumber] ?? parentNumber
            }
        }

        return parentNumbersByChildNumber
    }

    private static func markdownHeadingTitle(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        let title = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private static func isMarkdownListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return true
        }

        guard let firstCharacter = trimmed.first, firstCharacter.isNumber else { return false }
        var index = trimmed.startIndex
        while index < trimmed.endIndex, trimmed[index].isNumber {
            index = trimmed.index(after: index)
        }
        return index < trimmed.endIndex && trimmed[index] == "."
    }

    private static func referencedIssueNumber(in line: String) -> Int? {
        let patterns = [
            #"(?:^|\s)(?:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#(\d+)\b"#,
            #"(?:^|\s)GH-(\d+)\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(line.startIndex ..< line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let numberRange = Range(match.range(at: 1), in: line)
            else {
                continue
            }

            return Int(line[numberRange])
        }

        return nil
    }
}
