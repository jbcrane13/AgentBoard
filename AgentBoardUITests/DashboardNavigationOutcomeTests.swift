import XCTest

final class DashboardNavigationOutcomeTests: XCTestCase {
    private var app: XCUIApplication!
    private let timeout: TimeInterval = 8

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--disable-animations", "--uitesting-dashboard-fixtures"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testProjectHeaderStatsChangeWhenProjectSelectionChanges() throws {
        let openStat = app.staticTexts["ProjectHeaderStat-Open"].firstMatch
        XCTAssertTrue(openStat.waitForExistence(timeout: timeout))
        let before = textValue(of: openStat)
        XCTAssertFalse(before.isEmpty)

        clickProject("Dashboard Beta")

        XCTAssertTrue(openStat.waitForExistence(timeout: timeout))
        let after = textValue(of: openStat)
        XCTAssertFalse(after.isEmpty)
        XCTAssertNotEqual(after, before)
    }

    func testUnreadBadgeClearsOnChatModeAndPanelCollapseTogglesSidebar() throws {
        let unreadBadge = app.staticTexts["UnreadChatBadge"].firstMatch
        XCTAssertTrue(unreadBadge.waitForExistence(timeout: timeout))
        XCTAssertEqual(textValue(of: unreadBadge), "41")

        app.typeKey("l", modifierFlags: [.command])
        XCTAssertFalse(unreadBadge.waitForExistence(timeout: 2))

        let collapseButton = app.buttons["RightPanelCollapseButton"].firstMatch
        XCTAssertTrue(collapseButton.waitForExistence(timeout: timeout))

        collapseButton.click()
        XCTAssertFalse(app.buttons["Board"].waitForExistence(timeout: 2))

        collapseButton.click()
        XCTAssertTrue(app.buttons["Board"].waitForExistence(timeout: timeout))
    }

    private func clickSidebar(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Expected sidebar item \(label)")
        button.click()
    }

    private func clickProject(_ name: String) {
        let row = app.buttons["ProjectRow-\(name)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "Expected project row \(name)")
        row.click()
    }

    private func clickButton(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Expected button \(label)")
        button.click()
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
