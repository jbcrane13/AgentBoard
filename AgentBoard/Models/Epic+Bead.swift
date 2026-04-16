import Foundation

extension Epic {
    init(bead: Bead) {
        let subtasks = Self.extractSubtasks(from: bead.body)
        self.init(
            id: bead.id,
            title: bead.title,
            description: bead.body,
            priority: Priority(intValue: bead.priority),
            status: Self.mapStatus(bead.status),
            subtasks: subtasks,
            assignee: bead.assignee,
            tags: bead.labels
        )
    }

    private static func mapStatus(_ status: BeadStatus) -> TaskStatus {
        switch status {
        case .open: return .todo
        case .inProgress: return .inProgress
        case .blocked: return .blocked
        case .done: return .done
        }
    }

    private static func extractSubtasks(from body: String?) -> [Subtask] {
        guard let body, !body.isEmpty else { return [] }
        var result: [Subtask] = []
        let checkboxPattern = #"- \[( |x|X)\] (.+)"#
        if let regex = try? NSRegularExpression(pattern: checkboxPattern) {
            let matches = regex.matches(in: body, range: NSRange(body.startIndex..., in: body))
            for match in matches {
                guard
                    let statusRange = Range(match.range(at: 1), in: body),
                    let titleRange = Range(match.range(at: 2), in: body)
                else { continue }
                let completed = body[statusRange].lowercased() == "x"
                let title = String(body[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                result.append(Subtask(title: title, status: completed ? .done : .todo))
            }
        }
        return result
    }
}
