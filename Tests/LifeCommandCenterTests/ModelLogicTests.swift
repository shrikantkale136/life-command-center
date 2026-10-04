import XCTest
import SwiftUI
@testable import LifeCommandCenter

final class ModelLogicTests: XCTestCase {
    func testTaskPriorityAndRepeatRawValuesHaveSafeDefaults() {
        let task = TaskItem(title: "Test")
        XCTAssertEqual(task.priority, .medium)
        XCTAssertEqual(task.repeatRule, .none)
        task.priorityRaw = "unknown"
        task.repeatRaw = "unknown"
        XCTAssertEqual(task.priority, .medium)
        XCTAssertEqual(task.repeatRule, .none)
    }

    func testProjectProgressAcrossEmptyPartialAndCompleteStates() {
        let project = HomeProject(name: "Paint")
        XCTAssertEqual(project.progress, 0)
        let first = ProjectTask(title: "Prep", project: project)
        let second = ProjectTask(title: "Paint", project: project)
        project.tasks = [first, second]
        XCTAssertEqual(project.progress, 0)
        first.isComplete = true
        XCTAssertEqual(project.progress, 0.5, accuracy: 0.0001)
        second.isComplete = true
        XCTAssertEqual(project.progress, 1)
    }

    func testSubscriptionMonthlyCostNormalizesBillingFrequency() {
        XCTAssertEqual(SubscriptionItem(name: "Weekly", cost: 12, frequency: "Weekly").monthlyCost, 52)
        XCTAssertEqual(SubscriptionItem(name: "Monthly", cost: 12).monthlyCost, 12)
        XCTAssertEqual(SubscriptionItem(name: "Quarterly", cost: 30, frequency: "Quarterly").monthlyCost, 10)
        XCTAssertEqual(SubscriptionItem(name: "Semi", cost: 60, frequency: "Semi-Annual").monthlyCost, 10)
        XCTAssertEqual(SubscriptionItem(name: "Annual", cost: 120, frequency: "Annual").monthlyCost, 10)
        XCTAssertEqual(SubscriptionItem(name: "Other", cost: 8, frequency: "Unexpected").monthlyCost, 8)
    }

    func testAppAppearancePreferencesResolveEveryChoiceAndFallback() {
        XCTAssertEqual(TaskPriority.allCases.count, 4)
        XCTAssertEqual(AppAccentColor.allCases.count, 7)
        XCTAssertEqual(AppAccentColor.color(named: "missing"), AppAccentColor.forest.color)
        XCTAssertEqual(AppFontSize.dynamicTypeSize(for: "Small"), .small)
        XCTAssertEqual(AppFontSize.dynamicTypeSize(for: "Medium"), .large)
        XCTAssertEqual(AppFontSize.dynamicTypeSize(for: "Large"), .xxxLarge)
        XCTAssertEqual(AppFontSize.dynamicTypeSize(for: "bad"), .large)
    }
}
