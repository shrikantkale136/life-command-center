import Foundation
import SwiftData

struct SampleDataRepository {
    let context: ModelContext

    func seedGroceryCatalogIfNeeded(hasSeeded: Bool, isEmpty: Bool, markSeeded: () -> Void) {
        guard !hasSeeded, isEmpty else { return }
        [
            GroceryItem(name: "Milk", category: "Dairy & Eggs"),
            GroceryItem(name: "Eggs", category: "Dairy & Eggs"),
            GroceryItem(name: "Rice", category: "Pantry"),
            GroceryItem(name: "Bread", category: "Bakery"),
            GroceryItem(name: "Bananas", category: "Produce"),
            GroceryItem(name: "Coffee", category: "Pantry")
        ].forEach { context.insert($0) }
        markSeeded()
    }

    func seedSampleDataIfNeeded(hasSeeded: Bool, isEmpty: Bool, markSeeded: () -> Void) {
        guard !hasSeeded else { return }
        markSeeded()
        guard isEmpty else { return }

        let calendar = Calendar.current
        let tasks = [
            TaskItem(title: "Buy groceries", dueDate: .now, category: "Shopping", reminderEnabled: false),
            TaskItem(title: "Pay water bill", dueDate: .now, priority: .high, category: "Finance"),
            TaskItem(title: "Clean garage", dueDate: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now, category: "Home"),
            TaskItem(title: "Call plumber", dueDate: calendar.date(byAdding: .day, value: 2, to: .now) ?? .now, priority: .high, category: "Home"),
            TaskItem(title: "Take trash out", dueDate: .now, category: "Home", repeatRule: .weekly)
        ]
        tasks.forEach { context.insert($0) }

        context.insert(HomeMaintenance(name: "Replace HVAC filter", area: "HVAC", nextDue: .now, frequency: .quarterly, lastCompleted: calendar.date(byAdding: .month, value: -3, to: .now)))
        context.insert(HomeMaintenance(name: "Clean gutters", area: "Exterior", nextDue: calendar.date(byAdding: .day, value: 4, to: .now) ?? .now, frequency: .quarterly))

        let garageProject = HomeProject(name: "Garage organization", detail: "Make room for projects and tools", area: "Garage", targetDate: calendar.date(byAdding: .day, value: 14, to: .now) ?? .now, estimatedCost: 450)
        context.insert(garageProject)
        ["Measure wall", "Buy shelves", "Assemble shelves", "Sort tools", "Donate extras"].forEach { title in
            let task = ProjectTask(title: title, project: garageProject)
            garageProject.tasks.append(task)
            context.insert(task)
        }
        context.insert(HomeProject(name: "Living room painting", area: "Living Room", targetDate: calendar.date(byAdding: .day, value: 30, to: .now) ?? .now, status: "Planned", estimatedCost: 700))

        context.insert(SubscriptionItem(name: "Netflix", cost: 22.99, nextDate: calendar.date(byAdding: .day, value: 3, to: .now) ?? .now))
        context.insert(SubscriptionItem(name: "Spotify", category: "Music", cost: 11.99, nextDate: calendar.date(byAdding: .day, value: 6, to: .now) ?? .now))
        context.insert(SubscriptionItem(name: "iCloud", category: "Software", cost: 2.99, nextDate: calendar.date(byAdding: .day, value: 10, to: .now) ?? .now))
        context.insert(BillItem(name: "Internet", amount: 80, dueDate: calendar.date(byAdding: .day, value: 3, to: .now) ?? .now))
        context.insert(BillItem(name: "Electricity", amount: 96.40, dueDate: calendar.date(byAdding: .day, value: 7, to: .now) ?? .now))
        context.insert(BillItem(name: "Mortgage", amount: 3200, dueDate: calendar.date(byAdding: .day, value: 12, to: .now) ?? .now))
    }
}
