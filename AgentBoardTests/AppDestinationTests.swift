import AgentBoardCore
import Testing

@Suite("AppDestination")
struct AppDestinationTests {
    @Test func appDestinationAllCasesAreStable() {
        // Ordering matters because navigation rails iterate `.allCases` directly.
        #expect(AppDestination.allCases == [.chat, .work, .agents, .sessions, .settings])
    }

    @Test func appDestinationIDMatchesRawValue() {
        for destination in AppDestination.allCases {
            #expect(destination.id == destination.rawValue)
        }
    }

    @Test func appDestinationTitleIsUserFacing() {
        #expect(AppDestination.chat.title == "Chat")
        #expect(AppDestination.work.title == "Work")
        #expect(AppDestination.agents.title == "Agents")
        #expect(AppDestination.sessions.title == "Sessions")
        #expect(AppDestination.settings.title == "Settings")
    }

    @Test func appDestinationSystemImageIsNonEmptySFSymbol() {
        for destination in AppDestination.allCases {
            #expect(!destination.systemImage.isEmpty)
            // SF Symbols never contain whitespace.
            #expect(!destination.systemImage.contains(" "))
        }
    }
}
