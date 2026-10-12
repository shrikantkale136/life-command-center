import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@Model final class TaskItem {
    var completedScheduleDates: [Date] = []
    var title: String
    var detail: String
    var dueDate: Date
    var priorityRaw: String
    var category: String
    var repeatRaw: String
    var isComplete: Bool
    var isSnoozed: Bool
    var createdAt: Date
    var completedAt: Date?
    var reminderEnabled: Bool
    var project: HomeProject?
    init(
        title: String,
        detail: String = "",
        dueDate: Date = .now,
        priority: TaskPriority = .medium,
        category: String = "Personal",
        repeatRule: RepeatRule = .none,
        reminderEnabled: Bool = false,
        project: HomeProject? = nil
    ) {
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
        self.category = category
        self.repeatRaw = repeatRule.rawValue
        self.isComplete = false
        self.isSnoozed = false
        self.createdAt = .now
        self.reminderEnabled = reminderEnabled
        self.project = project
    }
    var priority: TaskPriority {
        TaskPriority(rawValue: priorityRaw) ?? .medium
    }
    var repeatRule: RepeatRule { RepeatRule(rawValue: repeatRaw) ?? .none }
}

@Model final class HomeMaintenance {
    var completedScheduleDates: [Date] = []
    var name: String
    var area: String
    var detail: String
    var nextDue: Date
    var frequencyRaw: String
    var cost: Double
    var provider: String
    var notes: String
    var lastCompleted: Date?
    var dateEnabled: Bool = true
    var timeEnabled: Bool = false
    var timeZoneEnabled: Bool = false
    var timeZoneID: String = ""
    var repeatEndDate: Date? = nil
    var customInterval: Int = 1
    var customIntervalUnitRaw: String = "Days"
    var reminderEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var reminderID: String = UUID().uuidString
    init(
        name: String,
        area: String = "Home",
        detail: String = "",
        nextDue: Date = .now,
        frequency: RepeatRule = .quarterly,
        cost: Double = 0,
        provider: String = "",
        notes: String = "",
        lastCompleted: Date? = nil
    ) {
        self.name = name
        self.area = area
        self.detail = detail
        self.nextDue = nextDue
        self.frequencyRaw = frequency.rawValue
        self.cost = cost
        self.provider = provider
        self.notes = notes
        self.lastCompleted = lastCompleted
    }
    var frequency: MaintenanceFrequency {
        MaintenanceFrequency(rawValue: frequencyRaw) ?? .quarterly
    }
    var customIntervalUnit: MaintenanceIntervalUnit {
        MaintenanceIntervalUnit(rawValue: customIntervalUnitRaw) ?? .days
    }
    var frequencyDescription: String {
        guard frequency == .custom else { return frequency.title }
        let unit = customIntervalUnit.rawValue.lowercased()
        return "Every \(customInterval) \(customInterval == 1 ? String(unit.dropLast()) : unit)"
    }
    var scheduleCalendar: Calendar {
        var calendar = Calendar.current
        if timeEnabled && timeZoneEnabled, let zone = TimeZone(identifier: timeZoneID) {
            calendar.timeZone = zone
        }
        return calendar
    }
    func isWithinRepeatEnd(_ date: Date) -> Bool {
        guard let end = repeatEndDate, frequency != .none else { return true }
        return scheduleCalendar.startOfDay(for: date) <= scheduleCalendar.startOfDay(for: end)
    }
    func nextOccurrence(onOrAfter lowerBound: Date) -> Date? {
        guard dateEnabled else { return nil }
        var date = nextDue
        while date < lowerBound {
            guard let next = nextDate(after: date), next > date else { return nil }
            date = next
        }
        return isWithinRepeatEnd(date) ? date : nil
    }

    func occurrences(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        guard var date = nextOccurrence(onOrAfter: interval.start) else { return [] }
        while date < interval.end {
            if date >= interval.start { result.append(date) }
            guard let next = nextDate(after: date), next > date else { break }
            date = next
        }
        return result
    }

    func nextDate(after date: Date) -> Date? {
        guard dateEnabled,
            let next = frequency.next(
                after: date, interval: customInterval, unit: customIntervalUnit,
                calendar: scheduleCalendar),
            isWithinRepeatEnd(next)
        else { return nil }
        return next
    }
}

@Model final class HomeProject {
    var completedScheduleDates: [Date] = []
    var name: String
    var detail: String
    var area: String
    var startDate: Date
    var targetDate: Date
    var status: String
    var priorityRaw: String
    var estimatedCost: Double
    var actualCost: Double
    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask] = []
    @Relationship(deleteRule: .cascade, inverse: \ProjectShoppingItem.project)
    var shoppingItems: [ProjectShoppingItem] = []
    init(
        name: String,
        detail: String = "",
        area: String = "Home",
        startDate: Date = .now,
        targetDate: Date = .now,
        status: String = "In Progress",
        estimatedCost: Double = 0,
        actualCost: Double = 0
    ) {
        self.name = name
        self.detail = detail
        self.area = area
        self.startDate = startDate
        self.targetDate = targetDate
        self.status = status
        self.priorityRaw = TaskPriority.medium.rawValue
        self.estimatedCost = estimatedCost
        self.actualCost = actualCost
    }
    var progress: Double {
        if status == "Completed" { return 1 }
        return totalItemCount == 0 ? 0 : Double(completedItemCount) / Double(totalItemCount)
    }
    var totalItemCount: Int { tasks.count + shoppingItems.count }
    var completedItemCount: Int {
        tasks.filter(\.isComplete).count + shoppingItems.filter(\.isPurchased).count
    }
    var isComplete: Bool { status == "Completed" }
    var displayStatus: String { status }
    var shoppingEstimate: Double {
        shoppingItems.reduce(0) { $0 + $1.estimatedTotal }
    }
    var orderedTasks: [ProjectTask] {
        tasks.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
    var orderedShoppingItems: [ProjectShoppingItem] {
        shoppingItems.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    func isDue(asOf date: Date = .now, calendar: Calendar = .current) -> Bool {
        !isComplete && calendar.startOfDay(for: targetDate) <= calendar.startOfDay(for: date)
    }
}

@Model final class ProjectTask {
    var title: String
    var isComplete: Bool
    var sortOrder: Int = 0
    var project: HomeProject?
    init(title: String, project: HomeProject? = nil) {
        self.title = title
        self.isComplete = false
        self.project = project
    }
}

@Model final class ProjectShoppingItem {
    var name: String
    var quantity: Int = 1
    var estimatedUnitCost: Double = 0
    var isPurchased: Bool = false
    var sortOrder: Int = 0
    var project: HomeProject?

    init(
        name: String, quantity: Int = 1, estimatedUnitCost: Double = 0, project: HomeProject? = nil
    ) {
        self.name = name
        self.quantity = quantity
        self.estimatedUnitCost = estimatedUnitCost
        self.project = project
    }

    var estimatedTotal: Double { Double(quantity) * estimatedUnitCost }
}

@Model final class SubscriptionItem {
    var completedScheduleDates: [Date] = []
    var name: String
    var category: String
    var cost: Double
    var frequencyRaw: String
    var nextDate: Date
    var paymentMethod: String
    var autoRenew: Bool
    var notes: String
    var isActive: Bool
    init(
        name: String,
        category: String = "Streaming",
        cost: Double = 0,
        frequency: String = "Monthly",
        nextDate: Date = .now,
        paymentMethod: String = "",
        autoRenew: Bool = true,
        notes: String = "",
        isActive: Bool = true
    ) {
        self.name = name
        self.category = category
        self.cost = cost
        self.frequencyRaw = frequency
        self.nextDate = nextDate
        self.paymentMethod = paymentMethod
        self.autoRenew = autoRenew
        self.notes = notes
        self.isActive = isActive
    }
    var monthlyCost: Double {
        switch frequencyRaw {
        case "Weekly": cost * 52 / 12
        case "Quarterly": cost / 3
        case "Semi-Annual": cost / 6
        case "Annual": cost / 12
        default: cost
        }
    }
}

@Model final class BillItem {
    var completedScheduleDates: [Date] = []
    var name: String
    var amount: Double
    var dueDate: Date
    var frequencyRaw: String
    var autoPay: Bool
    var paymentMethod: String
    var notes: String
    init(
        name: String,
        amount: Double = 0,
        dueDate: Date = .now,
        frequency: String = "Monthly",
        autoPay: Bool = false,
        paymentMethod: String = "",
        notes: String = ""
    ) {
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.frequencyRaw = frequency
        self.autoPay = autoPay
        self.paymentMethod = paymentMethod
        self.notes = notes
    }
}

@Model final class GroceryItem {
    var name: String
    var category: String
    var isStaged: Bool
    var isPurchased: Bool = false
    var quantity: Int
    var lastPurchasedAt: Date?
    var createdAt: Date
    init(
        name: String,
        category: String = "Other",
        isStaged: Bool = false,
        isPurchased: Bool = false,
        quantity: Int = 1
    ) {
        self.name = name
        self.category = category
        self.isStaged = isStaged
        self.isPurchased = isPurchased
        self.quantity = quantity
        self.createdAt = .now
    }
}
