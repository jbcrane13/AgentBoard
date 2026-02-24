import Foundation
import Testing
@testable import AgentBoard

@Suite("BeadsWatcher Tests")
struct BeadsWatcherTests {
    @Test("watch reports an error when the target file cannot be opened")
    func watchReportsErrorForMissingFile() {
        let watcher = BeadsWatcher()
        let missingFile = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)/issues.jsonl")

        var capturedError: String?
        watcher.watch(fileURL: missingFile, onChange: {}, onError: { message in
            capturedError = message
        })
        watcher.stop()

        #expect(capturedError != nil)
        #expect(capturedError?.contains("Unable to watch") == true)
        #expect(capturedError?.contains("issues.jsonl") == true)
    }

    @Test("watch calls onChange when the file is written to")
    func watchCallsOnChangeOnFileWrite() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("issues.jsonl")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let watcher = BeadsWatcher()
        var changeCount = 0
        var errorMessage: String?

        watcher.watch(fileURL: fileURL, onChange: {
            changeCount += 1
        }, onError: { msg in
            errorMessage = msg
        })

        // Write to the file to trigger onChange
        try "{}".write(to: fileURL, atomically: true, encoding: .utf8)

        // Give the file system event a moment to fire
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
        watcher.stop()

        #expect(errorMessage == nil, "No error should occur for a valid file")
        #expect(changeCount >= 1, "onChange should be called at least once after a file write")
    }

    @Test("stop is safe to call before watch")
    func stopBeforeWatchDoesNotCrash() {
        let watcher = BeadsWatcher()
        watcher.stop()  // Should not crash
    }

    @Test("stop is safe to call multiple times")
    func stopMultipleTimesDoesNotCrash() {
        let watcher = BeadsWatcher()
        let fileURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)/nonexistent.jsonl")
        watcher.watch(fileURL: fileURL, onChange: {}, onError: { _ in })
        watcher.stop()
        watcher.stop()  // Second stop should not crash
    }
}
