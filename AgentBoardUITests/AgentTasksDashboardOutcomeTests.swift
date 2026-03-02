import XCTest

final class AgentTasksDashboardOutcomeTests: XCTestCase {
    private var app: XCUIApplication!
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--disable-animations", "--uitesting-dashboard-fixtures"]
        app.launch()

        clickSidebar("Agent Tasks")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCreateTaskValidationAndCreationOutcome() throws {
        let newTaskButton = app.buttons["AgentTasksNewTaskButton"].firstMatch
        XCTAssertTrue(newTaskButton.waitForExistence(timeout: timeout))
        newTaskButton.click()

        let createButton = app.buttons["AgentTaskCreateConfirmButton"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: timeout))
        XCTAssertFalse(createButton.isEnabled)

        let titleField = app.textFields["AgentTaskCreateTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: timeout))
        titleField.click()
        titleField.typeText("Created In UI Test")

        XCTAssertTrue(createButton.isEnabled)
        createButton.click()

        XCTAssertTrue(app.staticTexts["Created In UI Test"].waitForExistence(timeout: timeout))
    }

    func testCompletedToggleShowsCompletedTasks() throws {
        XCTAssertFalse(app.staticTexts["Completed Fixture Task"].exists)

        let toggle = app.buttons["AgentTasksToggleCompleted-quentin"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: timeout))
        toggle.click()
        XCTAssertTrue(toggle.label.contains("Hide"), "Expected toggle label to switch to hide completed state")
    }

    func testDetailSaveUpdatesTaskTitle() throws {
        let taskTitle = app.staticTexts["AgentTaskTitle-AB-fixture-1"].firstMatch
        XCTAssertTrue(taskTitle.waitForExistence(timeout: timeout))
        taskTitle.click()

        let titleField = app.textFields["AgentTaskDetailTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: timeout))
        titleField.click()
        titleField.typeKey("a", modifierFlags: .command)
        titleField.typeText("Edited Fixture Task")

        let saveButton = app.buttons["AgentTaskDetailSaveButton"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: timeout))
        saveButton.click()

        XCTAssertTrue(app.staticTexts["Edited Fixture Task"].waitForExistence(timeout: timeout))
    }

    private func clickSidebar(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Expected sidebar item \(label)")
        button.click()
    }
}
