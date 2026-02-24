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
}
