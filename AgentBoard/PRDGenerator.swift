import Foundation

/// Generates lightweight PRD markdown from GitHub issues.
public final class PRDGenerator: Sendable {
    public init() {}

    public func generatePRD(from issue: GitHubIssue) -> String {
        var lines: [String] = []

        lines.append("# #\(issue.number): \(issue.title)")
        lines.append("")
        lines.append("## Context")
        lines.append("")
        lines.append("- **Issue:** #\(issue.number)")

        if !issue.labels.isEmpty {
            lines.append("- **Labels:** \(issue.labels.map(\.name).joined(separator: ", "))")
        }
        if let milestone = issue.milestone {
            lines.append("- **Milestone:** \(milestone.title)")
        }
        if !issue.assignees.isEmpty {
            lines.append("- **Assignees:** \(issue.assignees.map(\.login).joined(separator: ", "))")
        }

        lines.append("- **Status:** \(issue.state)")
        lines.append("")

        if let body = issue.body, !body.isEmpty {
            lines.append("## Description")
            lines.append("")
            lines.append(body)
            lines.append("")
        }

        let tasks = extractTasks(from: issue.body ?? "")
        if !tasks.isEmpty {
            lines.append("## Tasks")
            lines.append("")
            for task in tasks {
                lines.append("- [ ] \(task)")
            }
            lines.append("")
        }

        lines.append("## Acceptance Criteria")
        lines.append("")
        lines.append("- [ ] All tests pass")
        lines.append("- [ ] Code review completed")
        lines.append("- [ ] No regressions introduced")
        lines.append("- [ ] Documentation updated (if needed)")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    public func generatePRD(from issues: [GitHubIssue]) -> String {
        var lines: [String] = []
        lines.append("# PRD: Combined Issues")
        lines.append("")
        lines.append("Generated: \(Date())")
        lines.append("Issues: \(issues.count)")
        lines.append("")

        for issue in issues {
            lines.append("---")
            lines.append("")
            lines.append(generatePRD(from: issue))
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    public func savePRD(content: String, issueNumber: Int) -> String {
        let filename = "PRD-\(issueNumber).md"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: path, atomically: true, encoding: .utf8)
        return path.path
    }

    private func extractTasks(from body: String) -> [String] {
        var tasks: [String] = []

        let checkboxPattern = "- \\[ \\] (.+)"
        if let regex = try? NSRegularExpression(pattern: checkboxPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: body, range: NSRange(body.startIndex..., in: body))
            for match in matches {
                if let range = Range(match.range(at: 1), in: body) {
                    let task = String(body[range]).trimmingCharacters(in: .whitespaces)
                    if !task.isEmpty {
                        tasks.append(task)
                    }
                }
            }
        }

        if tasks.isEmpty {
            let lines = body.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") ||
                    (trimmed.count > 2 && trimmed[trimmed.startIndex].isNumber && trimmed[trimmed.index(after: trimmed.startIndex)] == ".") {
                    let task = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !task.isEmpty {
                        tasks.append(task)
                    }
                }
            }
        }

        return tasks
    }
}
