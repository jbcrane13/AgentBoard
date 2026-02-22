import Foundation
import XCTest

// MARK: - UI Test State Query Helpers

/// Provides state query access for UI tests via launch arguments
/// The app must be configured to read these launch arguments and expose state
final class UIStateQueryHelper {
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - Bead Queries via Accessibility
    
    /// Count beads visible in the board
    func countVisibleBeads() -> Int {
        app.buttons.matching(identifier: "BeadCard").count
    }
    
    /// Check if a bead with the given title is visible
    func beadIsVisible(title: String) -> Bool {
        app.staticTexts[title].exists || app.buttons[title].exists
    }
    
    /// Find a bead card by title
    func findBeadCard(title: String) -> XCUIElement {
        let staticText = app.staticTexts[title]
        if staticText.exists {
            return staticText
        }
        return app.buttons[title]
    }
    
    // MARK: - Session Queries via Accessibility
    
    /// Count sessions visible in sidebar
    func countVisibleSessions() -> Int {
        app.buttons.matching(identifier: "SessionRow").count
    }
    
    /// Check if a session with the given name is visible
    func sessionIsVisible(name: String) -> Bool {
        app.staticTexts[name].exists || app.buttons[name].exists
    }
    
    // MARK: - Chat Queries via Accessibility
    
    /// Count chat messages visible in chat panel
    func countVisibleChatMessages() -> Int {
        app.otherElements.matching(identifier: "ChatMessage").count
    }
    
    /// Check if send button is enabled
    func sendButtonIsEnabled() -> Bool {
        app.buttons["arrow.up"].isEnabled
    }
    
    // MARK: - Settings Queries via Accessibility
    
    /// Get gateway URL field value
    func gatewayURLFieldValue() -> String? {
        let field = app.textFields["Gateway URL (e.g. http://192.168.1.100:18789)"]
        return field.value as? String
    }
    
    // MARK: - Error/Status Queries
    
    /// Check if error message is visible
    func errorIsVisible() -> Bool {
        app.staticTexts.matching(NSPredicate(format: "color == %@", NSColor.red)).firstMatch.exists
    }
    
    /// Get status message if visible
    func statusMessageText() -> String? {
        let statusLabels = app.staticTexts.matching(NSPredicate(format: "value != nil"))
        for label in statusLabels.allElementsBoundByIndex {
            if let text = label.value as? String, !text.isEmpty {
                return text
            }
        }
        return nil
    }
}

// MARK: - Async UI Test Helpers

extension XCTestCase {
    /// Wait for an element to appear
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Wait for element to disappear
    func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval = 5.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Wait for count of elements matching identifier to reach expected value
    func waitForElementCount(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .any,
        expected: Int,
        timeout: TimeInterval = 5.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let count: Int
            switch elementType {
            case .button:
                count = app.buttons.matching(identifier: identifier).count
            case .staticText:
                count = app.staticTexts.matching(identifier: identifier).count
            case .textField:
                count = app.textFields.matching(identifier: identifier).count
            default:
                count = app.otherElements.matching(identifier: identifier).count
            }
            if count == expected {
                return true
            }
            usleep(100_000) // 100ms
        }
        return false
    }
}

// MARK: - UI Test Data Setup

/// Provides test data setup for UI tests
final class UITestDataHelper {
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    /// Launch app with test configuration
    func launchWithTestConfig() {
        app.launchArguments = [
            "--uitesting",
            "--disable-animations"
        ]
        app.launch()
    }
    
    /// Launch app with gateway config
    func launchWithGateway(url: String, token: String? = nil) {
        var args = ["--uitesting", "--disable-animations", "--gateway-url", url]
        if let token {
            args.append(contentsOf: ["--gateway-token", token])
        }
        app.launchArguments = args
        app.launch()
    }
    
    /// Launch app with a test project
    func launchWithTestProject(at path: String) {
        app.launchArguments = [
            "--uitesting",
            "--disable-animations",
            "--test-project", path
        ]
        app.launch()
    }
}

// MARK: - Sheet Interaction Helpers

extension XCTestCase {
    /// Wait for a sheet to appear
    func waitForSheet(timeout: TimeInterval = 5.0) -> Bool {
        let sheet = XCUIApplication().sheets.firstMatch
        return waitForElement(sheet, timeout: timeout)
    }
    
    /// Dismiss any open sheet
    func dismissSheet() {
        let app = XCUIApplication()
        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.click()
        }
    }
    
    /// Create a bead via the UI
    func createBeadViaUI(title: String, description: String = "", file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        
        let createButton = app.buttons["Create Bead"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create Bead button should exist", file: file, line: line)
        createButton.click()
        
        XCTAssertTrue(waitForSheet(timeout: 3), "Create bead sheet should appear", file: file, line: line)
        
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Title field should exist", file: file, line: line)
        titleField.click()
        titleField.typeText(title)
        
        if !description.isEmpty {
            let descField = app.textViews.firstMatch
            if descField.waitForExistence(timeout: 2) {
                descField.click()
                descField.typeText(description)
            }
        }
        
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Save button should exist", file: file, line: line)
        saveButton.click()
    }
    
    /// Create a session via the UI
    func createSessionViaUI(projectName: String, agentType: String = "Claude Code", file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        
        let newSessionButton = app.buttons["+ New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5), "New Session button should exist", file: file, line: line)
        newSessionButton.click()
        
        XCTAssertTrue(waitForSheet(timeout: 3), "New session sheet should appear", file: file, line: line)
        
        let projectPicker = app.menuButtons["Project"]
        if projectPicker.waitForExistence(timeout: 2) {
            projectPicker.click()
            app.menuItems[projectName].click()
        }
        
        let launchButton = app.buttons["Launch"]
        XCTAssertTrue(launchButton.waitForExistence(timeout: 2), "Launch button should exist", file: file, line: line)
        launchButton.click()
    }
}

// MARK: - App Property for XCTestCase Extension

extension XCTestCase {
    var app: XCUIApplication {
        XCUIApplication()
    }
}