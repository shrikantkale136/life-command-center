import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskItem]
    @Query private var bills: [BillItem]
    @Query private var subs: [SubscriptionItem]
    @Query private var maint: [HomeMaintenance]
    @Query private var projects: [HomeProject]
    @State private var selected = Date.now
    @State private var displayedMonth =
        Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var recordBeingEdited: CalendarRecord?
    @State private var recordToDelete: CalendarRecord?
    @State private var showingDeleteConfirmation = false

    let addEvent: () -> Void
    let editTask: (TaskItem) -> Void

    init(addEvent: @escaping () -> Void, editTask: @escaping (TaskItem) -> Void) {
        self.addEvent = addEvent
        self.editTask = editTask
    }

    private let calendar = Calendar.current
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 7
    )

    private var days: [Date?] {
        let first =
            calendar.dateInterval(of: .month, for: displayedMonth)?.start
            ?? displayedMonth
        let count =
            calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let leading =
            (calendar.component(.weekday, from: first) - calendar.firstWeekday
                + 7) % 7
        let blanks: [Date?] = Array(repeating: nil, count: leading)
        let dates: [Date?] = (0..<count).compactMap { index in
            calendar.date(byAdding: .day, value: index, to: first)
        }
        return blanks + dates
    }

    private var weekdays: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    private var selectedEvents: [CalendarRecord] {
        CalendarRecord.records(
            tasks: tasks, bills: bills, subscriptions: subs, maintenance: maint, projects: projects,
            in: calendar.dateInterval(of: .day, for: selected)!)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left").font(.headline).frame(
                            width: 40,
                            height: 40
                        )
                    }
                    .accessibilityLabel("Previous month")
                    Spacer()
                    Text(
                        displayedMonth.formatted(.dateTime.month(.wide).year())
                    ).font(.headline.weight(.semibold))
                    Spacer()
                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right").font(.headline)
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel("Next month")
                }
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(weekdays.enumerated()), id: \.offset) {
                        _,
                        day in
                        Text(day).font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary).frame(
                                maxWidth: .infinity
                            ).frame(height: 24)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                        if let date {
                            let isSelected = calendar.isDate(
                                date,
                                inSameDayAs: selected
                            )
                            let containsEvents = hasEvents(on: date)
                            Button {
                                selected = date
                            } label: {
                                VStack(spacing: 3) {
                                    Text(date.formatted(.dateTime.day())).font(
                                        .subheadline.weight(
                                            isSelected ? .bold : .regular
                                        )
                                    )
                                    .foregroundStyle(
                                        isSelected ? Color.white : Color.primary
                                    )
                                    Circle().fill(
                                        containsEvents
                                            ? (isSelected
                                                ? Color.white : forest)
                                            : Color.clear
                                    )
                                    .frame(width: 5, height: 5)
                                }
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(
                                    isSelected ? forest : Color.clear,
                                    in: RoundedRectangle(
                                        cornerRadius: 12,
                                        style: .continuous
                                    )
                                )
                                .contentShape(
                                    RoundedRectangle(
                                        cornerRadius: 12,
                                        style: .continuous
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                accessibilityDateLabel(
                                    for: date,
                                    hasEvents: containsEvents
                                )
                            )
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(14)
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(
                        title: selected.formatted(
                            .dateTime.weekday(.wide).month(.wide).day()
                        ),
                        subtitle: "Scheduled items"
                    )
                    if selectedEvents.isEmpty {
                        Text("Nothing scheduled for this date.").font(
                            .subheadline
                        ).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16).cardStyle()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(selectedEvents) { event in
                                Button {
                                    edit(event)
                                } label: {
                                    Label(
                                        event.displayTitle,
                                        systemImage: event.symbol
                                    )
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(event.color)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .padding(14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Edit event", systemImage: "pencil") { edit(event) }
                                    Button(
                                        "Delete event",
                                        systemImage: "trash",
                                        role: .destructive
                                    ) {
                                        recordToDelete = event
                                        showingDeleteConfirmation = true
                                    }
                                }
                                if event.id != selectedEvents.last?.id {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }.cardStyle()
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .background(canvas)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: addEvent) { Image(systemName: "plus") }
                    .accessibilityLabel("Add event")
            }
        }
        .sheet(item: $recordBeingEdited) { record in
            CalendarRecordEditor(record: record)
        }
        .alert("Delete event?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                recordToDelete?.delete(from: context)
                try? context.save()
                if !ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                    NotificationService.syncMaintenance(in: context)
                }
                recordToDelete = nil
            }
            Button("Cancel", role: .cancel) { recordToDelete = nil }
        } message: {
            Text(
                "\(recordToDelete?.displayTitle ?? "This event") will be permanently deleted."
            )
        }
    }

    private func edit(_ record: CalendarRecord) {
        if case .task(let task) = record {
            editTask(task)
        } else {
            recordBeingEdited = record
        }
    }

    private func hasEvents(on date: Date) -> Bool {
        !CalendarRecord.records(
            tasks: tasks, bills: bills, subscriptions: subs, maintenance: maint, projects: projects,
            in: calendar.dateInterval(of: .day, for: date)!
        ).isEmpty
    }

    private func changeMonth(by offset: Int) {
        if let next = calendar.date(
            byAdding: .month,
            value: offset,
            to: displayedMonth
        ) {
            displayedMonth = next
        }
    }

    private func accessibilityDateLabel(for date: Date, hasEvents: Bool)
        -> String
    {
        let label = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return hasEvents ? "\(label), events scheduled" : label
    }
}

enum CalendarRecord: Identifiable {
    case task(TaskItem)
    case bill(BillItem)
    case subscription(SubscriptionItem)
    case maintenance(HomeMaintenance, Date)
    case project(HomeProject)

    static func records(
        tasks: [TaskItem], bills: [BillItem], subscriptions: [SubscriptionItem],
        maintenance: [HomeMaintenance], projects: [HomeProject], in interval: DateInterval
    ) -> [CalendarRecord] {
        func includes(_ date: Date) -> Bool { date >= interval.start && date < interval.end }
        let taskRecords = tasks.filter { includes($0.dueDate) }.map { CalendarRecord.task($0) }
        let billRecords = bills.filter { includes($0.dueDate) }.map { CalendarRecord.bill($0) }
        let subscriptionRecords = subscriptions.filter { includes($0.nextDate) }.map {
            CalendarRecord.subscription($0)
        }
        let maintenanceRecords = maintenance.flatMap { item in
            item.occurrences(in: interval).map { CalendarRecord.maintenance(item, $0) }
        }
        let projectRecords = projects.filter { includes($0.targetDate) }.map {
            CalendarRecord.project($0)
        }
        return
            (taskRecords + billRecords + subscriptionRecords + maintenanceRecords + projectRecords)
            .sorted { $0.date < $1.date }
    }

    var id: String {
        switch self {
        case .task(let item): "task-\(item.persistentModelID.hashValue)"
        case .bill(let item): "bill-\(item.persistentModelID.hashValue)"
        case .subscription(let item):
            "subscription-\(item.persistentModelID.hashValue)"
        case .maintenance(let item, _):
            "maintenance-\(item.persistentModelID.hashValue)-\(date.timeIntervalSince1970)"
        case .project(let item): "project-\(item.persistentModelID.hashValue)"
        }
    }

    var checklistCategory: String {
        switch self {
        case .task(let item): item.category
        case .bill: "Bill"
        case .subscription: "Subscription"
        case .maintenance: "Maintenance"
        case .project: "Project"
        }
    }
    private var completedDates: [Date] {
        switch self {
        case .task: []
        case .bill(let item): item.completedScheduleDates
        case .subscription(let item): item.completedScheduleDates
        case .maintenance(let item, _): item.completedScheduleDates
        case .project(let item): item.completedScheduleDates
        }
    }
    var isComplete: Bool {
        if case .task(let item) = self { return item.isComplete }
        return completedDates.contains(date)
    }
    func toggleChecklistCompletion() {
        var dates = completedDates
        if let index = dates.firstIndex(of: date) {
            dates.remove(at: index)
        } else {
            dates.append(date)
        }
        switch self {
        case .task: break  // TaskRepository handles task recurrence and notifications.
        case .bill(let item): item.completedScheduleDates = dates
        case .subscription(let item): item.completedScheduleDates = dates
        case .maintenance(let item, _): item.completedScheduleDates = dates
        case .project(let item): item.completedScheduleDates = dates
        }
    }

    var displayTitle: String {
        switch self {
        case .task(let item): item.title
        case .bill(let item): "\(item.name) · \(item.amount.currency)"
        case .subscription(let item): "\(item.name) renewal"
        case .maintenance(let item, _): item.name
        case .project(let item): "\(item.name) deadline"
        }
    }

    var symbol: String {
        switch self {
        case .task: "checkmark.circle"
        case .bill: "dollarsign.circle"
        case .subscription: "arrow.clockwise.circle"
        case .maintenance: "wrench.and.screwdriver"
        case .project: "hammer"
        }
    }

    var color: Color {
        switch self {
        case .task, .project: forest
        case .bill, .maintenance: .orange
        case .subscription: .purple
        }
    }

    var title: String {
        switch self {
        case .task(let item): item.title
        case .bill(let item): item.name
        case .subscription(let item): item.name
        case .maintenance(let item, _): item.name
        case .project(let item): item.name
        }
    }

    var date: Date {
        switch self {
        case .task(let item): item.dueDate
        case .bill(let item): item.dueDate
        case .subscription(let item): item.nextDate
        case .maintenance(_, let occurrence): occurrence
        case .project(let item): item.targetDate
        }
    }

    func update(title: String, date: Date) {
        switch self {
        case .task(let item):
            item.title = title
            item.dueDate = date
        case .bill(let item):
            item.name = title
            item.dueDate = date
        case .subscription(let item):
            item.name = title
            item.nextDate = date
        case .maintenance(let item, _):
            item.name = title
            item.nextDue = date
        case .project(let item):
            item.name = title
            item.targetDate = date
        }
    }

    func delete(from context: ModelContext) {
        switch self {
        case .task(let item):
            NotificationService.cancel(
                id: item.persistentModelID.hashValue.description
            )
            context.delete(item)
        case .bill(let item): context.delete(item)
        case .subscription(let item): context.delete(item)
        case .maintenance(let item, _): context.delete(item)
        case .project(let item): context.delete(item)
        }
    }
}

private struct CalendarRecordEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    let record: CalendarRecord

    init(record: CalendarRecord) {
        self.record = record
        _title = State(initialValue: record.title)
        _date = State(initialValue: record.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event details") {
                    TextField("Name", text: $title)
                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle("Edit event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        record.update(
                            title: title.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ),
                            date: date
                        )
                        try? context.save()
                        if !ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                            NotificationService.syncMaintenance(in: context)
                        }
                        dismiss()
                    }.buttonStyle(SaveButtonStyle())
                        .disabled(
                            title.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        )
                }
            }
        }
        .presentationDetents([.medium])
    }
}
