import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var type: String
    private let types = [
        "Task", "Reminder", "Chore", "Grocery item", "Maintenance", "Project",
        "Subscription", "Bill", "Visiting Card",
    ]
    var body: some View {
        if type == "Visiting Card" { VisitingCardEditor() }
        else { standardQuickAdd }
    }
    private var standardQuickAdd: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("What would you like to add?", selection: $type) {
                        ForEach(types, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).accessibilityIdentifier("quick-add-type")
                }
                if type == "Project" {
                    ProjectCreateFields(done: { dismiss() })
                } else if type == "Maintenance" {
                    MaintenanceCreateFields(done: { dismiss() })
                } else {
                    Section {
                        switch type {
                        case "Task", "Reminder", "Chore":
                            TaskCreateFields(kind: type, done: { dismiss() })
                        case "Grocery item":
                            GroceryCreateFields(done: { dismiss() })
                        case "Subscription":
                            SubscriptionCreateFields(done: { dismiss() })
                        default: BillCreateFields(done: { dismiss() })
                        }
                    }
                }
            }
            .navigationTitle("Quick add").navigationBarTitleDisplayMode(
                .inline
            ).toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FormCancelButton(label: "Close")
                }.formIconBackground()
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil,
                            for: nil)
                    }
                }
            }
        }.formDiscardProtection()
    }
}

struct TaskCreateFields: View {
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var date = Date.now
    @State private var category = AppPreferences().category
    @State private var priority: TaskPriority = AppPreferences().priority
    @State private var repeatRule: RepeatRule = .none
    @State private var reminder = AppPreferences().taskReminders
    @State private var saveError: String?
    let kind: String
    let done: () -> Void
    var body: some View {
        Group {

            TextField("What needs doing?", text: $title).toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                            return
                        }
                        let item = TaskItem(
                            title: title,
                            dueDate: date,
                            priority: priority,
                            category: kind == "Chore" ? "Home" : category,
                            repeatRule: repeatRule,
                            reminderEnabled: reminder
                        )
                        context.insert(item)
                        do { try context.save() }
                        catch { context.delete(item); saveError = error.localizedDescription; return }
                        if reminder {
                            NotificationService.schedule(
                                id: NotificationService.taskID(item),
                                title: item.title,
                                date: date
                            )
                        }
                        done()
                    }.buttonStyle(SaveButtonStyle()).disabled(
                        title.trimmingCharacters(in: .whitespaces).isEmpty)
                }.formIconBackground()
            }
            DatePicker(
                "Due",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            Picker("Category", selection: $category) {
                ForEach(
                    [
                        "Personal", "Work", "Home", "Finance", "Shopping", "Health",
                        "Family", "Other",
                    ],
                    id: \.self
                ) { Text($0) }
            }.accessibilityIdentifier("new-task-category")
            Picker("Priority", selection: $priority) {
                ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0) }
            }.accessibilityIdentifier("new-task-priority")
            Picker("Repeat", selection: $repeatRule) {
                ForEach(RepeatRule.allCases) { Text($0.rawValue).tag($0) }
            }
            Toggle("Remind me", isOn: $reminder)
        }
        .alert("Task couldn’t save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "") }
    }
}
