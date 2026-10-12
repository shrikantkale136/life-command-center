import XCTest

final class HomeManagerFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testTodayDashboardAndCalendarNavigation() {
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add event"].exists)
    }

    func testDailyChecklistSwipesBetweenTodayAndTomorrow() {
        XCTAssertTrue(app.staticTexts["Today's tasks"].waitForExistence(timeout: 10))
        swipeTaskPage(left: true, title: "Buy groceries")
        XCTAssertTrue(app.staticTexts["Tomorrow's tasks"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["schedule-preview-1-Clean garage"].exists)
        swipeTaskPage(left: true, title: "Clean garage")
        XCTAssertTrue(app.staticTexts["This week's tasks"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Buy groceries"].exists)
        XCTAssertFalse(app.staticTexts["Clean garage"].exists)
        swipeTaskPage(left: false, title: "Call plumber")
        XCTAssertTrue(app.staticTexts["Tomorrow's tasks"].waitForExistence(timeout: 5))
        swipeTaskPage(left: false, title: "Clean garage")
        XCTAssertTrue(app.staticTexts["Today's tasks"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Show all'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Coming up"].exists)
        XCTAssertFalse(app.staticTexts["Projects"].exists)
        XCTAssertFalse(app.staticTexts["Monthly subscriptions"].exists)
        XCTAssertEqual(app.scrollViews.count, 1)
        let maintenance = app.buttons["schedule-checklist-Replace HVAC filter"]
        reveal(maintenance)
        XCTAssertEqual(maintenance.value as? String, "Incomplete")
        maintenance.tap()
        XCTAssertEqual(maintenance.value as? String, "Completed")
        maintenance.tap()
        XCTAssertEqual(maintenance.value as? String, "Incomplete")
    }

    private func swipeTaskPage(left: Bool, title: String) {
        let row = app.staticTexts.matching(identifier: title).allElementsBoundByIndex.first { $0.isHittable }!
        let y = row.frame.midY - app.frame.minY
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0))
            .withOffset(CGVector(dx: 0, dy: y))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.15 : 0.85, dy: 0))
            .withOffset(CGVector(dx: 0, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCreateEditProjectChecklistAndShoppingEstimate() {
        XCTAssertTrue(app.staticTexts["Today's tasks"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Home"].tap()
        reveal(app.buttons["Add project"])
        app.buttons["Add project"].tap()
        XCTAssertTrue(app.navigationBars["New project"].waitForExistence(timeout: 8))
        app.textFields["Project name"].tap()
        app.textFields["Project name"].typeText("UI project")
        app.buttons["Done"].tap()
        app.buttons["Add task"].tap()
        let taskTitle = app.textFields["Task title"].exists ? app.textFields["Task title"] : app.textViews["Task title"]
        taskTitle.tap()
        taskTitle.typeText("Install shelf")
        app.buttons["Done"].tap()
        reveal(app.buttons["Add shopping item"])
        app.buttons["Add shopping item"].tap()
        reveal(app.textFields["Shopping item"])
        app.textFields["Shopping item"].tap()
        app.textFields["Shopping item"].typeText("Brackets")
        app.buttons["Done"].tap()
        let quantity = app.textFields["Quantity"]
        reveal(quantity)
        quantity.doubleTap()
        quantity.typeText("2")
        app.buttons["Done"].tap()
        XCTAssertEqual(quantity.value as? String, "2")
        XCTAssertEqual(app.steppers.count, 0)
        let cost = app.textFields["Estimated unit cost"]
        reveal(cost)
        cost.tap()
        cost.typeText("25")
        app.buttons["Done"].tap()
        reveal(app.buttons["Use shopping total as project estimate"])
        app.buttons["Use shopping total as project estimate"].tap()
        capture("Project editor budget")
        app.buttons["Save"].tap()
        let project = app.buttons["project-row-UI project"]
        reveal(project)
        XCTAssertFalse(app.buttons["Complete Install shelf"].exists)
        project.tap()
        XCTAssertTrue(app.navigationBars["Project details"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Complete Install shelf"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mark Brackets purchased"].exists)
        XCTAssertFalse(app.buttons["project-tasks-show-all"].exists)
        XCTAssertFalse(app.buttons["project-shopping-show-all"].exists)
        XCTAssertTrue(app.buttons["project-status-menu"].exists)
        capture("Project lists open by default")
        app.buttons["Complete Install shelf"].tap()
        XCTAssertTrue(app.buttons["Reopen Install shelf"].waitForExistence(timeout: 5))
        reveal(app.buttons["Mark Brackets purchased"])
        app.buttons["Mark Brackets purchased"].tap()
        XCTAssertTrue(app.buttons["Mark Brackets unpurchased"].exists)
        capture("Project landing checklists")
        setProjectStatus("On Hold")
        XCTAssertTrue(app.buttons["Reopen Install shelf"].isEnabled)
        setProjectStatus("Planned")
        XCTAssertTrue(app.buttons["Mark Brackets unpurchased"].isEnabled)
        setProjectStatus("Completed")
        XCTAssertTrue(app.navigationBars["Project details"].exists)
        XCTAssertFalse(app.buttons["Reopen Install shelf"].isEnabled)
        XCTAssertFalse(app.buttons["Mark Brackets unpurchased"].isEnabled)
        capture("Completed project locked lists")
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit project"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Add task"].isEnabled)
        XCTAssertFalse(app.buttons["Status, Completed"].exists)
        for _ in 0..<3 {
            if app.buttons["Add shopping item"].exists { break }
            app.swipeUp()
        }
        XCTAssertFalse(app.buttons["Add shopping item"].isEnabled)
        app.swipeDown()
        app.textFields["Project name"].tap()
        app.textFields["Project name"].typeText(" cancelled")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["UI project"].exists)
        XCTAssertTrue(app.navigationBars["Project details"].exists)
        setProjectStatus("In Progress")
        XCTAssertTrue(app.buttons["Reopen Install shelf"].isEnabled)
        XCTAssertTrue(app.buttons["Mark Brackets unpurchased"].isEnabled)
        app.buttons["Reopen Install shelf"].tap()
        XCTAssertTrue(app.buttons["Complete Install shelf"].waitForExistence(timeout: 5))
    }

    private func setProjectStatus(_ status: String) {
        app.buttons["project-status-menu"].tap()
        app.buttons["project-status-option-\(status)"].tap()
    }

    func testMaintenanceInlineDateTimeAndConditionalEndRepeat() {
        app.buttons["Quick add"].tap()
        XCTAssertTrue(app.navigationBars["Quick add"].waitForExistence(timeout: 8))
        app.buttons["quick-add-type"].tap()
        let maintenance = app.buttons["Maintenance"]
        XCTAssertTrue(maintenance.waitForExistence(timeout: 5))
        maintenance.tap()
        let date = app.switches["maintenance-date-toggle"]
        let time = app.switches["maintenance-time-toggle"]
        XCTAssertTrue(time.waitForExistence(timeout: 5))
        XCTAssertEqual(date.value as? String, "0")
        XCTAssertEqual(time.value as? String, "0")
        XCTAssertFalse(app.buttons["maintenance-end-repeat-picker"].exists)
        time.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let dateEnabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: date)
        XCTAssertEqual(XCTWaiter.wait(for: [dateEnabled], timeout: 5), .completed)
        XCTAssertEqual(date.value as? String, "1")
        XCTAssertEqual(time.value as? String, "1")
        XCTAssertTrue(app.staticTexts["Today"].exists)
        XCTAssertFalse(app.datePickers["maintenance-date-picker"].exists)
        XCTAssertTrue(app.datePickers["maintenance-time-picker"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["Time zone"].exists)
        app.buttons["maintenance-date-focus"].tap()
        XCTAssertTrue(app.datePickers["maintenance-date-picker"].waitForExistence(timeout: 5))
        let timeFocus = app.buttons["maintenance-time-focus"]
        reveal(timeFocus)
        timeFocus.tap()
        XCTAssertTrue(app.datePickers["maintenance-time-picker"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.datePickers["maintenance-date-picker"].exists)
        let repeatPicker = app.buttons["maintenance-repeat-picker"]
        reveal(repeatPicker)
        repeatPicker.tap()
        XCTAssertTrue(app.buttons["Daily"].waitForExistence(timeout: 5))
        app.buttons["Daily"].tap()
        XCTAssertFalse(app.datePickers["maintenance-date-picker"].exists)
        let pickerHidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.datePickers["maintenance-time-picker"])
        XCTAssertEqual(XCTWaiter.wait(for: [pickerHidden], timeout: 5), .completed)
        let endRepeat = app.buttons["maintenance-end-repeat-picker"]
        reveal(endRepeat)
        XCTAssertTrue(endRepeat.exists)
        reveal(repeatPicker)
        repeatPicker.tap()
        XCTAssertTrue(app.buttons["Never"].waitForExistence(timeout: 5))
        app.buttons["Never"].tap()
        XCTAssertFalse(endRepeat.exists)
    }

    func testQuickAddOpensEditor() {
        app.buttons["Quick add"].tap()
        XCTAssertTrue(app.navigationBars["Quick add"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons.matching(identifier: "Save").count, 1)
        for type in ["Maintenance", "Project", "Subscription", "Bill", "Grocery item", "Reminder", "Chore", "Task"] {
            app.buttons["quick-add-type"].tap()
            let option = app.buttons[type]
            if !option.waitForExistence(timeout: 3) { app.buttons["quick-add-type"].tap() }
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            XCTAssertEqual(app.buttons.matching(identifier: "Save").count, 1, "One Save button for \(type)")
        }
        capture("Quick add single Save")
        app.buttons["Close"].tap()
    }

    func testProjectStatusAccordionsAndLongLists() {
        app.tabBars.buttons["Home"].tap()
        reveal(app.buttons["Add project"])
        let inProgress = app.staticTexts["In Progress"].firstMatch
        let planned = app.staticTexts["Planned"].firstMatch
        XCTAssertFalse(app.buttons["project-section-On Hold"].exists)
        XCTAssertFalse(app.buttons["project-section-Completed"].exists)
        XCTAssertLessThan(inProgress.frame.minY, planned.frame.minY)
        XCTAssertTrue(app.buttons["project-row-Garage organization"].exists)
        inProgress.tap()
        XCTAssertFalse(app.buttons["project-row-Garage organization"].exists)
        inProgress.tap()
        XCTAssertTrue(app.buttons["project-row-Garage organization"].exists)
        reveal(planned)
        planned.tap()
        XCTAssertTrue(app.buttons["project-row-Living room painting"].exists)
        planned.tap()
        XCTAssertFalse(app.buttons["project-row-Living room painting"].exists)
        capture("Project status accordions")
        // Return to the Projects heading before opening the editor.
        app.swipeDown()
        reveal(app.buttons["Add project"])
        app.buttons["Add project"].tap()
        app.textFields["Project name"].tap()
        app.textFields["Project name"].typeText("Long lists")
        app.buttons["Done"].tap()
        for number in 1...7 {
            reveal(app.buttons["Add task"])
            app.buttons["Add task"].tap()
            let field = app.descendants(matching: .any).matching(NSPredicate(
                format: "placeholderValue == %@ AND (value == %@ OR value == %@)",
                "Task title", "", "Task title")).firstMatch
            reveal(field)
            field.tap()
            field.typeText("Task \(number)")
            app.buttons["Done"].tap()
        }
        for number in 1...7 {
            reveal(app.buttons["Add shopping item"])
            app.buttons["Add shopping item"].tap()
            let fields = app.textFields.matching(identifier: "Shopping item")
            let field = fields.element(boundBy: fields.count - 1)
            reveal(field)
            field.tap()
            field.typeText("Supply \(number)")
            app.buttons["Done"].tap()
        }
        app.buttons["Save"].tap()
        let project = app.buttons["project-row-Long lists"]
        reveal(project)
        project.tap()
        XCTAssertTrue(app.navigationBars["Project details"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Complete Task 6"].exists)
        XCTAssertFalse(app.buttons["Complete Task 7"].exists)
        let allTasks = app.buttons["project-tasks-show-all"]
        reveal(allTasks)
        allTasks.tap()
        XCTAssertTrue(app.buttons["Complete Task 7"].exists)
        reveal(allTasks)
        allTasks.tap()
        XCTAssertFalse(app.buttons["Complete Task 7"].exists)
        XCTAssertTrue(app.buttons["Mark Supply 6 purchased"].exists)
        XCTAssertFalse(app.buttons["Mark Supply 7 purchased"].exists)
        let allShopping = app.buttons["project-shopping-show-all"]
        reveal(allShopping)
        allShopping.tap()
        XCTAssertTrue(app.buttons["Mark Supply 7 purchased"].exists)
        capture("Shopping show all")
        reveal(allShopping)
        allShopping.tap()
        XCTAssertFalse(app.buttons["Mark Supply 7 purchased"].exists)
    }

    func testMaintenanceCanEditSaveAndCancel() {
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        app.staticTexts["Replace HVAC filter"].tap()
        XCTAssertTrue(app.navigationBars["Edit maintenance"].waitForExistence(timeout: 8))
        let name = app.textFields["Maintenance item"]
        name.tap()
        name.typeText(" updated")
        app.buttons["Done"].tap()
        let provider = app.textFields["Provider"]
        reveal(provider)
        provider.tap()
        provider.typeText("Local service")
        app.buttons["Done"].tap()
        capture("Maintenance editor")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Replace HVAC filter updated"].waitForExistence(timeout: 5))
        app.staticTexts["Replace HVAC filter updated"].tap()
        reveal(app.textFields["Provider"])
        XCTAssertEqual(app.textFields["Provider"].value as? String, "Local service")
        app.swipeDown()
        app.swipeDown()
        app.textFields["Maintenance item"].tap()
        app.textFields["Maintenance item"].typeText(" cancelled")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Replace HVAC filter updated"].exists)
        XCTAssertFalse(app.staticTexts["Replace HVAC filter updated cancelled"].exists)
        capture("Compact Home lists")
    }

    func testHomeProjectAddOpensProjectEditor() {
        app.tabBars.buttons["Home"].tap()
        reveal(app.buttons["Add project"])
        app.buttons["Add project"].tap()
        XCTAssertTrue(app.navigationBars["New project"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Project name"].exists)
        app.buttons["Cancel"].tap()
    }

    func testMainTabsOpenTheirPrimaryScreens() {
        app.tabBars.buttons["Groceries"].tap()
        XCTAssertTrue(app.navigationBars["Groceries"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Money"].tap()
        XCTAssertTrue(app.navigationBars["Money"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testShoppingCatalogStagesAnItemAndShoppingCompletionFlow() {
        app.tabBars.buttons["Groceries"].tap()
        app.buttons["Open Master Catalog"].tap()
        XCTAssertTrue(app.navigationBars["Master Catalog"].waitForExistence(timeout: 5))
        let milk = app.staticTexts["Milk"]
        XCTAssertTrue(milk.waitForExistence(timeout: 5))
        let addButtons = app.buttons.matching(identifier: "Add")
        XCTAssertTrue(addButtons.firstMatch.exists)
        addButtons.firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Mark Milk purchased"].waitForExistence(timeout: 5))
    }
}
