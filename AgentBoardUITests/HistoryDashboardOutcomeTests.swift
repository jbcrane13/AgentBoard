import XCTest

final class HistoryDashboardOutcomeTests: XCTestCase {
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

    func testHistoryFiltersChangeVisibleEvents() throws {
        clickButton("History")

        XCTAssertTrue(app.staticTexts["Alpha Bead Created"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Beta Commit Event"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["Beta Old Session Event"].exists)

        clickEventFilter("Commits")
        XCTAssertTrue(app.staticTexts["Beta Commit Event"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["Alpha Bead Created"].exists)

        openMenu(currentLabel: "All Projects")
        clickMenuItem("Dashboard Beta")
        XCTAssertTrue(app.staticTexts["Beta Commit Event"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["Alpha Bead Created"].exists)

        clickEventFilter("All Events")
        openMenu(currentLabel: "Last 30d")
        clickMenuItem("All Time")
        XCTAssertTrue(app.staticTexts["Beta Old Session Event"].waitForExistence(timeout: timeout))
    }

    private func clickButton(_ title: String) {
        let button = app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Expected button \(title)")
        button.click()
    }

    private func openMenu(currentLabel: String) {
        let menuButton = app.popUpButtons[currentLabel].firstMatch
        if menuButton.waitForExistence(timeout: 2) {
            menuButton.click()
            return
        }

        let fallback = app.buttons[currentLabel].firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: timeout), "Expected menu with label \(currentLabel)")
        fallback.click()
    }

    private func clickMenuItem(_ title: String) {
        let menuItem = app.menuItems[title].firstMatch
        XCTAssertTrue(menuItem.waitForExistence(timeout: timeout), "Expected menu item \(title)")
        menuItem.click()
    }

    private func clickEventFilter(_ label: String) {
        let segmented = app.segmentedControls.allElementsBoundByIndex.first(where: { $0.buttons.count >= 4 })
            ?? app.segmentedControls.firstMatch
        XCTAssertTrue(segmented.waitForExistence(timeout: timeout), "Expected segmented event filter")

        // History event filter is a 4-segment control (All/Bead/Session/Commits).
        let dx: CGFloat
        switch label {
        case "Commits":
            dx = 0.88
        case "All Events":
            dx = 0.12
        default:
            dx = 0.5
        }
        segmented.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).click()
    }
}
