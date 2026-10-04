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

    func testQuickAddTaskAppearsOnToday() {
        app.buttons["Quick add"].tap()
        XCTAssertTrue(app.navigationBars["Quick add"].waitForExistence(timeout: 5))
        let title = app.textFields["What needs doing?"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("UI test task")
        app.buttons["Save Task"].tap()
        XCTAssertTrue(app.staticTexts["UI test task"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.navigationBars["Master catalog"].waitForExistence(timeout: 5))
        let milk = app.staticTexts["Milk"]
        XCTAssertTrue(milk.waitForExistence(timeout: 5))
        let addButtons = app.buttons.matching(identifier: "Add")
        XCTAssertTrue(addButtons.firstMatch.exists)
        addButtons.firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Mark Milk purchased"].waitForExistence(timeout: 5))
    }
}
