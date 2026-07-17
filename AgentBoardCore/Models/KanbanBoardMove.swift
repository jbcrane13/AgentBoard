import Foundation

/// Legal semantic transitions the agent board can request from `hermes kanban`.
/// Hermes has no generic "set status" — only these named transitions exist, so
/// a drag-and-drop drop must map onto one of them or be rejected.
public enum KanbanBoardMove: Equatable, Sendable {
    case promote // triage/todo → ready
    case block // any non-terminal → blocked
    case unblock // blocked → ready
    case complete // any non-terminal → done

    /// The legal move for a drag from `from` to `to`, or `nil` if the drop
    /// is not a legal user-initiated transition.
    public static func forDrag(from: KanbanStatus, to: KanbanStatus) -> KanbanBoardMove? {
        guard from != to else { return nil }
        guard from != .done else { return nil }

        switch to {
        case .done:
            return .complete
        case .blocked:
            return .block
        case .ready:
            switch from {
            case .blocked: return .unblock
            case .triage, .todo: return .promote
            default: return nil
            }
        default:
            return nil
        }
    }

    /// Human explanation for a rejected drop.
    public static func rejectionMessage(from: KanbanStatus, to: KanbanStatus) -> String {
        switch to {
        case .running:
            return "Tasks enter Running when an agent claims them."
        case .triage, .todo, .archived:
            return "Tasks can't be dragged to \(to.title)."
        default:
            if from == to {
                return "Task is already in \(to.title)."
            }
            if from == .done {
                return "Completed tasks can't be moved."
            }
            return "That move isn't supported."
        }
    }
}
