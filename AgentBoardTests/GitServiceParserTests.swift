import Foundation
import Testing
@testable import AgentBoard

@Suite("GitService Parser Tests")
struct GitServiceParserTests {
    @Test("parseCommitRecords parses git log output, sorts by date, and deduplicates bead IDs")
    func parseCommitRecordsParsesAndSorts() async {
        let output = [
            "1111111111111111111111111111111111111111\u{1f}1111111\u{1f}1766000000\u{1f}AB-48z implement tests AB-48z\u{1f}(HEAD -> main, origin/main)\u{1e}",
            "2222222222222222222222222222222222222222\u{1f}2222222\u{1f}1765000000\u{1f}General maintenance\u{1f}\u{1e}"
        ].joined()

        let service = GitService()
        let commits = await service.parseCommitRecords(from: output)

        #expect(commits.count == 2)
        #expect(commits[0].sha == "1111111111111111111111111111111111111111")
        #expect(commits[0].branch == "main")
        #expect(commits[0].beadIDs == ["AB-48z"])
        #expect(commits[0].authoredAt > commits[1].authoredAt)
        #expect(commits[1].branch == nil)
    }

    @Test("parseCommitRecords skips malformed rows")
    func parseCommitRecordsSkipsMalformedRows() async {
        let malformed = "missing-fields\u{1e}"
        let valid = "3333333333333333333333333333333333333333\u{1f}3333333\u{1f}1764000000\u{1f}AB-12 patch\u{1f}(origin/release)\u{1e}"
        let output = malformed + valid

        let service = GitService()
        let commits = await service.parseCommitRecords(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].sha == "3333333333333333333333333333333333333333")
        #expect(commits[0].branch == "origin/release")
        #expect(commits[0].beadIDs == ["AB-12"])
    }

    @Test("parseCommitRecords with tag ref plus branch ref prefers branch over tag")
    func parseCommitRecordsTagPlusBranchPrefersBranch() async {
        // refs = "(tag: v1.0, origin/main)" → first non-tag ref is "origin/main"
        let output = "4444444444444444444444444444444444444444\u{1f}4444444\u{1f}1763000000\u{1f}Release v1.0\u{1f}(tag: v1.0, origin/main)\u{1e}"

        let service = GitService()
        let commits = await service.parseCommitRecords(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].branch == "origin/main")
    }

    @Test("parseCommitRecords with only a tag ref uses the tag as branch")
    func parseCommitRecordsTagOnlyUsesTag() async {
        let output = "5555555555555555555555555555555555555555\u{1f}5555555\u{1f}1762000000\u{1f}Tag-only commit\u{1f}(tag: v2.0)\u{1e}"

        let service = GitService()
        let commits = await service.parseCommitRecords(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].branch == "tag: v2.0")
    }

    @Test("parseCommitRecords with empty refs produces nil branch")
    func parseCommitRecordsEmptyRefsNilBranch() async {
        let output = "6666666666666666666666666666666666666666\u{1f}6666666\u{1f}1761000000\u{1f}No refs commit\u{1f}\u{1e}"

        let service = GitService()
        let commits = await service.parseCommitRecords(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].branch == nil)
    }

    @Test("parseCommitRecords extracts bead IDs with dot suffixes like AB-48z.1")
    func parseCommitRecordsBeadIDsWithDotSuffix() async {
        let output = "7777777777777777777777777777777777777777\u{1f}7777777\u{1f}1760000000\u{1f}fix: update AB-48z.1 and AB-48z.3\u{1f}\u{1e}"

        let service = GitService()
        let commits = await service.parseCommitRecords(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].beadIDs.contains("AB-48z.1"))
        #expect(commits[0].beadIDs.contains("AB-48z.3"))
    }

    @Test("parseCommitRecords deduplicates repeated bead IDs in same subject")
    func parseCommitRecordsDeduplicatesBeadIDs() async {
        let output = "8888888888888888888888888888888888888888\u{1f}8888888\u{1f}1759000000\u{1f}AB-99x close AB-99x per review AB-99x\u{1f}\u{1e}"

        let service = GitService()
        let commits = await service.parseCommitRecords(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].beadIDs == ["AB-99x"])
    }

    @Test("parseCommitRecords with HEAD -> branch plus remote origin extracts local branch name")
    func parseCommitRecordsHeadBranchStrippedCorrectly() async {
        let output = "9999999999999999999999999999999999999999\u{1f}9999999\u{1f}1758000000\u{1f}feat: add tests\u{1f}(HEAD -> feature/tests, origin/feature/tests)\u{1e}"

        let service = GitService()
        let commits = await service.parseCommitRecords(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].branch == "feature/tests")
    }

    @Test("parseCommitRecords returns empty array for empty input")
    func parseCommitRecordsEmptyInput() async {
        let service = GitService()
        let commits = await service.parseCommitRecords(from: "")
        #expect(commits.isEmpty)
    }
}
