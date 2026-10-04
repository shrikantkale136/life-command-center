import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct TaskRow: View {
    let task: TaskItem; let toggle: () -> Void; let edit: () -> Void
    var body: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { toggle() }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isComplete ? forest : .secondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(task.isComplete)
                        .foregroundStyle(task.isComplete ? .secondary : ink)
                    HStack(spacing: 7) {
                        Text(task.category)
                        if task.repeatRule != .none { Label(task.repeatRaw, systemImage: "repeat") }
                        if !Calendar.current.isDateInToday(task.dueDate) { Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day())) }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(task.priority.color).frame(width: 7, height: 7)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(task.isComplete ? 0.5 : 1)
        .animation(.smooth(duration: 0.25), value: task.isComplete)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: edit)
            Button(task.isComplete ? "Reopen" : "Complete", systemImage: "checkmark") {
                withAnimation(.smooth(duration: 0.25)) { toggle() }
            }
            Button("Snooze until tomorrow", systemImage: "zzz") {
                task.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
            }
        }
    }
}
