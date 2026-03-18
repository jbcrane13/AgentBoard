import Foundation

/// An issue from a specific GitHub-backed project, bundled with project metadata.
struct CrossRepoIssue: Identifiable, Sendable {
    let bead: Bead
    let projectName: String
    let owner: String
    let repo: String

    var id: String {
        "\(owner)/\(repo)/\(bead.id)"
    }
}

extension CrossRepoIssue {
    /// True if the issue is open and not carrying a status:blocked label.
    var isReady: Bool {
        guard bead.status == .open else { return false }
        return !bead.labels.contains { $0.lowercased().hasPrefix("status:blocked") || $0.lowercased() == "blocked" }
    }

    /// Extracts the agent name from an "agent:…" label, if present.
    var assignedAgent: String? {
        bead.labels
            .first { $0.lowercased().hasPrefix("agent:") }
            .map { String($0.dropFirst("agent:".count)).trimmingCharacters(in: .whitespaces) }
            ?? bead.assignee
    }
}
