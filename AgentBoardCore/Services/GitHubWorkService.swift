import Foundation

public struct GitHubIssuePatch: Sendable {
    public var title: String?
    public var body: String?
    public var labels: [String]?
    public var assignees: [String]?
    public var state: WorkState?

    public init(
        title: String? = nil,
        body: String? = nil,
        labels: [String]? = nil,
        assignees: [String]? = nil,
        state: WorkState? = nil
    ) {
        self.title = title
        self.body = body
        self.labels = labels
        self.assignees = assignees
        self.state = state
    }
}

public actor GitHubWorkService {
    public enum ServiceError: LocalizedError, Sendable {
        case unauthorized
        case notFound
        case rateLimited
        case serverError(Int)
        case invalidResponse
        case missingConfiguration

        public var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "GitHub token is invalid or missing."
            case .notFound:
                return "GitHub repository not found."
            case .rateLimited:
                return "GitHub API rate limit exceeded. Try again later."
            case let .serverError(code):
                return "GitHub server error (\(code))."
            case .invalidResponse:
                return "Unexpected response from GitHub API."
            case .missingConfiguration:
                return "GitHub repositories or token are not configured."
            }
        }
    }

    private struct RawIssue: Decodable, Sendable {
        let number: Int
        let title: String
        let body: String?
        let state: String
        let labels: [RawLabel]
        let assignees: [RawUser]
        let milestone: RawMilestone?
        let pullRequest: RawPullRequest?
        let createdAt: String
        let updatedAt: String

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

    private struct RawPullRequest: Decodable, Sendable {}
    private struct RawUser: Decodable, Sendable { let login: String }
    private struct RawLabel: Decodable, Sendable { let name: String }
    private struct RawMilestone: Decodable, Sendable {
        let number: Int
        let title: String
    }

    private let session: URLSession
    private var repositories: [ConfiguredRepository] = []
    private var token: String?

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func configure(
        repositories: [ConfiguredRepository],
        token: String?
    ) {
        self.repositories = repositories
        self.token = token?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    public func fetchWorkItems() async throws -> [WorkItem] {
        guard !repositories.isEmpty, let token, !token.isEmpty else {
            throw ServiceError.missingConfiguration
        }

        var mapped: [WorkItem] = []
        for repository in repositories {
            try mapped.append(contentsOf: await fetchIssues(for: repository, token: token))
        }

        return mapped.sorted { lhs, rhs in
            if lhs.priority.rank != rhs.priority.rank {
                return lhs.priority.rank < rhs.priority.rank
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public func updateIssue(
        repository: ConfiguredRepository,
        issueNumber: Int,
        patch: GitHubIssuePatch
    ) async throws -> WorkItem {
        guard let token, !token.isEmpty else {
            throw ServiceError.missingConfiguration
        }

        let url = try buildURL(repository: repository, endpoint: "issues/\(issueNumber)")
        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]
        if let title = patch.title { payload["title"] = title }
        if let body = patch.body { payload["body"] = body }
        if let labels = patch.labels { payload["labels"] = labels }
        if let assignees = patch.assignees { payload["assignees"] = assignees }
        if let state = patch.state { payload["state"] = state.githubState }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        let issue = try JSONDecoder().decode(RawIssue.self, from: data)
        return map(issue: issue, repository: repository)
    }

    private func fetchIssues(
        for repository: ConfiguredRepository,
        token: String
    ) async throws -> [WorkItem] {
        var page = 1
        var allIssues: [RawIssue] = []

        while true {
            let url = try buildURL(
                repository: repository,
                endpoint: "issues",
                queryItems: [
                    URLQueryItem(name: "state", value: "all"),
                    URLQueryItem(name: "per_page", value: "100"),
                    URLQueryItem(name: "page", value: "\(page)")
                ]
            )
            let (data, response) = try await session.data(for: authorizedRequest(url: url, token: token))
            try validateResponse(response, data: data)

            let issues = try JSONDecoder().decode([RawIssue].self, from: data)
            if issues.isEmpty { break }
            allIssues.append(contentsOf: issues)
            if issues.count < 100 { break }
            page += 1
        }

        return allIssues
            .filter { !$0.isPullRequest }
            .map { map(issue: $0, repository: repository) }
    }

    private func map(issue: RawIssue, repository: ConfiguredRepository) -> WorkItem {
        let labels = issue.labels.map(\.name)
        return WorkItem(
            repository: repository,
            issueNumber: issue.number,
            title: issue.title,
            bodySummary: bodySummary(from: issue.body),
            isClosed: issue.state == "closed",
            assignees: issue.assignees.map(\.login),
            milestone: issue.milestone.map { WorkMilestone(number: $0.number, title: $0.title) },
            labels: labels,
            status: derivedStatus(issueState: issue.state, labels: labels),
            priority: derivedPriority(labels: labels),
            agentHint: labels
                .first { $0.lowercased().hasPrefix("agent:") }
                .map { String($0.dropFirst("agent:".count)) },
            createdAt: parseDate(issue.createdAt),
            updatedAt: parseDate(issue.updatedAt)
        )
    }

    private func derivedStatus(issueState: String, labels: [String]) -> WorkState {
        if issueState == "closed" {
            return .done
        }

        for label in labels {
            switch label.lowercased() {
            case "status:blocked":
                return .blocked
            case "status:in-progress", "status:in_progress", "status:doing":
                return .inProgress
            case "status:done", "status:closed":
                return .done
            case "status:open", "status:ready":
                return .open
            default:
                continue
            }
        }

        return .open
    }

    private func derivedPriority(labels: [String]) -> WorkPriority {
        let normalized = labels.map { $0.lowercased() }
        if normalized.contains("priority:p0") || normalized.contains("priority:urgent") {
            return .critical
        }
        if normalized.contains("priority:p1") || normalized.contains("priority:high") {
            return .high
        }
        if normalized.contains("priority:p3") || normalized.contains("priority:low") {
            return .low
        }
        return .medium
    }

    private func bodySummary(from body: String?) -> String {
        guard let body else { return "" }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let firstLine = trimmed
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            ?? trimmed
        return String(firstLine.prefix(240))
    }

    private func parseDate(_ rawValue: String) -> Date {
        ISO8601DateFormatter().date(from: rawValue) ?? .now
    }

    private func buildURL(
        repository: ConfiguredRepository,
        endpoint: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        var components =
            URLComponents(string: "https://api.github.com/repos/\(repository.owner)/\(repository.name)/\(endpoint)")
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else {
            throw ServiceError.invalidResponse
        }
        return url
    }

    private func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AgentBoard", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""

        switch httpResponse.statusCode {
        case 200 ... 299:
            return
        case 401 where responseBody.contains("rate limit"),
             403 where responseBody.contains("rate limit"):
            throw ServiceError.rateLimited
        case 401:
            throw ServiceError.unauthorized
        case 404:
            throw ServiceError.notFound
        default:
            throw ServiceError.serverError(httpResponse.statusCode)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
