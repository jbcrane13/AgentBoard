import Foundation
import Testing
@testable import AgentBoard

@Suite("GitService Parser Tests")
struct GitServiceParserTests {
    @Test("parseCommitRecords parses git log output, sorts by date, and deduplicates bead IDs")
    func parseCommitRecordsParsesAndSorts() {
        let output = [
            "1111111111111111111111111111111111111111\u{1f}1111111\u{1f}1766000000\u{1f}AB-48z implement tests AB-48z\u{1f}(HEAD -> main, origin/main)\u{1e}",
            "2222222222222222222222222222222222222222\u{1f}2222222\u{1f}1765000000\u{1f}General maintenance\u{1f}\u{1e}",
        ].joined()

        let service = GitService()
        let commits = service.parseCommitRecords(from: output)

        #expect(commits.count == 2)
        #expect(commits[0].sha == "1111111111111111111111111111111111111111")
        #expect(commits[0].branch == "main")
        #expect(commits[0].beadIDs == ["AB-48z"])
        #expect(commits[0].authoredAt > commits[1].authoredAt)
        #expect(commits[1].branch == nil)
    }

    @Test("parseCommitRecords skips malformed rows")
    func parseCommitRecordsSkipsMalformedRows() {
        let malformed = "missing-fields\u{1e}"
        let valid = "3333333333333333333333333333333333333333\u{1f}3333333\u{1f}1764000000\u{1f}AB-12 patch\u{1f}(origin/release)\u{1e}"
        let output = malformed + valid

        let service = GitService()
        let commits = service.parseCommitRecords(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].sha == "3333333333333333333333333333333333333333")
        #expect(commits[0].branch == "origin/release")
        #expect(commits[0].beadIDs == ["AB-12"])
    }
}
