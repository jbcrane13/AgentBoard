import Foundation
import Testing

/// Guardrails for the strict SwiftLint gate around the Hermes-first rebuild
/// (issue #47). These tests pin the repo's lint contract so the strict gate
/// cannot silently regress while legacy donor-app debt is paid down.
///
/// The contract has three parts:
///   1. `.swiftlint.yml` keeps every Hermes-first target inside `included:`,
///      so adding a file to a modern module is automatically linted.
///   2. The CI workflow runs `swiftlint lint --strict` (warnings = errors),
///      not the default lenient invocation.
///   3. The local pre-commit hook lints the same scope as CI, so local
///      verification does not lull the author into a false sense of safety.
@Suite("Strict SwiftLint gate")
struct SwiftLintGateTests {
    /// Hermes-first targets that must be inside the lint scope.
    private static let hermesTargets: [String] = [
        "AgentBoard",
        "AgentBoardMobile",
        "AgentBoardUI",
        "AgentBoardCore",
        "AgentBoardCompanion",
        "AgentBoardCompanionKit",
        "AgentBoardTests"
    ]

    @Test(".swiftlint.yml scopes lint to every Hermes-first target")
    func swiftLintConfigIncludesHermesTargets() throws {
        let yaml = try readRepoFile(".swiftlint.yml")
        let includedBlock = try section(named: "included", in: yaml)
        for target in Self.hermesTargets {
            #expect(
                includedBlock.contains("- \(target)"),
                "expected `.swiftlint.yml` `included:` to cover \(target)"
            )
        }
    }

    @Test("CI workflow enforces strict SwiftLint")
    func ciWorkflowRunsSwiftLintStrict() throws {
        let workflow = try readRepoFile(".github/workflows/ci.yml")
        #expect(
            workflow.contains("swiftlint lint --strict"),
            "CI workflow must invoke `swiftlint lint --strict`; the legacy lenient call lets warnings slip through the gate"
        )
    }

    @Test("Pre-commit hook lints the full Hermes scope, not just the macOS shell")
    func preCommitHookLintsFullHermesScope() throws {
        let hook = try readRepoFile("scripts/pre-commit-quality")
        let lintLine = try line(matching: "swiftlint lint", in: hook)
        #expect(
            lintLine.contains("--strict"),
            "pre-commit hook must pass `--strict`; otherwise local lint stays lenient while CI is strict"
        )
        for target in Self.hermesTargets {
            #expect(
                lintLine.contains(target),
                "pre-commit hook must lint \(target) so local verification matches the configured scope"
            )
        }
    }

    // MARK: - Helpers

    private func readRepoFile(_ relativePath: String) throws -> String {
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Returns the body of a top-level YAML block (lines indented under the
    /// given key) up until the next top-level key. Naive but sufficient for
    /// the simple block-style `.swiftlint.yml` this repo uses.
    private func section(named key: String, in yaml: String) throws -> String {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("\(key):") }) else {
            Issue.record("missing top-level `\(key):` block in `.swiftlint.yml`")
            return ""
        }
        var body: [String] = []
        for line in lines[(start + 1)...] {
            if line.isEmpty { continue }
            if line.first == " " || line.first == "\t" {
                body.append(line)
            } else {
                break
            }
        }
        return body.joined(separator: "\n")
    }

    private func line(matching needle: String, in source: String) throws -> String {
        let matches = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.contains(needle) && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        guard let first = matches.first else {
            Issue.record("no `\(needle)` line found")
            return ""
        }
        return first
    }
}
