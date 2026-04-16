import Foundation

struct GitHubIssue: Decodable, Sendable, Identifiable {
    let number: Int
    let title: String
    let body: String?
    let state: String
    let labels: [GitHubLabel]
    let assignees: [GitHubUser]
    let milestone: GitHubMilestoneRef?
    let pullRequest: GitHubPullRequestRef?
    let createdAt: String
    let updatedAt: String

    var id: Int { number }

    var isPullRequest: Bool {
        pullRequest != nil
    }

    enum CodingKeys: String, CodingKey {
        case number, title, body, state, labels, assignees, milestone
        case pullRequest = "pull_request"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubPullRequestRef: Decodable, Sendable {}

struct GitHubUser: Decodable, Sendable, Identifiable {
    let login: String

    var id: String { login }
}

struct GitHubMilestoneRef: Decodable, Sendable, Identifiable {
    let number: Int
    let title: String

    var id: Int { number }
}

struct GitHubLabel: Decodable, Sendable, Identifiable {
    let name: String

    var id: String { name }
}
