import Foundation

enum HistoryEventType: String, CaseIterable, Hashable, Sendable {
    case beadCreated
    case beadStatus
    case sessionStarted
    case sessionCompleted
    case commit

    var label: String {
        switch self {
        case .beadCreated:
            return "Bead Created"
        case .beadStatus:
            return "Bead Status"
        case .sessionStarted:
            return "Session Started"
        case .sessionCompleted:
            return "Session Completed"
        case .commit:
            return "Commit"
        }
    }

    var symbolName: String {
        switch self {
        case .beadCreated:
            return "plus.circle"
        case .beadStatus:
            return "arrow.triangle.2.circlepath"
        case .sessionStarted:
            return "play.circle"
        case .sessionCompleted:
            return "checkmark.circle"
        case .commit:
            return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

struct HistoryEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    let occurredAt: Date
    let type: HistoryEventType
    let title: String
    let details: String?
    let projectName: String?
    let beadID: String?
    let commitSHA: String?

    init(
        id: UUID = UUID(),
        occurredAt: Date,
        type: HistoryEventType,
        title: String,
        details: String? = nil,
        projectName: String? = nil,
        beadID: String? = nil,
        commitSHA: String? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.type = type
        self.title = title
        self.details = details
        self.projectName = projectName
        self.beadID = beadID
        self.commitSHA = commitSHA
    }
}
