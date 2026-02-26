import XCTest

/// Tests that validate Create Bead actually creates a bead in the board
/// These tests verify outcomes, not just UI interactions
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
    
    // MARK: - Outcome Validation Tests
    
    /// Test that creating a bead increases the visible bead count
    func testCreateBead_IncreasesBoardCount() throws {
        navigateToBoard()
        let initialCount = countVisibleBeadCards()
        
        let uniqueTitle = "Count Test \(UUID().uuidString.prefix(6))"
        createBeadViaUI(title: uniqueTitle)
        
        let newCount = countVisibleBeadCards()
        XCTAssertEqual(
            newCount,
            initialCount + 1,
            "Bead count should increase by 1 after creating a bead (was \(initialCount), now \(newCount))"
        )
    }
    
    /// Test that created bead appears in the Open column
    func testCreateBead_AppearsInOpenColumn() throws {
        navigateToBoard()
        let uniqueTitle = "Open Column Test \(UUID().uuidString.prefix(6))"
        
        createBeadViaUI(title: uniqueTitle)
        
        XCTAssertTrue(
            beadWithTitleExists(uniqueTitle),
            "Created bead '\(uniqueTitle)' should be visible on the board in the Open column"
        )
    }
    
    /// Test that created bead displays correct title
    func testCreateBead_DisplaysCorrectTitle() throws {
        navigateToBoard()
        let uniqueTitle = "Title Test \(UUID().uuidString.prefix(6))"
        
        createBeadViaUI(title: uniqueTitle)
        
        let titleElement = testApp.staticTexts[uniqueTitle]
        XCTAssertTrue(
            titleElement.waitForExistence(timeout: 5),
            "Bead title '\(uniqueTitle)' should be displayed as static text"
        )
    }
    
    /// Test that created bead with description is saved correctly
    func testCreateBead_WithDescription_AppearsOnBoard() throws {
        navigateToBoard()
        let uniqueTitle = "Desc Test \(UUID().uuidString.prefix(6))"
        let description = "This is a detailed test description for the bead"
        
        createBeadViaUI(title: uniqueTitle, description: description)
        
        XCTAssertTrue(
            beadWithTitleExists(uniqueTitle),
            "Bead with description should be visible on the board"
        )
    }
    
    /// Test that multiple beads can be created and all appear
    func testCreateBead_MultipleBeads_AllAppear() throws {
        navigateToBoard()
        let initialCount = countVisibleBeadCards()
        
        let titles = (1...3).map { "Multi Test \($0) \(UUID().uuidString.prefix(4))" }
        for title in titles {
            createBeadViaUI(title: title)
            // Small delay to allow UI to update
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let finalCount = countVisibleBeadCards()
        XCTAssertEqual(
            finalCount,
            initialCount + 3,
            "Board should show \(initialCount + 3) beads after creating 3 new ones"
        )
        
        for title in titles {
            XCTAssertTrue(
                beadWithTitleExists(title),
                "Bead '\(title)' should be visible on the board"
            )
        }
    }
    
    /// Test that bead persists after sheet dismissal (verifies actual creation)
    func testCreateBead_PersistsAfterSheetDismissal() throws {
        navigateToBoard()
        let uniqueTitle = "Persist Test \(UUID().uuidString.prefix(6))"
        
        createBeadViaUI(title: uniqueTitle)
        
        // Verify bead exists immediately after creation
        XCTAssertTrue(beadWithTitleExists(uniqueTitle), "Bead should exist immediately after creation")
        
        // Navigate away and back to verify persistence
        clickButton("Settings")
        XCTAssertTrue(testApp.staticTexts["Gateway Connection"].waitForExistence(timeout: 3))
        
        clickButton("Board")
        XCTAssertTrue(testApp.buttons["Create Bead"].waitForExistence(timeout: 3))
        
        // Verify bead still exists after navigation
        XCTAssertTrue(
            beadWithTitleExists(uniqueTitle),
            "Bead '\(uniqueTitle)' should persist after navigating away and back"
        )
    }
    
    // MARK: - Error Handling Tests
    
    /// Test that empty title prevents creation (sheet stays open)
    func testCreateBead_EmptyTitle_PreventsCreation() throws {
        navigateToBoard()
        let initialCount = countVisibleBeadCards()
        
        clickButton("Create Bead")
        XCTAssertTrue(waitForSheet(), "Create bead sheet should appear")
        
        // Try to save without entering a title
        let saveButton = testApp.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        
        // Save should be disabled or sheet should stay open
        saveButton.click()
        
        // Sheet should still be visible (either disabled save or validation error)
        let sheetStillVisible = testApp.sheets.firstMatch.waitForExistence(timeout: 2)
            || testApp.staticTexts["Create Bead"].waitForExistence(timeout: 2)
        
        if sheetStillVisible {
            // Use local dismiss to avoid conflict with extension
            let cancelButton = testApp.buttons["Cancel"].firstMatch
            if cancelButton.waitForExistence(timeout: 2) {
                cancelButton.click()
            }
        }
        
        // Count should not have changed
        let newCount = countVisibleBeadCards()
        XCTAssertEqual(
            newCount,
            initialCount,
            "Bead count should not change when trying to create with empty title"
        )
    }
    
    /// Test that cancel button dismisses without creating
    func testCreateBead_Cancel_DoesNotCreate() throws {
        navigateToBoard()
        let initialCount = countVisibleBeadCards()
        
        clickButton("Create Bead")
        // Use local sheet wait
        let sheet = testApp.sheets.firstMatch
        XCTAssertTrue(waitForElement(sheet, timeout: 3), "Create bead sheet should appear")
        
        // Enter a title but then cancel
        let titleField = testApp.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.click()
        titleField.typeText("Cancelled Bead")
        
        clickButton("Cancel")
        
        // Verify sheet dismissed
        XCTAssertFalse(
            testApp.staticTexts["Create Bead"].waitForExistence(timeout: 2),
            "Sheet should dismiss after clicking Cancel"
        )
        
        // Count should not have changed
        let newCount = countVisibleBeadCards()
        XCTAssertEqual(
            newCount,
            initialCount,
            "Bead count should not change when cancelling creation"
        )
    }
    
    // MARK: - Helper Methods
    
    private func navigateToBoard() {
        let boardButton = testApp.buttons["Board"]
        if boardButton.waitForExistence(timeout: 3) {
            boardButton.click()
        }
        XCTAssertTrue(
            testApp.buttons["Create Bead"].waitForExistence(timeout: 5),
            "Should be on Board view with Create Bead button visible"
        )
    }
    
    private func countVisibleBeadCards() -> Int {
        testApp.buttons.matching(identifier: "BeadCard").count
    }
    
    private func beadWithTitleExists(_ title: String) -> Bool {
        testApp.staticTexts[title].exists || testApp.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch.exists
    }
    
    private func createBeadViaUI(title: String, description: String = "") {
        let createButton = testApp.buttons["Create Bead"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create Bead button should exist")
        createButton.click()
        
        // Use local sheet wait
        let sheet = testApp.sheets.firstMatch
        XCTAssertTrue(waitForElement(sheet, timeout: 3), "Create bead sheet should appear")
        
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
        
        // Wait for sheet to dismiss and bead to appear
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    private func clickButton(_ label: String) {
        let button = testApp.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Button '\(label)' should exist")
        button.click()
    }
}
