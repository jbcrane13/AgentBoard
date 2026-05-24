import AgentBoardCore
import Foundation
import Testing

@Suite("FoundationExtras")
struct FoundationExtrasTests {
    // MARK: - String.trimmedOrNil

    @Test func trimmedOrNilReturnsNilForEmptyString() {
        #expect("".trimmedOrNil == nil)
    }

    @Test func trimmedOrNilReturnsNilForWhitespaceOnly() {
        #expect("   ".trimmedOrNil == nil)
        #expect("\n\t".trimmedOrNil == nil)
        #expect(" \r\n  ".trimmedOrNil == nil)
    }

    @Test func trimmedOrNilStripsLeadingAndTrailingWhitespace() {
        #expect("  hello  ".trimmedOrNil == "hello")
        #expect("\n\thello\n".trimmedOrNil == "hello")
    }

    @Test func trimmedOrNilPreservesInternalWhitespace() {
        #expect("hello world".trimmedOrNil == "hello world")
        #expect("  a b  c  ".trimmedOrNil == "a b  c")
    }

    // MARK: - String.trimmed

    @Test func trimmedReturnsEmptyStringForWhitespaceOnly() {
        #expect("   ".trimmed.isEmpty)
    }

    @Test func trimmedStripsBothEnds() {
        #expect("\thello\n".trimmed == "hello")
    }

    // MARK: - Sequence<String>.sortedCaseInsensitive

    @Test func sortedCaseInsensitiveProducesAlphabeticalOrderRegardlessOfCase() {
        let input = ["Banana", "apple", "Cherry", "ant"]
        let sorted = input.sortedCaseInsensitive()
        #expect(sorted == ["ant", "apple", "Banana", "Cherry"])
    }

    @Test func sortedCaseInsensitiveLeavesAlreadySortedInputAlone() {
        let input = ["alpha", "beta", "gamma"]
        #expect(input.sortedCaseInsensitive() == input)
    }

    @Test func sortedCaseInsensitiveHandlesDuplicates() {
        let input = ["foo", "FOO", "bar", "Bar"]
        let sorted = input.sortedCaseInsensitive()
        // "bar" cluster precedes "foo" cluster — original order preserved within ties.
        #expect(sorted.prefix(2).map { $0.lowercased() } == ["bar", "bar"])
        #expect(sorted.suffix(2).map { $0.lowercased() } == ["foo", "foo"])
    }
}
