@testable import AgentBoardCore
import Foundation
import Testing

/// Covers `KanbanCLIWriter.resolveHermes()` — the path discovery that must
/// locate the `hermes` binary no matter how the app was launched (GUI apps do
/// NOT inherit the user's interactive-shell PATH, so a bare `hermes` name
/// won't resolve via Foundation's `Process`). Regression guard for the
/// "save task" failure where `hermes` lives at `~/.local/bin/hermes` instead of
/// the hardcoded `/opt/homebrew/bin/hermes`.
@Suite("KanbanCLIWriter.resolveHermes path discovery")
struct KanbanCLIWriterPathTests {
    @Test func fallsBackToCommonLocationsWhenConfiguredPathMissing() async {
        // Writer created with a bogus configured path; resolution must still
        // find a real hermes install (e.g. ~/.local/bin/hermes) without throwing.
        let writer = KanbanCLIWriter(hermesPath: "/nonexistent/hermes")
        let resolved = await writer.resolveHermes()
        // Either we found a real binary, or we returned the bare "hermes"
        // fallback — never an empty string or the bogus configured path.
        #expect(!resolved.isEmpty)
        #expect(resolved != "/nonexistent/hermes")
        if resolved != "hermes" {
            #expect(FileManager.default.isExecutableFile(atPath: resolved))
        }
    }

    @Test func configuredPathWinsWhenValid() async {
        let home = NSHomeDirectory()
        let realBinary = (home as NSString).appendingPathComponent(".local/bin/hermes")
        guard FileManager.default.isExecutableFile(atPath: realBinary) else {
            // Skip on machines where the probe install doesn't exist.
            return
        }
        let writer = KanbanCLIWriter(hermesPath: realBinary)
        #expect(await writer.resolveHermes() == realBinary)
    }

    @Test func probeFindsLocalBinInstall() async {
        let home = NSHomeDirectory()
        let realBinary = (home as NSString).appendingPathComponent(".local/bin/hermes")
        guard FileManager.default.isExecutableFile(atPath: realBinary) else {
            return
        }
        // No configured path set; must probe and find ~/.local/bin/hermes.
        let writer = KanbanCLIWriter(hermesPath: "/opt/homebrew/bin/hermes")
        #expect(await writer.resolveHermes() == realBinary)
    }
}
