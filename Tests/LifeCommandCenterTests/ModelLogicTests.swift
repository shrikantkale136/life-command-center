import XCTest
import UserNotifications
import SwiftUI
@testable import LifeCommandCenter

final class ModelLogicTests: XCTestCase {
    func testMaintenanceWeekdayWeekendAndHourlyRules() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 9))!
        XCTAssertEqual(MaintenanceFrequency.weekdays.next(after: friday, calendar: calendar), calendar.date(byAdding: .day, value: 3, to: friday))
        let saturday = MaintenanceFrequency.weekends.next(after: friday, calendar: calendar)!
        let sunday = MaintenanceFrequency.weekends.next(after: saturday, calendar: calendar)!
        XCTAssertEqual(calendar.component(.weekday, from: saturday), 7)
        XCTAssertEqual(calendar.component(.weekday, from: sunday), 1)
        XCTAssertEqual(MaintenanceFrequency.weekends.next(after: sunday, calendar: calendar), calendar.date(byAdding: .day, value: 6, to: sunday))
        XCTAssertEqual(MaintenanceFrequency.hourly.next(after: friday, calendar: calendar), friday.addingTimeInterval(3600))
    }

    @MainActor
    func testTimeToggleSelectsTodayAndHourlyNotificationsKeepDistinctTimes() {
        var draft = MaintenanceDraft()
        XCTAssertFalse(draft.dateEnabled)
        XCTAssertFalse(draft.timeEnabled)
        XCTAssertEqual(draft.frequency, .none)
        let now = Date.now
        draft.setTimeEnabled(true, now: now)
        XCTAssertTrue(draft.dateEnabled)
        XCTAssertEqual(draft.nextDue, now)
        XCTAssertEqual(draft.dateSubtitle, "Today")
        let item = HomeMaintenance(name: "Hourly", nextDue: now.addingTimeInterval(7200))
        item.frequencyRaw = MaintenanceFrequency.hourly.rawValue
        item.timeEnabled = true
        item.reminderEnabled = true
        let requests = NotificationService.makeMaintenanceRequests(for: item)
        XCTAssertEqual(requests.count, 12)
        let first = (requests[0].trigger as! UNCalendarNotificationTrigger).nextTriggerDate()!
        let second = (requests[1].trigger as! UNCalendarNotificationTrigger).nextTriggerDate()!
        XCTAssertEqual(second.timeIntervalSince(first), 3600, accuracy: 1)
    }

    @MainActor
    func testMaintenanceTimeZoneRepeatEndAndDateToggle() {
        let item = HomeMaintenance(name: "Filter")
        item.timeEnabled = true
        item.timeZoneEnabled = true
        item.timeZoneID = "America/New_York"
        item.frequencyRaw = MaintenanceFrequency.daily.rawValue
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: item.timeZoneID)!
        item.nextDue = calendar.date(from: DateComponents(year: 2030, month: 3, day: 9, hour: 9))!
        item.repeatEndDate = calendar.date(from: DateComponents(year: 2030, month: 3, day: 11))!
        let end = calendar.date(byAdding: .day, value: 5, to: item.nextDue)!
        let occurrences = item.occurrences(in: DateInterval(start: calendar.startOfDay(for: item.nextDue), end: end))
        XCTAssertEqual(occurrences.count, 3)
        XCTAssertTrue(occurrences.allSatisfy { calendar.component(.hour, from: $0) == 9 })
        XCTAssertNil(item.nextDate(after: occurrences.last!))
        item.reminderEnabled = true
        let requests = NotificationService.makeMaintenanceRequests(for: item)
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual((requests[0].trigger as! UNCalendarNotificationTrigger).dateComponents.timeZone?.identifier, item.timeZoneID)
        item.dateEnabled = false
        XCTAssertNil(item.nextOccurrence(onOrAfter: item.nextDue))
        XCTAssertTrue(item.occurrences(in: DateInterval(start: item.nextDue, end: end)).isEmpty)
        XCTAssertTrue(NotificationService.makeMaintenanceRequests(for: item).isEmpty)
        item.dateEnabled = true
        item.repeatEndDate = nil
        XCTAssertEqual(item.occurrences(in: DateInterval(start: calendar.startOfDay(for: item.nextDue), end: end)).count, 5)
    }

    func testDashboardWeekExcludesTodayAndTomorrowAndStopsAtWeekBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
        let interval = TodayView.scheduleInterval(for: 2, asOf: monday, calendar: calendar)
        XCTAssertEqual(interval.start, calendar.date(from: DateComponents(year: 2026, month: 10, day: 14)))
        XCTAssertEqual(interval.end, calendar.date(from: DateComponents(year: 2026, month: 10, day: 18)))
        for day in [16,17] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!
            XCTAssertEqual(TodayView.scheduleInterval(for: 2, asOf: date, calendar: calendar).duration, 0)
        }
    }

    @MainActor
    func testScheduledChecklistsToggleEachOccurrenceIndependently() {
        let start = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let maintenance = HomeMaintenance(name: "Filter", nextDue: start)
        let todayRecord = CalendarRecord.maintenance(maintenance, start)
        let tomorrowRecord = CalendarRecord.maintenance(maintenance, tomorrow)
        let bill = BillItem(name: "Bill", dueDate: start)
        let subscription = SubscriptionItem(name: "Renewal", nextDate: start)
        let project = HomeProject(name: "Project", targetDate: start)
        for record in [todayRecord, CalendarRecord.bill(bill), .subscription(subscription), .project(project)] {
            XCTAssertFalse(record.isComplete)
            record.toggleChecklistCompletion()
            XCTAssertTrue(record.isComplete)
            record.toggleChecklistCompletion()
            XCTAssertFalse(record.isComplete)
        }
        todayRecord.toggleChecklistCompletion()
        XCTAssertFalse(tomorrowRecord.isComplete)
        XCTAssertEqual(maintenance.nextDue, start)
        XCTAssertEqual(project.status, "In Progress", "Daily checklist completion does not change project status")
    }

    @MainActor
    func testCalendarIncludesEveryRecordTypeAndCalculatedMaintenanceDates() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 29, to: start)!
        let item = HomeMaintenance(name: "Filter", nextDue: start)
        item.frequencyRaw = MaintenanceFrequency.biweekly.rawValue
        let task = TaskItem(title: "Task", dueDate: start)
        let bill = BillItem(name: "Bill", dueDate: start)
        let subscription = SubscriptionItem(name: "Renewal", nextDate: start)
        let project = HomeProject(name: "Project", targetDate: start)
        let records = CalendarRecord.records(tasks: [task], bills: [bill], subscriptions: [subscription], maintenance: [item], projects: [project], in: DateInterval(start: start, end: end))
        XCTAssertEqual(records.count, 7)
        XCTAssertEqual(Set(records.map(\.id)).count, 7)
        XCTAssertEqual(item.occurrences(in: DateInterval(start: start, end: end)), [0,14,28].map { calendar.date(byAdding: .day, value: $0, to: start)! })
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start)!
        XCTAssertEqual(item.nextOccurrence(onOrAfter: nextDay), calendar.date(byAdding: .day, value: 14, to: start))
        XCTAssertEqual(item.nextDue, start, "Calculating the next due date preserves the schedule anchor")
        item.frequencyRaw = MaintenanceFrequency.custom.rawValue
        item.customInterval = 10
        item.customIntervalUnitRaw = MaintenanceIntervalUnit.days.rawValue
        XCTAssertEqual(item.occurrences(in: DateInterval(start: start, end: end)).count, 3)
        item.frequencyRaw = MaintenanceFrequency.none.rawValue
        XCTAssertEqual(item.occurrences(in: DateInterval(start: start, end: end)), [start])
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start)!
        XCTAssertTrue(item.occurrences(in: DateInterval(start: tomorrow, end: end)).isEmpty)
        XCTAssertNil(item.nextOccurrence(onOrAfter: tomorrow))
    }

    func testMaintenanceIntervalsUseCalendarDates() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2030, month: 1, day: 31))!
        XCTAssertEqual(MaintenanceFrequency.biweekly.next(after: start, calendar: calendar), calendar.date(byAdding: .day, value: 14, to: start))
        XCTAssertEqual(MaintenanceFrequency.semiannual.next(after: start, calendar: calendar), calendar.date(byAdding: .month, value: 6, to: start))
        for unit in MaintenanceIntervalUnit.allCases {
            XCTAssertEqual(MaintenanceFrequency.custom.next(after: start, interval: 3, unit: unit, calendar: calendar), calendar.date(byAdding: unit.component, value: 3, to: start))
        }
        XCTAssertNil(MaintenanceFrequency.custom.next(after: start, interval: 0))
        XCTAssertNil(MaintenanceFrequency.none.next(after: start))
    }

    @MainActor
    func testMaintenanceRemindersAreOptionalAndFollowCustomSchedule() {
        let item = HomeMaintenance(name: "Replace filter", nextDue: Calendar.current.date(byAdding: .day, value: 2, to: .now)!)
        XCTAssertTrue(NotificationService.makeMaintenanceRequests(for: item).isEmpty)
        item.reminderEnabled = true
        item.frequencyRaw = MaintenanceFrequency.custom.rawValue
        item.customInterval = 3
        item.customIntervalUnitRaw = MaintenanceIntervalUnit.weeks.rawValue
        item.reminderHour = 14
        item.reminderMinute = 30
        let requests = NotificationService.makeMaintenanceRequests(for: item)
        XCTAssertEqual(requests.count, 12)
        let first = (requests[0].trigger as! UNCalendarNotificationTrigger).nextTriggerDate()!
        let second = (requests[1].trigger as! UNCalendarNotificationTrigger).nextTriggerDate()!
        XCTAssertEqual(Calendar.current.component(.hour, from: first), 14)
        XCTAssertEqual(Calendar.current.component(.minute, from: first), 30)
        XCTAssertEqual(second, Calendar.current.date(byAdding: .weekOfYear, value: 3, to: first))
        XCTAssertEqual(requests.map(\.identifier), NotificationService.makeMaintenanceRequests(for: item).map(\.identifier))
        item.frequencyRaw = MaintenanceFrequency.none.rawValue
        XCTAssertEqual(NotificationService.makeMaintenanceRequests(for: item).count, 1)
        item.reminderEnabled = false
        XCTAssertTrue(NotificationService.makeMaintenanceRequests(for: item).isEmpty)
    }

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
        XCTAssertEqual(project.displayStatus, "In Progress")
        XCTAssertFalse(project.isComplete)
        project.status = "Completed"
        XCTAssertTrue(project.isComplete)
        project.status = "On Hold"
        XCTAssertFalse(project.isComplete)
        XCTAssertEqual(project.displayStatus, "On Hold")
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

    func testProjectDueCountsExcludeCompletedAndUseCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 10))!
        let project = HomeProject(name: "Due today", targetDate: today.addingTimeInterval(3600))
        XCTAssertTrue(project.isDue(asOf: today, calendar: calendar))
        project.targetDate = today.addingTimeInterval(-86400)
        XCTAssertTrue(project.isDue(asOf: today, calendar: calendar))
        project.targetDate = today.addingTimeInterval(86400)
        XCTAssertFalse(project.isDue(asOf: today, calendar: calendar))
        project.targetDate = today
        project.status = "Completed"
        XCTAssertEqual(project.progress, 1)
        XCTAssertFalse(project.isDue(asOf: today, calendar: calendar))
        project.status = "Planned"
        let task = ProjectTask(title: "Finish", project: project)
        project.tasks = [task]
        task.isComplete = true
        XCTAssertEqual(project.displayStatus, "Planned")
        XCTAssertFalse(project.isComplete)
        XCTAssertTrue(project.isDue(asOf: today, calendar: calendar))
        task.isComplete = false
        XCTAssertTrue(project.isDue(asOf: today, calendar: calendar))
    }

    func testShoppingEstimateAndDraftCostValidation() {
        let project = HomeProject(name: "Shelves")
        let item = ProjectShoppingItem(name: "Bracket", quantity: 3, estimatedUnitCost: 12.5, project: project)
        project.shoppingItems = [item]
        XCTAssertEqual(project.shoppingEstimate, 37.5)
        item.isPurchased = true
        XCTAssertEqual(project.shoppingEstimate, 37.5)
        XCTAssertEqual(project.progress, 0)
        var draft = ProjectDraft(project: project)
        XCTAssertTrue(draft.canSave)
        draft.estimatedCost = "-10"
        XCTAssertFalse(draft.canSave)
        draft.estimatedCost = "NaN"
        XCTAssertFalse(draft.canSave)
        draft.estimatedCost = "abc"
        XCTAssertFalse(draft.canSave)
        draft.estimatedCost = ""
        draft.name = "   "
        XCTAssertFalse(draft.canSave)
    }
}
