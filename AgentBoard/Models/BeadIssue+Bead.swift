import Foundation

extension BeadIssue {
    init(bead: Bead) {
        let bodyText = bead.body ?? ""
        let extractedTasks = Self.extractTasks(from: bodyText)
        let extractedCriteria = Self.defaultCriteria(for: bead)

        self.init(
            beadId: bead.id,
            title: bead.title,
            description: bodyText.isEmpty ? bead.title : bodyText,
            context: [
                "Issue ID: \(bead.id)",
                "Status: \(bead.status.rawValue)",
                "Kind: \(bead.kind.rawValue)",
                bead.assignee.map { "Assignee: \($0)" },
                bead.milestoneTitle.map { "Milestone: \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: "\n"),
            tasks: extractedTasks,
            acceptanceCriteria: extractedCriteria,
            priority: Priority(intValue: bead.priority)
        )
    }

    private static func extractTasks(from body: String) -> [IssueTask] {
        guard !body.isEmpty else { return [] }
        var tasks: [IssueTask] = []

        let checkboxPattern = #"- \[( |x|X)\] (.+)"#
        if let regex = try? NSRegularExpression(pattern: checkboxPattern) {
            let matches = regex.matches(in: body, range: NSRange(body.startIndex..., in: body))
            for match in matches {
                guard
                    let statusRange = Range(match.range(at: 1), in: body),
                    let titleRange = Range(match.range(at: 2), in: body)
                else { continue }
                let isCompleted = body[statusRange].lowercased() == "x"
                let title = String(body[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    tasks.append(IssueTask(title: title, isCompleted: isCompleted))
                }
            }
        }

        return tasks
    }

    private static func defaultCriteria(for bead: Bead) -> [AcceptanceCriterion] {
        [
            AcceptanceCriterion(description: "Issue can be moved forward without regressions"),
            AcceptanceCriterion(description: "Relevant status/assignee data is preserved for #\(bead.id)")
        ]
    }
}
