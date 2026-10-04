import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

private struct TaskDraft {
    var title: String
    var detail: String
    var dueDate: Date
    var priorityRaw: String
    var category: String
    var repeatRaw: String
    var reminderEnabled: Bool

    init(task: TaskItem) {
        title = task.title
        detail = task.detail
        dueDate = task.dueDate
        priorityRaw = task.priorityRaw
        category = task.category
        repeatRaw = task.repeatRaw
        reminderEnabled = task.reminderEnabled
    }
}

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft: TaskDraft
    @State private var showingDeleteConfirmation = false
    let task: TaskItem

    init(task: TaskItem) {
        self.task = task
        _draft = State(initialValue: TaskDraft(task: task))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $draft.title)
                    TextField("Notes", text: $draft.detail, axis: .vertical)
                    DatePicker("Due", selection: $draft.dueDate, displayedComponents: [.date, .hourAndMinute])
                    Picker("Priority", selection: $draft.priorityRaw) {
                        ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Picker("Category", selection: $draft.category) {
                        ForEach(["Personal", "Work", "Home", "Finance", "Shopping", "Health", "Family", "Other"], id: \.self) { Text($0) }
                    }
                    Picker("Repeat", selection: $draft.repeatRaw) {
                        ForEach(RepeatRule.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Toggle("Remind me", isOn: $draft.reminderEnabled)
                }
                Section {
                    Button("Delete task", role: .destructive) { showingDeleteConfirmation = true }
                }
            }
            .navigationTitle("Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Task", role: .destructive) {
                    NotificationService.cancel(id: task.persistentModelID.hashValue.description)
                    context.delete(task)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func save() {
        task.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.detail = draft.detail
        task.dueDate = draft.dueDate
        task.priorityRaw = draft.priorityRaw
        task.category = draft.category
        task.repeatRaw = draft.repeatRaw
        task.reminderEnabled = draft.reminderEnabled
        let id = task.persistentModelID.hashValue.description
        if draft.reminderEnabled {
            NotificationService.schedule(id: id, title: task.title, date: task.dueDate)
        } else {
            NotificationService.cancel(id: id)
        }
        dismiss()
    }
}
