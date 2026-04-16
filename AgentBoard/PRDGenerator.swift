import Foundation

/// Generates lightweight PRD markdown from GitHub issues.
final class PRDGenerator: Sendable {
    init() {}

    func generatePRD(from issue: Bead, childIssues: [Bead] = []) -> String {
        var lines: [String] = []

        lines.append("# \(issue.id): \(issue.title)")
        lines.append("")
        lines.append("## Context")
        lines.append("")
        lines.append("- **Issue:** \(issue.id)")

        if !issue.labels.isEmpty {
            lines.append("- **Labels:** \(issue.labels.joined(separator: ", "))")
        }
        if let milestoneTitle = issue.milestoneTitle {
            lines.append("- **Milestone:** \(milestoneTitle)")
        }
        if let assignee = issue.assignee, !assignee.isEmpty {
            lines.append("- **Assignee:** \(assignee)")
        }

        lines.append("- **Status:** \(issue.status.rawValue)")
        lines.append("")

        if let body = issue.body, !body.isEmpty {
            lines.append("## Description")
            lines.append("")
            lines.append(body)
            lines.append("")
        }

        if !childIssues.isEmpty {
            lines.append("## Child issues")
            lines.append("")
            for childIssue in childIssues {
                let checkbox = childIssue.status == .done ? "x" : " "
                lines.append("- [\(checkbox)] \(childIssue.id): \(childIssue.title)")
            }
            lines.append("")
        }

        let tasks = childIssues.isEmpty ? extractTasks(from: issue.body ?? "") : []
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

    func generatePRD(from issue: GitHubIssue) -> String {
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

    func generatePRD(from epic: Epic) -> String {
        var lines: [String] = []

        lines.append("# \(epic.id): \(epic.title)")
        lines.append("")
        lines.append("## Context")
        lines.append("")
        lines.append("- **Issue:** \(epic.id)")
        if let assignee = epic.assignee, !assignee.isEmpty {
            lines.append("- **Assignee:** \(assignee)")
        }
        if !epic.tags.isEmpty {
            lines.append("- **Tags:** \(epic.tags.joined(separator: ", "))")
        }
        lines.append("- **Status:** \(epic.status.rawValue)")
        lines.append("")

        if let description = epic.description, !description.isEmpty {
            lines.append("## Description")
            lines.append("")
            lines.append(description)
            lines.append("")
        }

        if !epic.subtasks.isEmpty {
            lines.append("## Tasks")
            lines.append("")
            for subtask in epic.subtasks {
                let checkbox = subtask.status == .done ? "x" : " "
                lines.append("- [\(checkbox)] \(subtask.title)")
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

    func generatePRD(from issues: [GitHubIssue]) -> String {
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
