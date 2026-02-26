import Foundation
import SwiftUI

struct Bead: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let body: String?
    let status: BeadStatus
    let kind: BeadKind
    let priority: Int
    let epicId: String?
    let labels: [String]
    let assignee: String?
    let createdAt: Date
    let updatedAt: Date
    let dependencies: [String]
    let gitBranch: String?
    let lastCommit: String?
}

enum BeadStatus: String, Codable, CaseIterable, Sendable {
    case open
    case inProgress = "in-progress"
    case blocked
    case done

    static func fromBeads(_ rawValue: String) -> BeadStatus {
        switch rawValue.lowercased() {
        case "in_progress", "in-progress":
            return .inProgress
        case "blocked":
            return .blocked
        case "done", "closed":
            return .done
        case "open":
            return .open
        default:
            return .open
        }
    }

    var beadsValue: String {
        switch self {
        case .open:
            return "open"
        case .inProgress:
            return "in_progress"
        case .blocked:
            return "blocked"
        case .done:
            return "closed"
        }
    }
}

enum BeadKind: String, Codable, CaseIterable, Sendable {
    case task
    case bug
    case feature
    case epic
    case chore

    static func fromBeads(_ rawValue: String?) -> BeadKind {
        switch rawValue?.lowercased() {
        case "bug":
            return .bug
        case "feature", "enhancement":
            return .feature
        case "epic":
            return .epic
        case "chore":
            return .chore
        default:
            return .task
        }
    }

    var beadsValue: String {
        switch self {
        case .task:
            return "task"
        case .bug:
            return "bug"
        case .feature:
            return "feature"
        case .epic:
            return "epic"
        case .chore:
            return "chore"
        }
    }
}

extension BeadKind {
    var color: Color {
        switch self {
        case .task: .blue
        case .bug: .red
        case .feature: .green
        case .epic: .purple
        case .chore: .gray
        }
    }
}

func priorityColor(for priority: Int) -> Color {
    switch priority {
    case 0: .red
    case 1: .orange
    case 2: .yellow
    case 3: .blue
    default: .gray
    }
}

extension Bead {
    static let samples: [Bead] = [
        Bead(id: "NM-098", title: "Create ConnectionBudget actor for global NWConnection cap",
             body: nil, status: .open, kind: .task, priority: 2, epicId: nil, labels: [],
             assignee: nil, createdAt: .now.addingTimeInterval(-3600),
             updatedAt: .now.addingTimeInterval(-3600), dependencies: [],
             gitBranch: nil, lastCommit: nil),
        Bead(id: "NM-095", title: "Add Wi-Fi signal strength overlay to map view",
             body: nil, status: .open, kind: .feature, priority: 3, epicId: nil, labels: [],
             assignee: nil, createdAt: .now.addingTimeInterval(-86400),
             updatedAt: .now.addingTimeInterval(-86400), dependencies: [],
             gitBranch: nil, lastCommit: nil),
        Bead(id: "NM-093", title: "Accessibility audit — VoiceOver labels for scan results",
             body: nil, status: .open, kind: .task, priority: 2, epicId: nil, labels: [],
             assignee: nil, createdAt: .now.addingTimeInterval(-172800),
             updatedAt: .now.addingTimeInterval(-172800), dependencies: [],
             gitBranch: nil, lastCommit: nil),
        Bead(id: "NM-096", title: "Implement NWPathMonitor integration for real-time status",
             body: nil, status: .inProgress, kind: .task, priority: 1, epicId: nil, labels: [],
             assignee: "claude-code", createdAt: .now.addingTimeInterval(-7200),
             updatedAt: .now.addingTimeInterval(-1800), dependencies: [],
             gitBranch: "feat/nwpath-monitor", lastCommit: "a3f2c1d"),
        Bead(id: "NM-094", title: "XCUITest suite for network scan flow",
             body: nil, status: .inProgress, kind: .task, priority: 2, epicId: nil, labels: [],
             assignee: "claude-code", createdAt: .now.addingTimeInterval(-43200),
             updatedAt: .now.addingTimeInterval(-3600), dependencies: [],
             gitBranch: "test/scan-ui-tests", lastCommit: "b7e4a09"),
        Bead(id: "NM-092", title: "SwiftData model for scan history persistence",
             body: nil, status: .done, kind: .task, priority: 2, epicId: nil, labels: [],
             assignee: nil, createdAt: .now.addingTimeInterval(-259200),
             updatedAt: .now.addingTimeInterval(-172800), dependencies: [],
             gitBranch: nil, lastCommit: "c1d9f32"),
        Bead(id: "NM-091", title: "Fix crash on background NWConnection timeout",
             body: nil, status: .done, kind: .bug, priority: 0, epicId: nil, labels: [],
             assignee: nil, createdAt: .now.addingTimeInterval(-345600),
             updatedAt: .now.addingTimeInterval(-259200), dependencies: [],
             gitBranch: nil, lastCommit: "d4e8b21"),
    ]
}
