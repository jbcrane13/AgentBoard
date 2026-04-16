import Foundation

/// Generates Product Requirements Documents (PRDs) from issue beads.
///
/// Converts a Bead issue into a structured markdown PRD suitable for
/// coding agent sessions (ralphy retry loops).
final class PRDGenerator {

    /// Generate a PRD markdown string from a bead/issue.
    func generatePRD(from bead: Bead) -> String {
        var prd = ""

        // Title
        prd += "# \(bead.title)\n\n"

        // Description
        if let body = bead.body, !body.isEmpty {
            prd += "## Description\n\n\(body)\n\n"
        }

        // Context
        prd += "## Context\n\n"
        prd += "- Issue: \(bead.id)\n"
        if let priority = priorityLabel(bead.priority) {
            prd += "- Priority: \(priority)\n"
        }
        prd += "- Type: \(bead.kind.rawValue.capitalized)\n"
        if let assignee = bead.assignee, !assignee.isEmpty {
            prd += "- Assignee: \(assignee)\n"
        }
        if !bead.labels.isEmpty {
            prd += "- Labels: \(bead.labels.joined(separator: ", "))\n"
        }
        prd += "\n"

        // Tasks (from checkboxes in body or derived from title)
        let tasks = extractTasks(from: bead)
        if !tasks.isEmpty {
            prd += "## Tasks\n\n"
            for task in tasks {
                prd += "- [ ] \(task)\n"
            }
            prd += "\n"
        }

        // Acceptance criteria
        prd += "## Acceptance Criteria\n\n"
        prd += "- [ ] All tests pass\n"
        prd += "- [ ] Code review completed\n"
        prd += "- [ ] No regressions introduced\n"
        prd += "\n"

        return prd
    }

    /// Save PRD content to a temporary file and return the path.
    func savePRD(content: String, for bead: Bead) -> String {
        let issueNumber = GitHubIssuesService.issueNumber(from: bead.id) ?? 0
        let filename = "PRD-\(issueNumber).md"
        let tempDir = FileManager.default.temporaryDirectory
        let prdPath = tempDir.appendingPathComponent(filename)

        try? content.write(to: prdPath, atomically: true, encoding: .utf8)

        return prdPath.path
    }

    // MARK: - Private Helpers

    private func extractTasks(from bead: Bead) -> [String] {
        var tasks: [String] = []

        // Extract checkbox items from issue body
        if let body = bead.body {
            let checkboxPattern = "- \\[ \\] (.+)"
            if let regex = try? NSRegularExpression(pattern: checkboxPattern) {
                let matches = regex.matches(in: body, range: NSRange(body.startIndex..., in: body))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: body) {
                        tasks.append(String(body[range]))
                    }
                }
            }
        }

        // Fall back to title if no tasks found
        if tasks.isEmpty {
            tasks.append(bead.title)
        }

        return tasks
    }

    private func priorityLabel(_ priority: Int) -> String? {
        switch priority {
        case 0: return "P0 - Critical"
        case 1: return "P1 - High"
        case 2: return "P2 - Medium"
        case 3: return "P3 - Low"
        case 4: return "P4 - Backlog"
        default: return nil
        }
    }
}
