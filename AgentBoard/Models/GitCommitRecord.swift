import Foundation

struct GitCommitRecord: Identifiable, Hashable, Sendable {
    let sha: String
    let shortSHA: String
    let authoredAt: Date
    let subject: String
    let refs: String
    let branch: String?
    let beadIDs: [String]

    var id: String { sha }
}

struct BeadGitSummary: Hashable, Sendable {
    let beadID: String
    let latestCommit: GitCommitRecord
    let commitCount: Int
}
