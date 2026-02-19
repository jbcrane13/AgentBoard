import Foundation

struct JSONLParser {
    private static let decoder = JSONDecoder()

    func parseBeads(from fileURL: URL) throws -> [Bead] {
        let data = try Data(contentsOf: fileURL)
        guard let rawText = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = rawText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let records = lines.compactMap { line -> RawIssue? in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? Self.decoder.decode(RawIssue.self, from: lineData)
        }

        let typeByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.issueType ?? "task") })

        return records
            .map { record in
                let status = BeadStatus.fromBeads(record.status)
                let kind = BeadKind.fromBeads(record.issueType)
                let createdAt = DateParser.parse(record.createdAt) ?? .distantPast
                let updatedAt = DateParser.parse(record.updatedAt) ?? createdAt
                let dependencyIDs = (record.dependencies ?? []).map(\.dependsOnID)
                let epicId = record.dependencies?
                    .first(where: { dependency in
                        guard dependency.type == "parent-child" else { return false }
                        return BeadKind.fromBeads(typeByID[dependency.dependsOnID]) == .epic
                    })?
                    .dependsOnID

                return Bead(
                    id: record.id,
                    title: record.title,
                    body: record.description,
                    status: status,
                    kind: kind,
                    priority: record.priority ?? 2,
                    epicId: epicId,
                    labels: record.labels ?? [],
                    assignee: record.owner,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    dependencies: dependencyIDs,
                    gitBranch: nil,
                    lastCommit: nil
                )
            }
            .sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
    }
}

private struct RawIssue: Decodable {
    let id: String
    let title: String
    let description: String?
    let status: String
    let issueType: String?
    let priority: Int?
    let labels: [String]?
    let owner: String?
    let createdAt: String?
    let updatedAt: String?
    let dependencies: [RawDependency]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case status
        case issueType = "issue_type"
        case priority
        case labels
        case owner
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case dependencies
    }
}

private struct RawDependency: Decodable {
    let dependsOnID: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case dependsOnID = "depends_on_id"
        case type
    }
}

private enum DateParser {
    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: raw) {
            return date
        }

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        return withoutFractional.date(from: raw)
    }
}
