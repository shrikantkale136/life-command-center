import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedDay = 0
    @AppStorage("preferredName") private var preferredName = ""
    @State private var selectedCategory = "All"
    let tasks: [TaskItem]
    let maintenance: [HomeMaintenance]
    let projects: [HomeProject]
    let subscriptions: [SubscriptionItem]
    let bills: [BillItem]
    let add: () -> Void
    let edit: (TaskItem) -> Void
    let toggle: (TaskItem) -> Void
    static func scheduleInterval(
        for page: Int, asOf date: Date = .now, calendar: Calendar = .current
    ) -> DateInterval {
        if page == 2 {
            let week = calendar.dateInterval(of: .weekOfYear, for: date)!
            let afterTomorrow = calendar.date(
                byAdding: .day, value: 2, to: calendar.startOfDay(for: date))!
            return DateInterval(start: min(afterTomorrow, week.end), end: week.end)
        }
        return calendar.dateInterval(
            of: .day, for: calendar.date(byAdding: .day, value: page, to: date)!)!
    }
    private func interval(for page: Int) -> DateInterval { Self.scheduleInterval(for: page) }
    private var dayTitle: String {
        ["Today's tasks", "Tomorrow's tasks", "This week's tasks"][selectedDay]
    }
    private var taskCategories: [String] {
        ["All"]
            + Set(scheduledItems(in: interval(for: selectedDay)).map(\.checklistCategory)).sorted()
    }
    private var completedTaskCount: Int { todayItems.filter(\.isComplete).count }
    private var completionProgress: Double {
        todayItems.isEmpty ? 0 : Double(completedTaskCount) / Double(todayItems.count)
    }
    private var completionPercentage: Int { Int((completionProgress * 100).rounded()) }
    private func scheduledItems(in interval: DateInterval) -> [CalendarRecord] {
        CalendarRecord.records(
            tasks: tasks, bills: bills, subscriptions: subscriptions,
            maintenance: maintenance, projects: projects, in: interval)
    }
    private func items(for offset: Int) -> [CalendarRecord] {
        return scheduledItems(in: interval(for: offset)).filter {
            selectedCategory == "All" || $0.checklistCategory == selectedCategory
        }
    }
    private var todayItems: [CalendarRecord] { items(for: selectedDay) }
    private func dayList(for offset: Int) -> some View {
        let entries = items(for: offset)
        return Group {
            if entries.isEmpty {
                if selectedCategory == "All" {
                    EmptyCard(
                        symbol: "sun.max", title: "A little breathing room",
                        subtitle:
                            "No tasks for \(["today", "tomorrow", "the rest of this week"][offset]). Enjoy it.",
                        button: "Add a task", action: add)
                } else {
                    Text("No tasks in this category \(["today", "tomorrow", "this week"][offset]).")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 136)
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(entries) {
                        event in
                        if offset != 0 {
                            HStack(spacing: 13) {
                                Image(systemName: event.symbol).font(.title3).foregroundStyle(
                                    event.color
                                ).frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.displayTitle).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ink)
                                    Text(
                                        "\(event.checklistCategory) · \(event.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
                                    )
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }.frame(minHeight: 68).accessibilityIdentifier(
                                "schedule-preview-\(offset)-\(event.title)")
                        } else if case .task(let task, _) = event,
                            task.repeatRule == .none || task.isComplete
                        {
                            TaskRow(task: task, toggle: { toggle(task) }, edit: { edit(task) })
                        } else {
                            Button {
                                withAnimation(.smooth(duration: 0.25)) {
                                    event.toggleChecklistCompletion()
                                    try? context.save()
                                }
                            } label: {
                                ChecklistRowContent(
                                    title: event.displayTitle, subtitle: event.checklistCategory,
                                    isComplete: event.isComplete, color: event.color)
                            }.buttonStyle(.plain).opacity(event.isComplete ? 0.5 : 1)
                                .accessibilityIdentifier("schedule-checklist-\(event.title)")
                                .accessibilityValue(event.isComplete ? "Completed" : "Incomplete")
                                .contextMenu {
                                    if case .task(let task, _) = event {
                                        Button("Edit", systemImage: "pencil") { edit(task) }
                                    }
                                }
                        }
                        if event.id != entries.last?.id {
                            Divider().padding(.leading, 48)
                        }
                    }
                }.padding(.horizontal, 14)
            }
        }.cardStyle().accessibilityIdentifier("schedule-list")
    }
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(greeting).font(.subheadline.weight(.semibold)).foregroundStyle(forest)
                        Text("Your day, in focus.").font(.largeTitle.weight(.bold)).fontDesign(
                            .rounded)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .foregroundStyle(
                                .secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center) {
                            SectionHeading(
                                title: dayTitle,
                                subtitle:
                                    selectedDay == 0
                                    ? "\(todayItems.count - completedTaskCount) remaining"
                                    : "\(todayItems.count) scheduled")
                            Spacer()
                            Menu {
                                ForEach(taskCategories, id: \.self) { option in
                                    Button {
                                        selectedCategory = option
                                    } label: {
                                        if selectedCategory == option {
                                            Label(option, systemImage: "checkmark")
                                        } else {
                                            Text(option)
                                        }
                                    }
                                }
                            } label: {
                                Image(
                                    systemName: selectedCategory == "All"
                                        ? "line.3.horizontal.decrease.circle"
                                        : "line.3.horizontal.decrease.circle.fill"
                                )
                                .font(.title3).foregroundStyle(forest).frame(width: 36, height: 36)
                                .contentShape(Circle())
                            }
                            .accessibilityLabel("Filter today's tasks by category")
                            if selectedDay == 0 {
                                Text("\(completedTaskCount) / \(todayItems.count)")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(
                                        "\(completedTaskCount) of \(todayItems.count) tasks completed"
                                    )
                            }
                        }

                        if selectedDay == 0 {
                            HStack(spacing: 10) {
                                ProgressView(value: completionProgress)
                                    .tint(forest)
                                Text("\(completionPercentage)%")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 38, alignment: .trailing)
                            }

                        }

                    }
                    Section {
                        ZStack {
                            dayList(for: selectedDay)
                                .id(selectedDay)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.primary.opacity(0.001))
                        .clipped()
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("daily-task-pages")
                    } header: {
                        HStack(spacing: 12) {
                            ForEach(0..<3) { offset in
                                Button {
                                    withAnimation(.snappy) { selectedDay = offset }
                                } label: {
                                    Text(["Today", "Tomorrow", "This week"][offset])
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedDay == offset ? .white : forest)
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(
                                            selectedDay == offset ? forest : forest.opacity(0.1),
                                            in: Capsule())
                                }.buttonStyle(.plain).accessibilityIdentifier("task-day-\(offset)")
                            }
                        }
                        .padding(.vertical, 10)
                        .background(canvas)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 16)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .global).onEnded { value in
                    let width = UIScreen.main.bounds.width
                    guard value.startLocation.x >= 24, value.startLocation.x <= width - 24
                    else { return }
                    guard abs(value.translation.width) > 60,
                        abs(value.translation.width) > abs(value.translation.height)
                    else { return }
                    withAnimation(.snappy) {
                        selectedDay = min(
                            2,
                            max(0, selectedDay + (value.translation.width < 0 ? 1 : -1))
                        )
                    }
                }
            )
            .accessibilityIdentifier("today-page-scroll")
            .onChange(of: selectedDay) { _, _ in selectedCategory = "All" }
            .background(canvas).navigationTitle("Today").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        CalendarView(addEvent: add, editTask: edit)
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(forest)
                    }
                    .accessibilityLabel("Calendar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: add) {
                        Image(systemName: "plus").foregroundStyle(forest)
                    }
                    .accessibilityLabel("Quick add")
                }
            }
        }
    }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeGreeting =
            hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "\(timeGreeting) 👋" : "\(timeGreeting), \(name) 👋"
    }
}
