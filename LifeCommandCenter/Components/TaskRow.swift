import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct TaskRow: View {
    let task: TaskItem
    let toggle: () -> Void
    let edit: () -> Void
    var body: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { toggle() }
        } label: {
            ChecklistRowContent(
                title: task.title, subtitle: task.category + (Calendar.current.isDateInToday(task.dueDate) ? "" : " · " + task.dueDate.formatted(.dateTime.month(.abbreviated).day())),
                isComplete: task.isComplete, color: task.priority.color,
                repeatLabel: task.repeatRule == .none ? nil : task.repeatRaw)

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

struct ChecklistRowContent: View {
    let title: String
    let subtitle: String
    let isComplete: Bool
    let color: Color
    var repeatLabel: String? = nil
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isComplete ? forest : .secondary.opacity(0.5))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).strikethrough(isComplete)
                    .foregroundStyle(isComplete ? .secondary : ink)
                HStack(spacing: 7) {
                    Text(subtitle)
                    if let repeatLabel { Label(repeatLabel, systemImage: "repeat") }
                }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(color).frame(width: 7, height: 7)
        }.padding(.vertical, 12).frame(minHeight: 68).contentShape(Rectangle())
    }
}
