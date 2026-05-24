import Foundation

/// Canonical issue types used as GitHub labels.
public enum IssueType: String, Codable, CaseIterable, Identifiable, Sendable {
    case bug
    case feature
    case task
    case epic
    case chore

    public var id: String {
        rawValue
    }

    public var title: String {
        rawValue.capitalized
    }

    public var labelValue: String {
        "type:\(rawValue)"
    }
}

/// Known agent names used as GitHub labels and task assignees.
public enum AgentName: String, Codable, CaseIterable, Identifiable, Sendable {
    case daneel
    case quentin
    case friend
    case argus
    case dessin

    public var id: String {
        rawValue
    }

    public var title: String {
        rawValue.capitalized
    }

    public var labelValue: String {
        "agent:\(rawValue)"
    }
}
