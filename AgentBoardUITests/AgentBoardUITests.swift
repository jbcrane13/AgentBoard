import XCTest

final class AgentBoardUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testLaunchShowsSidebarSections() throws {
        XCTAssertTrue(app.staticTexts["Projects"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Sessions"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Views"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["+ New Session"].waitForExistence(timeout: 10))
    }

    func testSidebarNavigationSettingsHistoryBoard() throws {
        let settingsButton = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.click()

        XCTAssertTrue(app.staticTexts["Gateway Connection"].waitForExistence(timeout: 10))

        let historyButton = app.buttons["History"].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 10))
        historyButton.click()

        XCTAssertTrue(app.buttons["All Events"].waitForExistence(timeout: 10))

        let boardButton = app.buttons["Board"].firstMatch
        XCTAssertTrue(boardButton.waitForExistence(timeout: 10))
        boardButton.click()

        XCTAssertTrue(app.buttons["Create Bead"].waitForExistence(timeout: 10))
    }
}
