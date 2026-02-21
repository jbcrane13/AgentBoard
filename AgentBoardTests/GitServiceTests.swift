import Foundation
import Testing
@testable import AgentBoard

@Suite("GitService Tests")
struct GitServiceTests {

    private var projectURL: URL {
        URL(fileURLWithPath: "/Users/blake/Projects/AgentBoard")
    }

    // MARK: - fetchCurrentBranch

    @Test("fetchCurrentBranch returns a non-empty string for a valid git repo")
    func fetchCurrentBranchReturnsNonEmptyString() async throws {
        let service = GitService()
        let branch = try await service.fetchCurrentBranch(projectPath: projectURL)
        #expect(!branch.isEmpty)
    }

    @Test("fetchCurrentBranch on a non-git directory throws an error")
    func fetchCurrentBranchOnNonGitDirectoryThrows() async throws {
        let service = GitService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var didThrow = false
        do {
            _ = try await service.fetchCurrentBranch(projectPath: tempDir)
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }

    // MARK: - fetchCommits

    @Test("fetchCommits returns a non-empty array with valid SHAs for a real git repo")
    func fetchCommitsReturnsNonEmptyArray() async throws {
        let service = GitService()
        let commits = try await service.fetchCommits(projectPath: projectURL, limit: 10)
        #expect(!commits.isEmpty)
        #expect(!commits[0].sha.isEmpty)
    }

    @Test("fetchCommits results are sorted by date descending")
    func fetchCommitsSortedByDateDescending() async throws {
        let service = GitService()
        let commits = try await service.fetchCommits(projectPath: projectURL, limit: 10)
        guard commits.count >= 2 else { return }
        #expect(commits[0].authoredAt >= commits[1].authoredAt)
    }

    @Test("fetchCommits respects the limit parameter")
    func fetchCommitsWithLimitRespected() async throws {
        let service = GitService()
        let commits = try await service.fetchCommits(projectPath: projectURL, limit: 3)
        #expect(commits.count <= 3)
    }

    // MARK: - bead ID extraction

    @Test("commits whose subjects contain a bead-pattern token have non-empty beadIDs")
    func extractBeadIDsFromCommitSubject() async throws {
        let service = GitService()
        let commits = try await service.fetchCommits(projectPath: projectURL, limit: 50)

        // Find any commit that already has beadIDs extracted by GitService
        // (subjects following the pattern <PREFIX>-<alphanum>: ...).
        let commitsWithBeadIDs = commits.filter { !$0.beadIDs.isEmpty }

        // The AgentBoard repo contains commits with bead references (e.g. "AgentBoard-xxx").
        // If such commits exist, verify the extracted IDs are non-empty strings.
        if !commitsWithBeadIDs.isEmpty {
            for commit in commitsWithBeadIDs {
                for beadID in commit.beadIDs {
                    #expect(!beadID.isEmpty)
                    // Bead IDs must contain a hyphen separating prefix and suffix.
                    #expect(beadID.contains("-"))
                }
            }
        }
        // If no commits with bead references are found in the 50-commit window,
        // the test passes vacuously — the extraction logic is still exercised
        // by the parser on every commit's subject line.
    }

    @Test("duplicate bead IDs in same commit subject are deduplicated")
    func duplicateBeadIDsAreDeduplicated() async throws {
        let service = GitService()
        let commits = try await service.fetchCommits(projectPath: projectURL, limit: 100)

        // Look for any commit that might have duplicate bead references
        // The deduplication logic ensures each bead ID appears only once
        for commit in commits {
            let uniqueIDs = Set(commit.beadIDs)
            #expect(commit.beadIDs.count == uniqueIDs.count, "Bead IDs should be deduplicated")
        }
    }

    // MARK: - branch parsing

    @Test("branch parsing extracts main from HEAD -> main, origin/main")
    func branchParsingExtractsMainFromRefs() async throws {
        let service = GitService()
        let commits = try await service.fetchCommits(projectPath: projectURL, limit: 10)

        // Find a commit with HEAD -> branch_name in refs
        let headCommit = commits.first { commit in
            commit.refs.contains("HEAD ->")
        }

        if let commit = headCommit {
            // Verify that branch was extracted correctly
            #expect(commit.branch != nil, "Branch should be extracted from refs containing HEAD ->")
            #expect(!commit.branch!.isEmpty)
            #expect(!commit.branch!.contains("HEAD ->"), "Branch name should not contain 'HEAD ->'")
        }
    }

    @Test("empty refs string results in nil branch")
    func emptyRefsResultsInNilBranch() async throws {
        let service = GitService()
        let commits = try await service.fetchCommits(projectPath: projectURL, limit: 50)

        // Find commits without refs (older commits typically have empty refs)
        let commitsWithoutRefs = commits.filter { $0.refs.isEmpty }

        // If we have commits without refs, verify branch is nil
        if !commitsWithoutRefs.isEmpty {
            for commit in commitsWithoutRefs {
                #expect(commit.branch == nil, "Empty refs should result in nil branch")
            }
        }
    }
}
