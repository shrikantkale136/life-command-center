import XCTest

final class SettingsFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
    }
    override func tearDownWithError() throws { app.terminate() }
    private func open(_ identifier: String, title: String) {
        if ["settings-color", "settings-text-size", "settings-opening", "settings-start-page"].contains(identifier),
           app.buttons["settings-appearance"].isHittable {
            open("settings-appearance", title: "Appearance")
        }
        let row = app.buttons[identifier]
        for _ in 0..<8 {
            if row.exists && row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }
    private func back() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: back)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 6), .completed)
        back.tap()
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testAllSettingsDestinationsAndOpeningPreview() {
        capture("Settings hub")
        let screens = [("appearance", "Appearance"),
                       ("accessibility", "Accessibility"), ("task-defaults", "Task defaults"), ("reminders", "Reminders"),
                       ("app-lock", "App lock"), ("backup", "Backup & restore"), ("help", "Help & feedback"), ("about", "About")]
        for (identifier, title) in screens {
            open("settings-" + identifier, title: title)
            if identifier == "appearance" {
                for (child, childTitle) in [("color", "Text color"), ("text-size", "Text size"), ("opening", "Opening screen"), ("start-page", "Start page")] {
                    open("settings-" + child, title: childTitle)
                    if child == "opening" {
                        app.buttons["Preview opening screen"].tap()
                        XCTAssertTrue(app.descendants(matching: .any)["branded-opening-screen"].exists)
                        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["Preview opening screen"])
                        XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 6), .completed)
                    }
                    back()
                }
            }
            if identifier == "appearance" || identifier == "backup" { capture(title) }
            back()
        }
        let tools = app.buttons["visiting-cards-library"]
        for _ in 0..<6 { if tools.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(tools.exists)
    }
    func testProfilePersistenceAndTaskDefaultsApplyToNewTask() {
        app.buttons["settings-profile"].tap()
        let name = app.textFields["preferred-name"]
        name.tap()
        if let value = name.value as? String, value != "Your name", !value.isEmpty {
            name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        name.typeText("Alex Settings")
        back()
        XCTAssertTrue(app.staticTexts["Alex Settings"].exists)
        open("settings-task-defaults", title: "Task defaults")
        app.buttons["default-priority"].tap(); app.buttons["High"].tap()
        app.buttons["default-category"].tap(); app.buttons["Work"].tap()
        back()
        app.tabBars.buttons["Today"].tap()
        app.buttons["Quick add"].tap()
        XCTAssertTrue(app.buttons["new-task-priority"].label.contains("High"))
        XCTAssertTrue(app.buttons["new-task-category"].label.contains("Work"))
        app.buttons["Close"].tap()
    }
    func testLiveColorSelectionKeepsNavigationAndUpdatesExistingPages() {
        open("settings-color", title: "Text color")
        let monitor = addUIInterruptionMonitor(withDescription: "Icon update") { alert in
            if alert.buttons["OK"].exists { alert.buttons["OK"].tap(); return true }
            return false
        }
        defer { removeUIInterruptionMonitor(monitor) }
        app.buttons["Blue app color"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.buttons["OK"].waitForExistence(timeout: 3) { springboard.alerts.buttons["OK"].tap() }
        XCTAssertTrue(app.navigationBars["Text color"].exists, "Selecting a color must not reset navigation")
        XCTAssertTrue(app.buttons["Blue app color"].isSelected)
        capture("Blue applied immediately")
        app.buttons["Teal app color"].tap()
        if springboard.alerts.buttons["OK"].waitForExistence(timeout: 3) { springboard.alerts.buttons["OK"].tap() }
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: app.buttons["Teal app color"])
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 4), .completed)
        capture("Teal applied immediately")
        back()
        XCTAssertFalse(app.buttons["settings-color"].label.contains("Custom"))
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["Quick add"].exists)
        capture("Existing Today page with new accent")
        app.buttons["Quick add"].tap()
        XCTAssertTrue(app.navigationBars["Quick add"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
    }

    func testVisibleTextSizePaletteAndPersonalization() {
        XCTAssertFalse(app.buttons["settings-text-size"].exists)
        open("settings-text-size", title: "Text size")
        XCTAssertTrue(app.segmentedControls["font-size-picker"].exists)
        back()
        open("settings-color", title: "Text color")
        XCTAssertTrue(app.buttons["Forest app color"].exists)
        XCTAssertTrue(app.buttons["Teal app color"].exists)
        app.buttons["add-custom-color"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["custom-color-picker"].waitForExistence(timeout: 5))
        app.buttons["close"].tap()
        capture("Preferred color palette")
        back()
        back()
        app.buttons["settings-profile"].tap()
        XCTAssertTrue(app.switches["Use my name in greetings"].exists)
        XCTAssertTrue(app.switches["Use my name in reminders"].exists)
        capture("Personalized profile")
    }

    func testAddCustomColorRequiresSeparateSelectionAndPersists() {
        open("settings-color", title: "Text color")
        XCTAssertFalse(app.buttons["create-color-palette"].exists)
        let originalSelection = app.buttons.matching(NSPredicate(format: "isSelected == true")).allElementsBoundByIndex.map(\.identifier)
        app.buttons["add-custom-color"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["custom-color-picker"].waitForExistence(timeout: 5))
        app.buttons["Sliders"].tap()
        capture("Native custom color picker")
        // The native picker exposes the RGB fields followed by its hex field.
        let hex = app.textFields.element(boundBy: 3)
        let chosenHex = String(UUID().uuidString.prefix(6))
        XCTAssertTrue(hex.exists)
        hex.tap()
        let old = hex.value as? String ?? ""
        hex.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + chosenHex)
        capture("Add color without applying it")
        app.buttons["save-custom-color"].tap()
        let color = app.buttons["saved-color-#" + chosenHex]
        XCTAssertTrue(color.waitForExistence(timeout: 5))
        XCTAssertFalse(color.isSelected, "Adding a color must not apply it")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "isSelected == true")).allElementsBoundByIndex.map(\.identifier), originalSelection)
        color.tap()
        XCTAssertTrue(color.isSelected)
        capture("Compact palette with saved custom color")
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        open("settings-color", title: "Text color")
        let restored = app.buttons["saved-color-#" + chosenHex]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        restored.tap()
        XCTAssertTrue(restored.isSelected)
        XCTAssertTrue(app.navigationBars["Text color"].exists)
    }

    func testThemeDropdownAndColorDotSummary() {
        open("settings-appearance", title: "Appearance")
        XCTAssertTrue(app.buttons["theme-picker"].exists)
        app.buttons["theme-picker"].tap()
        XCTAssertTrue(app.buttons["Light"].waitForExistence(timeout: 5))
        app.buttons["Light"].tap()
        XCTAssertTrue(app.buttons["theme-picker"].label.contains("Light"))
        XCTAssertTrue(app.buttons["settings-color"].label.contains("Text color"))
        XCTAssertFalse(app.buttons["settings-color"].label.contains("Custom"))
        capture("Theme dropdown and text color dot")
        app.buttons["theme-picker"].tap()
        app.buttons["System"].tap()
    }

    func testDarkAppearanceAndLargeTextLayout() {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-appearance", "Dark", "-followSystemTextSize", "NO", "-appFontSize", "Large"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        capture("Settings dark with large text")
        open("settings-appearance", title: "Appearance")
        XCTAssertTrue(app.staticTexts["Live preview"].exists)
        capture("Appearance dark with large text")
    }

    func testBackupExportValidationAndFeedbackDraft() {
        open("settings-backup", title: "Backup & restore")
        XCTAssertFalse(app.buttons["Export backup"].isEnabled)
        app.secureTextFields["Backup password"].tap(); app.secureTextFields["Backup password"].typeText("backup-password-123")
        app.secureTextFields["Confirm password"].tap(); app.secureTextFields["Confirm password"].typeText("different")
        XCTAssertFalse(app.buttons["Export backup"].isEnabled)
        back()
        open("settings-help", title: "Help & feedback")
        app.buttons["Report a problem"].tap()
        XCTAssertTrue(app.navigationBars["Feedback"].waitForExistence(timeout: 5))
        let draft = app.textViews["Feedback draft"]
        XCTAssertTrue((draft.value as? String)?.contains("Home Manager") == true)
        XCTAssertTrue((draft.value as? String)?.contains("iOS") == true)
        app.buttons["Cancel"].tap()
    }
}
