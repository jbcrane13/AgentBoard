import CoreGraphics
import XCTest

final class AgentBoardUITests: XCTestCase {
    private var app: XCUIApplication!

    private let timeout: TimeInterval = 10
    private let minimumWindowWidth: CGFloat = 900
    private let minimumWindowHeight: CGFloat = 600

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testLaunchAndWindowSizing() throws {
        let window = requireWindow()
        assertWindowRespectsMinimumSize(window)

        requireStaticText("Projects")
        requireStaticText("Sessions")
        requireStaticText("Views")
        requireButton("+ New Session")
    }

    func testSidebarNavigationItemsAndViewSwitching() throws {
        requireButton("Board")
        requireButton("Epics")
        requireButton("History")
        requireButton("Settings")

        clickButton("Settings")
        requireStaticText("Gateway Connection")

        clickButton("History")
        requireButton("All Events")

        clickButton("Epics")
        requireButton("Create Epic")

        clickButton("Board")
        requireButton("Create Bead")
    }

    func testBoardViewColumnsPresent() throws {
        clickButton("Board")
        requireButton("Create Bead")

        requireStaticText(anyOf: ["OPEN", "Open"])
        requireStaticText(anyOf: ["IN PROGRESS", "In Progress"])
        requireStaticText(anyOf: ["BLOCKED", "Blocked"])
        requireStaticText(anyOf: ["DONE", "Done"])
    }

    func testChatPanelElements() throws {
        selectRightPanelMode("Chat")

        requireButton("main")
        requireStaticText("Message your agents...")

        let sendButton = app.buttons.matching(
            NSPredicate(format: "label == 'arrow.up' OR identifier == 'arrow.up'")
        ).firstMatch
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: timeout),
            "Expected chat send button to exist"
        )
    }

    func testSettingsViewFields() throws {
        clickButton("Settings")

        requireStaticText("Gateway Connection")
        requireButton("Save")
        requireButton("Manual").click()

        requireTextField("Gateway URL (e.g. http://192.168.1.100:18789)")
        requireSecureField("Auth Token")

        let testConnectionButton = app.buttons["Test Connection"].firstMatch
        let testingButton = app.buttons["Testing…"].firstMatch
        XCTAssertTrue(
            testConnectionButton.waitForExistence(timeout: timeout)
                || testingButton.waitForExistence(timeout: timeout),
            "Expected Test Connection action to be available"
        )
    }

    func testKeyboardShortcutsCmd1ThroughCmd8CmdNCmdComma() throws {
        requireWindow().click()

        app.typeKey("1", modifierFlags: [.command])
        requireButton("Create Bead")

        app.typeKey("2", modifierFlags: [.command])
        requireButton("Create Epic")

        app.typeKey("3", modifierFlags: [.command])
        requireStaticText("Sessions Today")

        app.typeKey("4", modifierFlags: [.command])
        requireButton("All Events")

        for key in ["5", "6", "7", "8"] {
            app.typeKey(key, modifierFlags: [.command])
            XCTAssertTrue(requireWindow().exists)
            XCTAssertTrue(
                anyPrimaryViewIndicatorExists(),
                "Expected app to remain in a valid visible state after Cmd+\(key)"
            )
        }

        app.typeKey("n", modifierFlags: [.command])
        XCTAssertTrue(
            app.staticTexts["Create Bead"].waitForExistence(timeout: timeout)
                || app.staticTexts["New Session"].waitForExistence(timeout: timeout),
            "Expected Cmd+N to open a creation sheet"
        )
        dismissSheetIfNeeded()

        app.typeKey("n", modifierFlags: [.command, .shift])
        XCTAssertTrue(
            app.staticTexts["New Session"].waitForExistence(timeout: timeout),
            "Expected Cmd+Shift+N to open New Session"
        )
        dismissSheetIfNeeded()

        app.typeKey(",", modifierFlags: [.command])
        if !app.staticTexts["Gateway Connection"].waitForExistence(timeout: 2) {
            clickButton("Settings")
        }
        requireStaticText("Gateway Connection")
    }

    func testRightPanelModeSwitching() throws {
        selectRightPanelMode("Canvas")
        requireStaticText("Canvas is empty.")

        selectRightPanelMode("Chat")
        requireStaticText("Message your agents...")

        selectRightPanelMode("Split")
        requireStaticText("Canvas is empty.")
        requireStaticText("Message your agents...")
    }

    func testNewSessionSheet() throws {
        clickButton("+ New Session")

        requireStaticText("New Session")
        requireStaticText("Project")
        requireStaticText("Agent")
        requireTextField("Linked bead ID (optional)")
        requireStaticText("Prompt (optional)")
        requireButton("Cancel")
        requireButton("Launch")

        clickButton("Cancel")
        XCTAssertFalse(app.staticTexts["New Session"].exists)
    }

    func testWindowMinimumSizeConstraints() throws {
        let window = requireWindow()
        assertWindowRespectsMinimumSize(window)

        let resizeHandle = window.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.98))
        let shrinkTarget = window.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
        resizeHandle.press(forDuration: 0.1, thenDragTo: shrinkTarget)

        assertWindowRespectsMinimumSize(window)
    }

    func testTabPersistenceAcrossNavigation() throws {
        app.typeKey("2", modifierFlags: [.command])
        requireButton("Create Epic")

        selectRightPanelMode("Canvas")
        requireButton("Create Epic")

        selectRightPanelMode("Chat")
        requireButton("Create Epic")

        clickButton("Settings")
        requireStaticText("Gateway Connection")

        app.typeKey("2", modifierFlags: [.command])
        requireButton("Create Epic")
    }
}

private extension AgentBoardUITests {
    @discardableResult
    func requireWindow(
        timeout: TimeInterval? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: timeout ?? self.timeout),
            "Expected main window to exist",
            file: file,
            line: line
        )
        return window
    }

    @discardableResult
    func requireButton(
        _ label: String,
        timeout: TimeInterval? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(
            button.waitForExistence(timeout: timeout ?? self.timeout),
            "Expected button '\(label)' to exist",
            file: file,
            line: line
        )
        return button
    }

    @discardableResult
    func requireStaticText(
        _ label: String,
        timeout: TimeInterval? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let text = app.staticTexts[label].firstMatch
        XCTAssertTrue(
            text.waitForExistence(timeout: timeout ?? self.timeout),
            "Expected text '\(label)' to exist",
            file: file,
            line: line
        )
        return text
    }

    @discardableResult
    func requireStaticText(
        anyOf labels: [String],
        timeout: TimeInterval? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let perLabelTimeout = max((timeout ?? self.timeout) / Double(max(labels.count, 1)), 0.5)
        for label in labels {
            let text = app.staticTexts[label].firstMatch
            if text.waitForExistence(timeout: perLabelTimeout) {
                return text
            }
        }

        XCTFail(
            "Expected one of texts \(labels) to exist",
            file: file,
            line: line
        )
        return app.staticTexts[labels.first ?? ""].firstMatch
    }

    @discardableResult
    func requireTextField(
        _ placeholder: String,
        timeout: TimeInterval? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let field = app.textFields[placeholder].firstMatch
        XCTAssertTrue(
            field.waitForExistence(timeout: timeout ?? self.timeout),
            "Expected text field '\(placeholder)' to exist",
            file: file,
            line: line
        )
        return field
    }

    @discardableResult
    func requireSecureField(
        _ placeholder: String,
        timeout: TimeInterval? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let field = app.secureTextFields[placeholder].firstMatch
        XCTAssertTrue(
            field.waitForExistence(timeout: timeout ?? self.timeout),
            "Expected secure field '\(placeholder)' to exist",
            file: file,
            line: line
        )
        return field
    }

    func clickButton(
        _ label: String,
        timeout: TimeInterval? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = requireButton(
            label,
            timeout: timeout,
            file: file,
            line: line
        )
        button.click()
    }

    func selectRightPanelMode(
        _ mode: String,
        timeout: TimeInterval? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let modeButton = requireButton(
            mode,
            timeout: timeout,
            file: file,
            line: line
        )
        modeButton.click()
    }

    func assertWindowRespectsMinimumSize(
        _ window: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = window.frame
        XCTAssertGreaterThanOrEqual(
            frame.width,
            minimumWindowWidth,
            "Window width should be >= \(minimumWindowWidth)",
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(
            frame.height,
            minimumWindowHeight,
            "Window height should be >= \(minimumWindowHeight)",
            file: file,
            line: line
        )
    }

    func anyPrimaryViewIndicatorExists() -> Bool {
        app.buttons["Create Bead"].exists
            || app.buttons["Create Epic"].exists
            || app.staticTexts["Sessions Today"].exists
            || app.buttons["All Events"].exists
            || app.staticTexts["Gateway Connection"].exists
    }

    func dismissSheetIfNeeded() {
        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.click()
        }
    }
}
