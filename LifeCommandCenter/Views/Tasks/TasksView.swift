import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct TasksView: View {
    @Environment(\.modelContext) private var context
    let tasks: [TaskItem]; let add: () -> Void; let edit: (TaskItem) -> Void; let toggle: (TaskItem) -> Void
    @State private var filter = "Open"
    private var shown: [TaskItem] { tasks.filter { filter == "Completed" ? $0.isComplete : !$0.isComplete }.sorted { $0.dueDate < $1.dueDate } }
    var body: some View { NavigationStack { VStack(spacing: 14) {
        Picker("Tasks", selection: $filter) { Text("Open").tag("Open"); Text("Completed").tag("Completed") }.pickerStyle(.segmented).padding(.horizontal, 20)
        if shown.isEmpty { Spacer(); EmptyCard(symbol: "checkmark.circle", title: filter == "Open" ? "You're all caught up" : "No completed tasks yet", subtitle: "Add a task and keep your day moving.", button: "Add task", action: add).padding(20); Spacer() }
        else { List { ForEach(shown) { task in TaskRow(task: task, toggle: { toggle(task) }, edit: { edit(task) }).listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18)).listRowSeparator(.hidden).listRowBackground(Color.clear) }.onDelete { offsets in offsets.map { shown[$0] }.forEach { context.delete($0) } } }.listStyle(.plain) }
        }.background(canvas).navigationTitle("Tasks").toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: add) { Image(systemName: "plus") } } } } }
}
