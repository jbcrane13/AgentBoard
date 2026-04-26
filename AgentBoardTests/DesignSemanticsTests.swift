import AgentBoardCore
import Foundation
import Testing

struct DesignSemanticsTests {
    @Test func workBoardColumnTitlesMatchDesignTemplate() {
        #expect(WorkState.open.designColumnTitle == "OPEN")
        #expect(WorkState.inProgress.designColumnTitle == "IN REVIEW")
        #expect(WorkState.done.designColumnTitle == "CLOSED")
    }

    @Test func designThemesExposeBlueAndGreyComparisonPresets() {
        #expect(AgentBoardDesignTheme.allCases == [.blue, .grey])
        #expect(AgentBoardDesignTheme.blue.displayName == "Blue")
        #expect(AgentBoardDesignTheme.grey.displayName == "Grey")
        #expect(AgentBoardDesignTheme.blue.primaryAccentHex == "#1bbfa6")
        #expect(AgentBoardDesignTheme.grey.primaryAccentHex == "#c97a3e")
    }

    @Test func settingsPersistSelectedDesignTheme() throws {
        let settings = AgentBoardSettings(designTheme: .grey)
        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AgentBoardSettings.self, from: encoded)

        #expect(decoded.designTheme == .grey)
    }

    @Test func settingsDecodeMissingDesignThemeAsBlue() throws {
        let legacyJSON = """
        {
          "hermesGatewayURL": "http://127.0.0.1:8642",
          "hermesModelID": "hermes-agent",
          "companionURL": "http://127.0.0.1:8742",
          "repositories": [],
          "autoRefreshInterval": 30
        }
        """

        let decoded = try JSONDecoder().decode(AgentBoardSettings.self, from: Data(legacyJSON.utf8))

        #expect(decoded.designTheme == .blue)
    }
}
