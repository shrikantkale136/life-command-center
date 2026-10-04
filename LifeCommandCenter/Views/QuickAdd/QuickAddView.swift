import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var type: String
    private let types = ["Task", "Reminder", "Chore", "Grocery item", "Maintenance", "Project", "Subscription", "Bill"]
    var body: some View { NavigationStack { Form { Section { Picker("What would you like to add?", selection: $type) { ForEach(types, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu) }; Section { switch type { case "Task", "Reminder", "Chore": TaskCreateFields(kind: type, done: { dismiss() }); case "Grocery item": GroceryCreateFields(done: { dismiss() }); case "Maintenance": MaintenanceCreateFields(done: { dismiss() }); case "Project": ProjectCreateFields(done: { dismiss() }); case "Subscription": SubscriptionCreateFields(done: { dismiss() }); default: BillCreateFields(done: { dismiss() }) } } }.navigationTitle("Quick add").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } } } }
}

struct TaskCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var title = ""; @State private var date = Date.now; @State private var category = "Personal"; @State private var priority: TaskPriority = .medium; @State private var repeatRule: RepeatRule = .none; @State private var reminder = false
    let kind: String; let done: () -> Void
    var body: some View { TextField("What needs doing?", text: $title); DatePicker("Due", selection: $date, displayedComponents: [.date, .hourAndMinute]); Picker("Category", selection: $category) { ForEach(["Personal", "Work", "Home", "Finance", "Shopping", "Health", "Family", "Other"], id: \.self) { Text($0) } }; Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0) } }; Picker("Repeat", selection: $repeatRule) { ForEach(RepeatRule.allCases) { Text($0.rawValue).tag($0) } }; Toggle("Remind me", isOn: $reminder); Button("Save \(kind)") { guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }; let item = TaskItem(title: title, dueDate: date, priority: priority, category: kind == "Chore" ? "Home" : category, repeatRule: repeatRule, reminderEnabled: reminder); context.insert(item); if reminder { NotificationService.schedule(id: item.persistentModelID.hashValue.description, title: item.title, date: date) }; done() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty) }
}
