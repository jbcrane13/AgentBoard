import XCTest

final class BeadOutcomeTests: XCTestCase {
    private var testApp: XCUIApplication!
    private let timeout: TimeInterval = 10
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        testApp = XCUIApplication()
        testApp.launchArguments = ["--uitesting", "--disable-animations"]
        testApp.launch()
    }
    
    override func tearDownWithError() throws {
        testApp = nil
    }
    
    func testCreateBeadIncreasesBoardCount() throws {
        let initialBeadCount = countVisibleBeads()
        
        createBeadViaUI(title: "Test Bead \(UUID().uuidString.prefix(8))")
        
        XCTAssertTrue(
            waitForElementCount("BeadCard", elementType: .button, expected: initialBeadCount + 1, timeout: 5),
            "Bead count should increase by 1 after creating a bead"
        )
    }
    
    func testCreateBeadAppearsInOpenColumn() throws {
        let uniqueTitle = "Open Bead \(UUID().uuidString.prefix(8))"
        
        createBeadViaUI(title: uniqueTitle)
        
        XCTAssertTrue(
            beadIsVisible(title: uniqueTitle),
            "Created bead should be visible on the board"
        )
    }
    
    func testCreateBeadWithDescription() throws {
        let uniqueTitle = "Bead With Desc \(UUID().uuidString.prefix(8))"
        
        createBeadViaUI(title: uniqueTitle, description: "This is a test description")
        
        XCTAssertTrue(
            beadIsVisible(title: uniqueTitle),
            "Created bead with description should be visible"
        )
    }
    
    func testCreateBeadEmptyTitleShowsError() throws {
        clickButton("Create Bead")
        XCTAssertTrue(waitForTestSheet(timeout: 3), "Create bead sheet should appear")
        
        let saveButton = testApp.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Save button should exist")
        
        saveButton.click()
        
        XCTAssertTrue(
            testApp.staticTexts["Create Bead"].waitForExistence(timeout: 2),
            "Sheet should still be visible after clicking Save with empty title"
        )
        
        dismissTestSheet()
    }
    
    func testCreateBeadCancelButtonDismisses() throws {
        clickButton("Create Bead")
        XCTAssertTrue(waitForTestSheet(timeout: 3), "Create bead sheet should appear")
        
        clickButton("Cancel")
        
        XCTAssertFalse(
            testApp.staticTexts["Create Bead"].waitForExistence(timeout: 2),
            "Sheet should dismiss after clicking Cancel"
        )
    }
    
    private func countVisibleBeads() -> Int {
        testApp.buttons.matching(identifier: "BeadCard").count
    }
    
    private func beadIsVisible(title: String) -> Bool {
        testApp.staticTexts[title].exists || testApp.buttons[title].exists
    }
    
    private func createBeadViaUI(title: String, description: String = "") {
        let createButton = testApp.buttons["Create Bead"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create Bead button should exist")
        createButton.click()
        
        XCTAssertTrue(waitForTestSheet(timeout: 3), "Create bead sheet should appear")
        
        let titleField = testApp.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Title field should exist")
        titleField.click()
        titleField.typeText(title)
        
        if !description.isEmpty {
            let descField = testApp.textViews.firstMatch
            if descField.waitForExistence(timeout: 2) {
                descField.click()
                descField.typeText(description)
            }
        }
        
        let saveButton = testApp.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Save button should exist")
        saveButton.click()
    }
    
    private func waitForTestSheet(timeout: TimeInterval) -> Bool {
        let sheet = testApp.sheets.firstMatch
        return waitForTestElement(sheet, timeout: timeout)
    }
    
    private func waitForTestElement(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
    
    private func waitForElementCount(_ identifier: String, elementType: XCUIElement.ElementType, expected: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let count: Int
            switch elementType {
            case .button:
                count = testApp.buttons.matching(identifier: identifier).count
            case .staticText:
                count = testApp.staticTexts.matching(identifier: identifier).count
            default:
                count = testApp.otherElements.matching(identifier: identifier).count
            }
            if count == expected {
                return true
            }
            usleep(100_000)
        }
        return false
    }
    
    private func clickButton(_ label: String) {
        let button = testApp.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Button '\(label)' should exist")
        button.click()
    }
    
    private func dismissTestSheet() {
        let cancelButton = testApp.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.click()
        }
    }
}
