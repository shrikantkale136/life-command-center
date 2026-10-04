import SwiftData
import Foundation

@MainActor
struct TaskRepository {
    let context: ModelContext
    var scheduleNotification: (String, String, Date) -> Void = { id, title, date in
        NotificationService.schedule(id: id, title: title, date: date)
    }
    var cancelNotification: (String) -> Void = { id in NotificationService.cancel(id: id) }

    func toggleCompletion(for task: TaskItem) {
        task.isComplete.toggle()
        task.completedAt = task.isComplete ? .now : nil

        let taskID = task.persistentModelID.hashValue.description
        if task.isComplete {
            if task.reminderEnabled { cancelNotification(taskID) }
            if let nextDate = task.repeatRule.next(after: task.dueDate) {
                let nextOccurrence = TaskItem(
                    title: task.title,
                    detail: task.detail,
                    dueDate: nextDate,
                    priority: task.priority,
                    category: task.category,
                    repeatRule: task.repeatRule,
                    reminderEnabled: task.reminderEnabled
                )
                context.insert(nextOccurrence)
                if nextOccurrence.reminderEnabled {
                    scheduleNotification(nextOccurrence.persistentModelID.hashValue.description, nextOccurrence.title, nextOccurrence.dueDate)
                }
            }
        } else if task.reminderEnabled {
            scheduleNotification(taskID, task.title, task.dueDate)
        }
    }
}
