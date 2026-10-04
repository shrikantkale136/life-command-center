import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

@Model final class TaskItem {
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
    init(title: String, detail: String = "", dueDate: Date = .now, priority: TaskPriority = .medium, category: String = "Personal", repeatRule: RepeatRule = .none, reminderEnabled: Bool = false, project: HomeProject? = nil) {
        self.title = title; self.detail = detail; self.dueDate = dueDate; self.priorityRaw = priority.rawValue
        self.category = category; self.repeatRaw = repeatRule.rawValue; self.isComplete = false; self.isSnoozed = false
        self.createdAt = .now; self.reminderEnabled = reminderEnabled; self.project = project
    }
    var priority: TaskPriority { TaskPriority(rawValue: priorityRaw) ?? .medium }
    var repeatRule: RepeatRule { RepeatRule(rawValue: repeatRaw) ?? .none }
}

@Model final class HomeMaintenance {
    var name: String; var area: String; var detail: String; var nextDue: Date; var frequencyRaw: String
    var cost: Double; var provider: String; var notes: String; var lastCompleted: Date?
    init(name: String, area: String = "Home", detail: String = "", nextDue: Date = .now, frequency: RepeatRule = .quarterly, cost: Double = 0, provider: String = "", notes: String = "", lastCompleted: Date? = nil) {
        self.name = name; self.area = area; self.detail = detail; self.nextDue = nextDue; self.frequencyRaw = frequency.rawValue
        self.cost = cost; self.provider = provider; self.notes = notes; self.lastCompleted = lastCompleted
    }
}

@Model final class HomeProject {
    var name: String; var detail: String; var area: String; var startDate: Date; var targetDate: Date
    var status: String; var priorityRaw: String; var estimatedCost: Double; var actualCost: Double
    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project) var tasks: [ProjectTask] = []
    init(name: String, detail: String = "", area: String = "Home", startDate: Date = .now, targetDate: Date = .now, status: String = "In Progress", estimatedCost: Double = 0, actualCost: Double = 0) {
        self.name = name; self.detail = detail; self.area = area; self.startDate = startDate; self.targetDate = targetDate
        self.status = status; self.priorityRaw = TaskPriority.medium.rawValue; self.estimatedCost = estimatedCost; self.actualCost = actualCost
    }
    var progress: Double { tasks.isEmpty ? 0 : Double(tasks.filter(\.isComplete).count) / Double(tasks.count) }
}

@Model final class ProjectTask {
    var title: String; var isComplete: Bool; var project: HomeProject?
    init(title: String, project: HomeProject? = nil) { self.title = title; self.isComplete = false; self.project = project }
}

@Model final class SubscriptionItem {
    var name: String; var category: String; var cost: Double; var frequencyRaw: String; var nextDate: Date
    var paymentMethod: String; var autoRenew: Bool; var notes: String; var isActive: Bool
    init(name: String, category: String = "Streaming", cost: Double = 0, frequency: String = "Monthly", nextDate: Date = .now, paymentMethod: String = "", autoRenew: Bool = true, notes: String = "", isActive: Bool = true) {
        self.name = name; self.category = category; self.cost = cost; self.frequencyRaw = frequency; self.nextDate = nextDate
        self.paymentMethod = paymentMethod; self.autoRenew = autoRenew; self.notes = notes; self.isActive = isActive
    }
    var monthlyCost: Double { switch frequencyRaw { case "Weekly": cost * 52 / 12; case "Quarterly": cost / 3; case "Semi-Annual": cost / 6; case "Annual": cost / 12; default: cost } }
}

@Model final class BillItem {
    var name: String; var amount: Double; var dueDate: Date; var frequencyRaw: String; var autoPay: Bool; var paymentMethod: String; var notes: String
    init(name: String, amount: Double = 0, dueDate: Date = .now, frequency: String = "Monthly", autoPay: Bool = false, paymentMethod: String = "", notes: String = "") {
        self.name = name; self.amount = amount; self.dueDate = dueDate; self.frequencyRaw = frequency; self.autoPay = autoPay; self.paymentMethod = paymentMethod; self.notes = notes
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
    init(name: String, category: String = "Other", isStaged: Bool = false, isPurchased: Bool = false, quantity: Int = 1) {
        self.name = name
        self.category = category
        self.isStaged = isStaged
        self.isPurchased = isPurchased
        self.quantity = quantity
        self.createdAt = .now
    }
}
