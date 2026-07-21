import AgentBoardCore
import Foundation
import Testing

@Suite("ProjectPathResolver")
struct ProjectPathResolverTests {
    @Test func resolvesCanonicalPathFromHermesRegistry() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectPathResolverTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let canonical = root.appendingPathComponent("LeadFeed", isDirectory: true)
        let registry = home
            .appendingPathComponent(".hermes", isDirectory: true)
            .appendingPathComponent("projects.yaml")
        try FileManager.default.createDirectory(at: canonical, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: registry.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        projects:
          - name: LeadScout
            path: \(canonical.path)
            repo: jbcrane13/LeadScout
            status: active
        """.write(to: registry, atomically: true, encoding: .utf8)

        let resolver = ProjectPathResolver(homeDirectory: home, registryURL: registry)

        #expect(
            resolver.resolve(repoName: "LeadScout", fullRepo: "jbcrane13/LeadScout") ==
                canonical.standardizedFileURL.path
        )
    }

    @Test func fallsBackToProjectsRepoNameWhenRegistryHasNoMatch() {
        let home = URL(fileURLWithPath: "/tmp/agentboard-path-fallback", isDirectory: true)
        let resolver = ProjectPathResolver(
            homeDirectory: home,
            registryURL: home.appendingPathComponent("missing-projects.yaml")
        )

        #expect(
            resolver.resolve(repoName: "Example", fullRepo: "owner/Example") ==
                "/tmp/agentboard-path-fallback/Projects/Example"
        )
    }

    @Test func parsesQuotedRegistryValues() {
        let entries = ProjectPathResolver.parseEntries(
            """
            projects:
              - name: Example
                path: "/tmp/Example Project"
                repo: 'owner/Example'
            """
        )

        #expect(entries == [
            ProjectPathResolver.RegistryEntry(
                repo: "owner/Example",
                path: "/tmp/Example Project"
            )
        ])
    }
}
