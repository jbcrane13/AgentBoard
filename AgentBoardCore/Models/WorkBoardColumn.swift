import Foundation

/// Presentation-only grouping of `WorkState` into the three columns shown on the
/// Work board. `WorkState` (and the `status:*` label schema) remains the domain
/// truth; this enum exists purely to simplify the board from five states to three
/// columns without touching labels, CLI workflows, or agent tooling.
public enum WorkBoardColumn: String, CaseIterable, Identifiable, Sendable {
    case todo
    case inProgress
    case resolved

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .todo: "To Do"
        case .inProgress: "In Progress"
        case .resolved: "Resolved"
        }
    }

    /// Which column a card renders in for a given `WorkState`.
    public static func column(for state: WorkState) -> WorkBoardColumn {
        switch state {
        case .ready: .todo
        case .inProgress, .review, .blocked: .inProgress
        case .done: .resolved
        }
    }

    /// The `WorkState` a drop onto this column requests via `WorkStore.updateStatus`.
    public var dropTargetState: WorkState {
        switch self {
        case .todo: .ready
        case .inProgress: .inProgress
        case .resolved: .done
        }
    }
}
