import Foundation

// MARK: - Error Types

enum GitHubError: LocalizedError, Sendable {
    case unauthorized
    case notFound
    case rateLimited
    case serverError(Int)
    case invalidResponse
    case missingConfig

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "GitHub token is invalid or missing."
        case .notFound: return "GitHub repository not found."
        case .rateLimited: return "GitHub API rate limit exceeded. Try again later."
        case let .serverError(code): return "GitHub server error (\(code))."
        case .invalidResponse: return "Unexpected response from GitHub API."
        case .missingConfig: return "GitHub owner/repo not configured for this project."
        }
    }
}

// MARK: - Raw GitHub Issue (Decodable from API)

private struct GitHubIssue: Decodable, Sendable {
    let number: Int
    let title: String
    let body: String?
    let state: String
    let labels: [GitHubLabel]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case number, title, body, state, labels
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct GitHubLabel: Decodable, Sendable {
    let name: String
}

// MARK: - GitHub Milestone (public, used by UI)

struct GitHubMilestone: Decodable, Sendable, Identifiable {
    let number: Int
    let title: String
    let openIssues: Int
    let closedIssues: Int
    let dueOn: String?

    var id: Int {
        number
    }

    var totalIssues: Int {
        openIssues + closedIssues
    }

    var progress: Double {
        totalIssues > 0 ? Double(closedIssues) / Double(totalIssues) : 0
    }

    enum CodingKeys: String, CodingKey {
        case number, title
        case openIssues = "open_issues"
        case closedIssues = "closed_issues"
        case dueOn = "due_on"
    }
}

// MARK: - GitHubIssuesService

/// Fetches and mutates GitHub Issues for a project, mapping them to the Bead model.
/// Inject a custom URLSession in tests via URLProtocol mock.
actor GitHubIssuesService {
    private let session: URLSession
    private let baseURL = "https://api.github.com"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Fetch All Issues

    func fetchIssues(owner: String, repo: String, token: String) async throws -> [Bead] {
        var allIssues: [GitHubIssue] = []
        var page = 1

        while true {
            let url = try buildURL(
                owner: owner,
                repo: repo,
                endpoint: "issues",
                queryItems: [
                    URLQueryItem(name: "state", value: "all"),
                    URLQueryItem(name: "per_page", value: "100"),
                    URLQueryItem(name: "page", value: "\(page)")
                ]
            )
            let (data, response) = try await session.data(for: authorizedRequest(url: url, token: token))
            try validateResponse(response, data: data)

            let issues = try JSONDecoder().decode([GitHubIssue].self, from: data)
            if issues.isEmpty { break }
            allIssues.append(contentsOf: issues)
            if issues.count < 100 { break }
            page += 1
        }

        return allIssues.map { mapToBead($0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Create Issue

    // swiftlint:disable:next function_parameter_count
    func createIssue(
        owner: String, repo: String, token: String,
        title: String, body: String?, labels: [String]
    ) async throws -> Bead {
        let url = try buildURL(owner: owner, repo: repo, endpoint: "issues")
        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = ["title": title]
        if let body { payload["body"] = body }
        if !labels.isEmpty { payload["labels"] = labels }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try mapToBead(JSONDecoder().decode(GitHubIssue.self, from: data))
    }

    // MARK: - Update Issue

    // swiftlint:disable:next function_parameter_count
    func updateIssue(
        owner: String, repo: String, token: String,
        number: Int, title: String?, body: String?, labels: [String]?, state: String?
    ) async throws -> Bead {
        let url = try buildURL(owner: owner, repo: repo, endpoint: "issues/\(number)")
        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]
        if let title { payload["title"] = title }
        if let body { payload["body"] = body }
        if let labels { payload["labels"] = labels }
        if let state { payload["state"] = state }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try mapToBead(JSONDecoder().decode(GitHubIssue.self, from: data))
    }

    // MARK: - Close Issue

    func closeIssue(owner: String, repo: String, token: String, number: Int, comment: String? = nil) async throws {
        if let comment, !comment.isEmpty {
            try await addComment(owner: owner, repo: repo, token: token, number: number, body: comment)
        }
        _ = try await updateIssue(
            owner: owner,
            repo: repo,
            token: token,
            number: number,
            title: nil,
            body: nil,
            labels: nil,
            state: "closed"
        )
    }

    // MARK: - Add Comment

    private func addComment(owner: String, repo: String, token: String, number: Int, body: String) async throws {
        let url = try buildURL(owner: owner, repo: repo, endpoint: "issues/\(number)/comments")
        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["body": body])
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Fetch Milestones

    func fetchMilestones(owner: String, repo: String, token: String) async throws -> [GitHubMilestone] {
        let url = try buildURL(
            owner: owner, repo: repo, endpoint: "milestones",
            queryItems: [
                URLQueryItem(name: "state", value: "open"),
                URLQueryItem(name: "per_page", value: "100")
            ]
        )
        let (data, response) = try await session.data(for: authorizedRequest(url: url, token: token))
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([GitHubMilestone].self, from: data)
    }

    // MARK: - Helpers

    private func buildURL(
        owner: String, repo: String, endpoint: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        var components = URLComponents(string: "\(baseURL)/repos/\(owner)/\(repo)/\(endpoint)")!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw GitHubError.invalidResponse }
        return url
    }

    private func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }

    private func validateResponse(_ response: URLResponse, data _: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        switch http.statusCode {
        case 200 ... 299: return
        case 401: throw GitHubError.unauthorized
        case 403: throw GitHubError.rateLimited
        case 404: throw GitHubError.notFound
        case 500 ... 599: throw GitHubError.serverError(http.statusCode)
        default: throw GitHubError.serverError(http.statusCode)
        }
    }

    // MARK: - GH Issue → Bead Mapping

    private func mapToBead(_ issue: GitHubIssue) -> Bead {
        let labelNames = issue.labels.map(\.name)

        let kind: BeadKind = {
            for label in labelNames {
                switch label.lowercased() {
                case "bug": return .bug
                case "feature", "enhancement": return .feature
                case "epic": return .epic
                case "chore": return .chore
                default: continue
                }
            }
            return .task
        }()

        let priority: Int = {
            for label in labelNames {
                let lower = label.lowercased()
                if lower == "priority:critical" || lower == "p0" { return 0 }
                if lower == "priority:high" || lower == "p1" { return 1 }
                if lower == "priority:medium" || lower == "p2" { return 2 }
                if lower == "priority:low" || lower == "p3" { return 3 }
                if lower == "priority:backlog" || lower == "p4" { return 4 }
            }
            return 2
        }()

        let status: BeadStatus = issue.state == "closed" ? .done : .open

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        func parseDate(_ raw: String) -> Date {
            withFractional.date(from: raw) ?? withoutFractional.date(from: raw) ?? .distantPast
        }

        return Bead(
            id: "GH-\(issue.number)",
            title: issue.title,
            body: issue.body,
            status: status,
            kind: kind,
            priority: priority,
            epicId: nil,
            labels: labelNames,
            assignee: nil,
            createdAt: parseDate(issue.createdAt),
            updatedAt: parseDate(issue.updatedAt),
            dependencies: [],
            gitBranch: nil,
            lastCommit: nil
        )
    }

    /// Parse "GH-123" → 123. Returns nil if not a GH issue ID.
    static func issueNumber(from beadID: String) -> Int? {
        guard beadID.hasPrefix("GH-"),
              let number = Int(beadID.dropFirst(3)) else { return nil }
        return number
    }
}
