import XCTest

final class AgentsDashboardOutcomeTests: XCTestCase {
    private var app: XCUIApplication!
    private let timeout: TimeInterval = 8

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        var args = ["--uitesting", "--disable-animations", "--uitesting-dashboard-fixtures"]
        if name.contains("EmptyStates") {
            args.append("--uitesting-dashboard-empty")
        }
        app.launchArguments = args
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAgentsWidgetsShowFixtureStatsAndHandoffExpansion() throws {
        app.typeKey("3", modifierFlags: [.command])

        let sessionsToday = app.staticTexts["AgentsStat-SessionsToday"].firstMatch
        XCTAssertTrue(sessionsToday.waitForExistence(timeout: timeout))
        XCTAssertEqual(textValue(of: sessionsToday), "2")

        XCTAssertTrue(app.staticTexts["AgentsSessionName-ab-alpha-run"].waitForExistence(timeout: timeout))

        let handoffRow = app.descendants(matching: .any)["HandoffRow-handoff-1"].firstMatch
        XCTAssertTrue(handoffRow.waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["HandoffContext-handoff-1"].exists)

        handoffRow.click()
        XCTAssertTrue(app.staticTexts["HandoffContext-handoff-1"].waitForExistence(timeout: timeout))

        handoffRow.click()
        XCTAssertFalse(app.staticTexts["HandoffContext-handoff-1"].waitForExistence(timeout: 2))
    }

    func testAgentsWidgetsShowEmptyStatesInEmptyFixtureMode() throws {
        app.typeKey("3", modifierFlags: [.command])
        XCTAssertTrue(app.staticTexts["AgentsEmptyStatus"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["AgentsEmptyHandoffs"].waitForExistence(timeout: timeout))
    }

    private func textValue(of element: XCUIElement) -> String {
        if !element.label.isEmpty {
            return element.label
        }
        if let value = element.value as? String {
            return value
        }
        return ""
    }
}
