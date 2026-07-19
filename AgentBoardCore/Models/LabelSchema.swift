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

    /// GitHub login to set in the issue's `assignees` field for this agent (issue #12).
    /// Every agent operates under the repo owner's account — GitHub only accepts
    /// assignees with repo access, and agent identity is carried by the `agent:` label.
    public var githubUsername: String {
        "jbcrane13"
    }

    /// Assignees array to send in an issue create/update for a picked agent,
    /// given the issue's current assignees. `nil` means leave the field
    /// untouched (issue #12 edge cases): no agent picked must not clear
    /// assignees set outside the app, and picking one must merge — not
    /// replace — the existing list. GitHub logins compare case-insensitively.
    public static func assigneesPatch(for agent: AgentName?, existing: [String]) -> [String]? {
        guard let agent else { return nil }
        let username = agent.githubUsername
        let alreadyAssigned = existing.contains {
            $0.caseInsensitiveCompare(username) == .orderedSame
        }
        return alreadyAssigned ? existing : existing + [username]
    }
}
