import Foundation

struct BeadDraft: Sendable {
    var title: String = ""
    var description: String = ""
    var kind: BeadKind = .task
    var status: BeadStatus = .open
    var priority: Int = 2
    var assignee: String = ""
    var labelsText: String = ""
    var epicId: String?

    var labels: [String] {
        labelsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func from(_ bead: Bead) -> BeadDraft {
        BeadDraft(
            title: bead.title,
            description: bead.body ?? "",
            kind: bead.kind,
            status: bead.status,
            priority: bead.priority,
            assignee: bead.assignee ?? "",
            labelsText: bead.labels.joined(separator: ", "),
            epicId: bead.epicId
        )
    }
}
