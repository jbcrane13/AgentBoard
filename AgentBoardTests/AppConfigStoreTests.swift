import Foundation
import Testing
@testable import AgentBoard

@Suite("AppConfigStore Tests")
struct AppConfigStoreTests {
    private let store = AppConfigStore()

    // MARK: - discoverProjects

    @Test("discoverProjects finds directory containing .beads subfolder")
    func discoverProjectsFindsBeadsDirectory() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projectDir = tempDir.appendingPathComponent("MyProject", isDirectory: true)
        let beadsDir = projectDir.appendingPathComponent(".beads", isDirectory: true)
        try FileManager.default.createDirectory(at: beadsDir, withIntermediateDirectories: true)

        let results = store.discoverProjects(in: tempDir)

        #expect(results.count == 1)
        #expect(results[0].path == projectDir.path)
    }

    @Test("discoverProjects ignores directories without .beads subfolder")
    func discoverProjectsIgnoresDirectoriesWithoutBeads() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projectDir = tempDir.appendingPathComponent("MyProject", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let results = store.discoverProjects(in: tempDir)

        #expect(results.isEmpty)
    }

    @Test("discoverProjects returns empty array for non-existent directory")
    func discoverProjectsNonExistentDirReturnsEmpty() {
        let nonexistent = URL(fileURLWithPath: "/tmp/ABConfigTests-nonexistent-\(UUID().uuidString)")

        let results = store.discoverProjects(in: nonexistent)

        #expect(results.isEmpty)
    }

    @Test("discoverProjects sorts results alphabetically by last path component")
    func discoverProjectsSortsAlphabetically() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for name in ["Beta", "Alpha"] {
            let beadsDir = tempDir
                .appendingPathComponent(name, isDirectory: true)
                .appendingPathComponent(".beads", isDirectory: true)
            try FileManager.default.createDirectory(at: beadsDir, withIntermediateDirectories: true)
        }

        let results = store.discoverProjects(in: tempDir)

        #expect(results.count == 2)
        #expect(URL(fileURLWithPath: results[0].path).lastPathComponent == "Alpha")
        #expect(URL(fileURLWithPath: results[1].path).lastPathComponent == "Beta")
    }

    @Test("discoverProjects returns ConfiguredProject with correct path and icon")
    func discoverProjectsWithBeadsReturnsConfiguredProject() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projectDir = tempDir.appendingPathComponent("SomeProject", isDirectory: true)
        let beadsDir = projectDir.appendingPathComponent(".beads", isDirectory: true)
        try FileManager.default.createDirectory(at: beadsDir, withIntermediateDirectories: true)

        let results = store.discoverProjects(in: tempDir)

        let project = try #require(results.first)
        #expect(project.path == projectDir.path)
        #expect(project.icon == "📁")
    }

    @Test("discoverProjects skips regular files in the search directory")
    func discoverProjectsSkipsFiles() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("notadirectory.txt")
        try "content".write(to: fileURL, atomically: true, encoding: .utf8)

        let results = store.discoverProjects(in: tempDir)

        #expect(results.isEmpty)
    }

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ABConfigTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
