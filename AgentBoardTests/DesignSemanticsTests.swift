import AgentBoardCore
import Foundation
import Testing

/// Guardrail tests for the native (ADR-015/ADR-016) design language. These are
/// source-text checks rather than instantiated-view checks: the test target
/// doesn't link AgentBoardUI (see `NativeSwiftUIInterfaceTests`), so pinning
/// `AppTheme`'s semantics means asserting on `AppTheme.swift`'s
/// source, and the "no hardcoded white/black" rule means asserting on the
/// shared chrome components' source.
struct DesignSemanticsTests {
    @Test func workBoardColumnTitlesMatchDesignTemplate() {
        #expect(WorkState.ready.designColumnTitle == "READY")
        #expect(WorkState.inProgress.designColumnTitle == "IN PROGRESS")
        #expect(WorkState.blocked.designColumnTitle == "BLOCKED")
        #expect(WorkState.review.designColumnTitle == "REVIEW")
    }

    @Test func appThemeAccentsResolveToSystemAccentColor() throws {
        let source = try Self.source("AgentBoardUI/Theme/AppTheme.swift")

        #expect(source.contains("primaryAccent: .accentColor"))
        #expect(source.contains("primaryAccentBright: .accentColor"))
        // No bespoke brand-teal RGB literal should reappear as the accent.
        #expect(!source.contains("red: 0.106, green: 0.749, blue: 0.651"))
    }

    @Test func cardSurfaceModifierHasNoPermanentDropShadow() throws {
        let source = try Self.source("AgentBoardUI/Theme/AppTheme.swift")

        guard let start = source.range(of: "struct CardSurfaceModifier"),
              let end = source.range(of: "struct InsetSurfaceModifier") else {
            Issue.record("Could not locate CardSurfaceModifier in AppTheme.swift")
            return
        }
        let modifierBody = source[start.lowerBound ..< end.lowerBound]

        // Cards read as flat native surfaces at rest; `.draggable()` already
        // supplies the system's own lift/shadow while a card is being dragged.
        #expect(!modifierBody.contains(".shadow("))
    }

    @Test func sharedChromeComponentsDoNotHardcodeWhiteOrBlack() throws {
        // The two fully-flat shared components (the P3 markdown landmine and
        // the shared card chrome) must never hardcode white/black — every
        // color there should flow through a semantic AppTheme token.
        for path in ["AgentBoardUI/Components/MarkdownText.swift", "AgentBoardUI/Components/BoardChrome.swift"] {
            let source = try Self.source(path)
            #expect(!source.contains(".white"), "\(path) should not hardcode .white")
            #expect(!source.contains("Color.black"), "\(path) should not hardcode Color.black")
        }

        // ChatBubbleView's one hardcoded `.white` (text on the user bubble's
        // accent fill) is the justified exception — pinned here so a future
        // edit can't silently drop the justifying comment or add a new,
        // unjustified hardcoded color alongside it.
        let chatBubble = try Self.source("AgentBoardUI/Components/ChatBubble.swift")
        let whiteOccurrences = chatBubble.components(separatedBy: ".white").count - 1
        #expect(whiteOccurrences == 1)
        #expect(chatBubble.contains("case .user: .white"))
        #expect(chatBubble.lowercased().contains("justified"))
        #expect(!chatBubble.contains("Color.black"))
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot.appending(path: relativePath), encoding: .utf8)
    }

    private static var repositoryRoot: URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appending(path: "project.yml").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }

        Issue.record("Unable to locate repository root from \(#filePath)")
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }
}
