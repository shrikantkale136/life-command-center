import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var expandedProjectStatus: String? = "In Progress"
    @State private var selectedProject: HomeProject?
    let maintenance: [HomeMaintenance]
    let projects: [HomeProject]
    let addMaintenance: () -> Void
    let addProject: () -> Void
    let editProject: (HomeProject) -> Void
    let editMaintenance: (HomeMaintenance) -> Void
    private var visibleProjectStatuses: [String] {
        ["In Progress", "On Hold", "Planned", "Completed"].filter { status in
            projects.contains { $0.displayStatus == status }
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("HOME MANAGEMENT").font(.caption.weight(.bold))
                            .tracking(1.4).foregroundStyle(forest)
                        Text("Care for your place.").font(
                            .largeTitle.weight(.bold)
                        ).fontDesign(.rounded)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(
                        .top,
                        12
                    )
                    HStack {
                        SectionHeading(
                            title: "Maintenance",
                            subtitle: "A little upkeep goes a long way"
                        )
                        Spacer()
                        Button(action: addMaintenance) {
                            Image(systemName: "plus.circle.fill").font(.title2)
                                .foregroundStyle(forest)
                        }.accessibilityLabel("Add maintenance")
                    }
                    if maintenance.isEmpty {
                        EmptyCard(
                            symbol: "wrench.adjustable",
                            title: "No maintenance tracked",
                            subtitle:
                                "Keep service dates and home care together.",
                            button: "Add maintenance",
                            action: addMaintenance
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(maintenance) { item in
                                Button {
                                    editMaintenance(item)
                                } label: {
                                    HStack(spacing: 13) {
                                        Image(
                                            systemName:
                                                "wrench.and.screwdriver.fill"
                                        ).foregroundStyle(.orange).frame(
                                            width: 34,
                                            height: 34
                                        ).background(
                                            Color.orange.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 11)
                                        )
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name).font(
                                                .subheadline.weight(.semibold)
                                            )
                                            Text(
                                                "\(item.area) · \(item.frequencyDescription)"
                                            ).font(.caption).foregroundStyle(
                                                .secondary
                                            )
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            let due = item.nextOccurrence(
                                                onOrAfter: Calendar.current.startOfDay(for: .now))
                                            if let due, Calendar.current.isDateInToday(due) {
                                                Text("Today").font(.caption.weight(.semibold))
                                                    .foregroundStyle(.green)
                                            } else {
                                                Text(
                                                    due?.formatted(
                                                        .dateTime.month(.abbreviated).day().year())
                                                        ?? "No upcoming date"
                                                )
                                                .font(.caption.weight(.semibold))
                                                Text("Next due").font(.caption2).foregroundStyle(
                                                    .secondary)
                                            }
                                        }
                                        Image(systemName: "chevron.right").font(.caption)
                                            .foregroundStyle(.secondary)
                                    }.padding(14).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Edit maintenance", systemImage: "square.and.pencil")
                                        { editMaintenance(item) }
                                        Button(
                                            "Mark complete",
                                            systemImage: "checkmark"
                                        ) {
                                            item.lastCompleted = .now
                                            if let next = item.nextDate(
                                                after: max(item.nextDue, .now))
                                            {
                                                item.nextDue = next
                                            }
                                            try? context.save()
                                            NotificationService.syncMaintenance(in: context)
                                        }
                                    }
                                if item.id != maintenance.last?.id {
                                    Divider().padding(.leading, 58)
                                }
                            }
                        }.cardStyle()
                    }
                    HStack {
                        SectionHeading(
                            title: "Projects",
                            subtitle: "Make progress, one step at a time"
                        )
                        Spacer()
                        Button {
                            expandedProjectStatus = "In Progress"
                            addProject()
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                                .foregroundStyle(forest)
                        }.accessibilityLabel("Add project")
                    }
                    if projects.isEmpty {
                        EmptyCard(
                            symbol: "hammer",
                            title: "No active projects",
                            subtitle:
                                "Start planning your next home improvement.",
                            button: "Add project",
                            action: {
                                expandedProjectStatus = "In Progress"
                                addProject()
                            }
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(visibleProjectStatuses, id: \.self) { status in
                                ProjectStatusSection(
                                    status: status,
                                    projects: projects.filter { $0.displayStatus == status },
                                    isExpanded: Binding(
                                        get: { expandedProjectStatus == status },
                                        set: { expanded in
                                            expandedProjectStatus = expanded ? status : nil
                                        }),
                                    openProject: { selectedProject = $0 })
                                if status != visibleProjectStatuses.last {
                                    Divider().padding(.leading, 61)
                                }
                            }
                        }.cardStyle()
                    }
                }.padding(20).padding(.bottom, 70)
            }.background(canvas).navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selectedProject) { project in
                    ProjectDetailView(project: project, edit: { editProject(project) })
                }
        }
    }
}

private struct ProjectStatusSection: View {
    let status: String
    let projects: [HomeProject]
    @Binding var isExpanded: Bool
    let openProject: (HomeProject) -> Void

    private var icon: String {
        switch status {
        case "On Hold": "pause.circle.fill"
        case "Planned": "calendar"
        case "Completed": "checkmark.circle.fill"
        default: "hammer.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: icon).font(.subheadline)
                        .foregroundStyle(ProjectStatusStyle.color(for: status)).frame(
                            width: 34, height: 34
                        )
                        .background(
                            ProjectStatusStyle.color(for: status).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 11))
                    Text(status).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Spacer()
                    Text("\(projects.count)").font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary).padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityIdentifier("project-section-\(status)")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(projects) { project in
                        Button {
                            openProject(project)
                        } label: {
                            ProjectCard(project: project)
                        }.buttonStyle(.plain).accessibilityIdentifier("project-row-\(project.name)")
                        if project.id != projects.last?.id { Divider() }
                    }
                }.padding(.leading, 61).padding(.trailing, 14).padding(.bottom, 4)
                    .background(Color.primary.opacity(0.025))
            }
        }
    }
}

struct MaintenanceDraft {
    var name: String
    var area: String
    var detail: String
    var nextDue: Date
    var frequency: MaintenanceFrequency
    var cost: String
    var provider: String
    var notes: String
    var customInterval: Int
    var customUnit: MaintenanceIntervalUnit
    var reminderEnabled: Bool
    var reminderTime: Date
    var dateEnabled: Bool
    var timeEnabled: Bool
    var timeZoneEnabled: Bool
    var timeZoneID: String
    var endsRepeat: Bool
    var repeatEndDate: Date
    var calendar: Calendar {
        var calendar = Calendar.current
        if timeEnabled && timeZoneEnabled, let zone = TimeZone(identifier: timeZoneID) {
            calendar.timeZone = zone
        }
        return calendar
    }

    init(item existing: HomeMaintenance? = nil) {
        let item = existing ?? HomeMaintenance(name: "", area: "HVAC")
        name = item.name
        area = item.area
        detail = item.detail
        nextDue = item.nextDue
        frequency = existing == nil ? .none : item.frequency
        cost = ProjectDraft.costText(item.cost)
        provider = item.provider
        notes = item.notes
        customInterval = item.customInterval
        customUnit = item.customIntervalUnit
        reminderEnabled = item.reminderEnabled
        dateEnabled = existing == nil ? false : item.dateEnabled
        timeEnabled = item.timeEnabled || (item.timeZoneID.isEmpty && item.reminderEnabled)
        timeZoneEnabled = item.timeZoneEnabled
        timeZoneID = item.timeZoneID.isEmpty ? TimeZone.current.identifier : item.timeZoneID
        endsRepeat = item.repeatEndDate != nil
        repeatEndDate = item.repeatEndDate ?? item.nextDue
        reminderTime =
            item.scheduleCalendar.date(
                bySettingHour: item.reminderHour, minute: item.reminderMinute, second: 0, of: .now)
            ?? .now
    }

    mutating func setTimeEnabled(_ enabled: Bool, now: Date = .now) {
        timeEnabled = enabled
        if enabled && !dateEnabled {
            dateEnabled = true
            nextDue = now
        }
    }
    var dateSubtitle: String {
        if calendar.isDateInToday(nextDue) { return "Today" }
        if calendar.isDateInTomorrow(nextDue) { return "Tomorrow" }
        return nextDue.formatted(
            Date.FormatStyle(date: .long, time: .omitted, timeZone: calendar.timeZone))
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ProjectDraft.amount(cost) != nil && customInterval > 0
            && (!dateEnabled || !endsRepeat || frequency == .none
                || calendar.startOfDay(for: repeatEndDate) >= calendar.startOfDay(for: nextDue))
    }

    @MainActor @discardableResult
    func save(in context: ModelContext, item existing: HomeMaintenance? = nil) throws
        -> HomeMaintenance
    {
        let item = existing ?? HomeMaintenance(name: name)
        if existing == nil { context.insert(item) }
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.area = area.trimmingCharacters(in: .whitespacesAndNewlines)
        item.detail = detail
        item.dateEnabled = dateEnabled || timeEnabled
        item.timeEnabled = timeEnabled
        item.timeZoneEnabled = timeZoneEnabled
        item.timeZoneID = timeZoneID
        item.repeatEndDate = endsRepeat && frequency != .none ? repeatEndDate : nil
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        item.nextDue =
            timeEnabled
            ? (calendar.date(bySettingHour: hour, minute: minute, second: 0, of: nextDue) ?? nextDue)
            : nextDue
        item.frequencyRaw = frequency.rawValue
        item.cost = ProjectDraft.amount(cost) ?? 0
        item.provider = provider
        item.notes = notes
        item.customInterval = customInterval
        item.customIntervalUnitRaw = customUnit.rawValue
        item.reminderEnabled = reminderEnabled
        item.reminderHour = timeEnabled ? hour : 9
        item.reminderMinute = timeEnabled ? minute : 0
        try context.save()
        if !ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            NotificationService.syncMaintenance(in: context)
        }
        return item
    }
}

private struct MaintenanceFormSections: View {
    @Binding var draft: MaintenanceDraft
    var lastCompleted: Date? = nil
    var createSaveButton: AnyView? = nil
    @State private var focusedPicker: PickerFocus?
    @FocusState private var editingText: Bool
    private enum PickerFocus { case date, time }

    var body: some View {
        Section("Maintenance details") {
            TextField("Maintenance item", text: $draft.name).focused($editingText)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { createSaveButton } }
            TextField("Area", text: $draft.area).focused($editingText)
            TextField("Description", text: $draft.detail, axis: .vertical).focused($editingText)
        }
        .simultaneousGesture(TapGesture().onEnded { focusedPicker = nil })
        Section("Date & Time") {
            HStack {
                Button {
                    editingText = false
                    if !draft.dateEnabled { draft.dateEnabled = true }
                    focusedPicker = focusedPicker == .date ? nil : .date
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Date").foregroundStyle(.primary)
                            if draft.dateEnabled {
                                Text(draft.dateSubtitle).font(.caption).foregroundStyle(.blue)
                            }
                        }
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("maintenance-date-focus")
                Toggle(
                    "Date",
                    isOn: Binding(
                        get: { draft.dateEnabled },
                        set: { enabled in
                            draft.dateEnabled = enabled
                            editingText = false
                            if enabled { focusedPicker = .date }
                            if !enabled {
                                draft.timeEnabled = false
                                focusedPicker = nil
                            }
                        })
                ).labelsHidden().accessibilityIdentifier("maintenance-date-toggle")
            }
            if draft.dateEnabled && focusedPicker == .date {
                DatePicker("Due date", selection: $draft.nextDue, displayedComponents: .date)
                    .datePickerStyle(.graphical).labelsHidden()
                    .accessibilityIdentifier("maintenance-date-picker")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            HStack {
                Button {
                    editingText = false
                    draft.setTimeEnabled(true)
                    focusedPicker = focusedPicker == .time ? nil : .time
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Time").foregroundStyle(.primary)
                            if draft.timeEnabled {
                                Text(
                                    draft.reminderTime.formatted(
                                        Date.FormatStyle(
                                            date: .omitted, time: .shortened,
                                            timeZone: draft.calendar.timeZone))
                                )
                                .font(.caption).foregroundStyle(.blue)
                            }
                        }
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("maintenance-time-focus")
                Toggle(
                    "Time",
                    isOn: Binding(
                        get: { draft.timeEnabled },
                        set: { enabled in
                            draft.setTimeEnabled(enabled)
                            editingText = false
                            if enabled { focusedPicker = .time }
                            if !enabled && focusedPicker == .time { focusedPicker = nil }
                        })
                ).labelsHidden().accessibilityIdentifier("maintenance-time-toggle")
            }
            if draft.timeEnabled && focusedPicker == .time {
                DatePicker(
                    "Time", selection: $draft.reminderTime, displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel).labelsHidden().frame(height: 170).clipped()
                .accessibilityIdentifier("maintenance-time-picker")
                .transition(.move(edge: .top).combined(with: .opacity))
            }

        }
        .onChange(of: editingText) { _, editing in
            if editing { focusedPicker = nil }
        }
        .animation(.easeInOut(duration: 0.25), value: focusedPicker)
        .animation(.easeInOut(duration: 0.25), value: draft.dateEnabled)
        .animation(.easeInOut(duration: 0.25), value: draft.timeEnabled)
        .environment(\.calendar, draft.calendar).environment(\.timeZone, draft.calendar.timeZone)
        Section("Repeat") {
            Picker("Repeat", selection: $draft.frequency) {
                ForEach(MaintenanceFrequency.allCases) { Text($0.title).tag($0) }
            }.accessibilityIdentifier("maintenance-repeat-picker")
            if draft.frequency == .custom {
                HStack {
                    Text("Every")
                    Spacer()
                    TextField(
                        "Interval", value: $draft.customInterval,
                        format: .number.grouping(.never)
                    )
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 70)
                }
                Picker("Interval unit", selection: $draft.customUnit) {
                    ForEach(MaintenanceIntervalUnit.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            if draft.frequency != .none {
                Picker("End repeat", selection: $draft.endsRepeat) {
                    Text("Never").tag(false)
                    Text("On date").tag(true)
                }.accessibilityIdentifier("maintenance-end-repeat-picker")
                if draft.endsRepeat {
                    DatePicker(
                        "End date", selection: $draft.repeatEndDate,
                        in: draft.calendar.startOfDay(for: draft.nextDue)...,
                        displayedComponents: .date)
                }
            }
        }
        .environment(\.calendar, draft.calendar).environment(\.timeZone, draft.calendar.timeZone)
        .simultaneousGesture(TapGesture().onEnded { focusedPicker = nil })
        .onChange(of: draft.frequency) { _, frequency in
            focusedPicker = nil
            if frequency != .none && !draft.dateEnabled {
                draft.dateEnabled = true
                draft.nextDue = .now
            }
            if frequency == .hourly { draft.setTimeEnabled(true) }
        }
        Section("Notifications") {
            Toggle("Remind me", isOn: $draft.reminderEnabled)
            if draft.reminderEnabled && !draft.timeEnabled {
                Text(
                    "Reminders arrive at 9:00 AM on the due date. Turn on Time to choose a time."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .simultaneousGesture(TapGesture().onEnded { focusedPicker = nil })
        Section("Service") {
            TextField("Provider", text: $draft.provider).focused($editingText)
            HStack {
                Text("Cost")
                Spacer()
                ProjectCostField(amount: $draft.cost, label: "Maintenance cost").frame(width: 140)
            }
            TextField("Notes", text: $draft.notes, axis: .vertical).focused($editingText).lineLimit(
                2...5)
            if ProjectDraft.amount(draft.cost) == nil {
                Text("Enter a valid cost of zero or more.").font(.caption).foregroundStyle(.red)
            }
            if let completed = lastCompleted {
                LabeledContent(
                    "Last completed", value: completed.formatted(date: .abbreviated, time: .omitted)
                )
            }
        }
        .simultaneousGesture(TapGesture().onEnded { focusedPicker = nil })
    }
}

struct MaintenanceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft: MaintenanceDraft
    @State private var saveError = false
    let item: HomeMaintenance

    init(item: HomeMaintenance) {
        self.item = item
        _draft = State(initialValue: MaintenanceDraft(item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                MaintenanceFormSections(draft: $draft, lastCompleted: item.lastCompleted)
            }
            .navigationTitle("Edit maintenance").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        do {
                            try draft.save(in: context, item: item)
                            dismiss()
                        } catch { saveError = true }
                    }.buttonStyle(SaveButtonStyle()).disabled(!draft.canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil,
                            for: nil)
                    }
                }
            }
            .alert("Couldn’t save maintenance", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try saving again.")
            }
        }
    }
}

struct MaintenanceCreateFields: View {
    @Environment(\.modelContext) private var context
    @State private var draft = MaintenanceDraft()
    @State private var saveError = false
    let done: () -> Void
    var body: some View {
        MaintenanceFormSections(
            draft: $draft,
            createSaveButton: AnyView(
                Button("Save") {
                    do {
                        try draft.save(in: context)
                        done()
                    } catch { saveError = true }
                }.buttonStyle(SaveButtonStyle()).disabled(!draft.canSave)
            )
        )

        .alert("Couldn’t save maintenance", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try saving again.")
        }
    }
}

struct ProjectTaskDraft: Identifiable {
    let id = UUID()
    var title = ""
    var isComplete = false
    var original: ProjectTask?
}

struct ProjectShoppingDraft: Identifiable {
    let id = UUID()
    var name = ""
    var quantity = 1
    var unitCost = ""
    var isPurchased = false
    var original: ProjectShoppingItem?
    var estimatedTotal: Double { Double(quantity) * (ProjectDraft.amount(unitCost) ?? 0) }
}

struct ProjectDraft {
    var name = ""
    var detail = ""
    var area = "Home"
    var targetDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    var estimatedCost = ""
    var actualCost = ""
    var tasks: [ProjectTaskDraft] = []
    var shoppingItems: [ProjectShoppingDraft] = []

    init(project: HomeProject? = nil) {
        guard let project else { return }
        name = project.name
        detail = project.detail
        area = project.area
        targetDate = project.targetDate
        estimatedCost = Self.costText(project.estimatedCost)
        actualCost = Self.costText(project.actualCost)
        tasks = project.orderedTasks.map {
            ProjectTaskDraft(title: $0.title, isComplete: $0.isComplete, original: $0)
        }
        shoppingItems = project.orderedShoppingItems.map {
            ProjectShoppingDraft(
                name: $0.name, quantity: $0.quantity,
                unitCost: Self.costText($0.estimatedUnitCost), isPurchased: $0.isPurchased,
                original: $0)
        }
    }

    static func costText(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.grouping(.never))
    }

    static func amount(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return 0 }
        let normalized = cleaned.replacingOccurrences(
            of: Locale.current.decimalSeparator ?? ".", with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0 else { return nil }
        return value
    }

    var shoppingEstimate: Double { shoppingItems.reduce(0) { $0 + $1.estimatedTotal } }
    var costsAreValid: Bool {
        Self.amount(estimatedCost) != nil && Self.amount(actualCost) != nil
            && shoppingItems.allSatisfy {
                Self.amount($0.unitCost) != nil && $0.quantity > 0 && $0.quantity <= 999
                    && $0.estimatedTotal.isFinite
            }
            && shoppingEstimate.isFinite
    }
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && costsAreValid
            && shoppingItems.allSatisfy {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || ($0.unitCost.isEmpty && $0.quantity == 1 && !$0.isPurchased)
            }
    }

    @MainActor
    func save(in context: ModelContext, project existing: HomeProject? = nil) throws -> HomeProject
    {
        let project = existing ?? HomeProject(name: name)
        if existing == nil { context.insert(project) }
        project.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        project.detail = detail
        project.area = area.trimmingCharacters(in: .whitespacesAndNewlines)
        project.targetDate = targetDate
        project.estimatedCost = Self.amount(estimatedCost) ?? 0
        project.actualCost = Self.amount(actualCost) ?? 0

        if !project.isComplete {
            let validTasks = tasks.filter {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            for old in project.tasks where !validTasks.contains(where: { $0.original === old }) {
                context.delete(old)
            }
            project.tasks = validTasks.enumerated().map { index, draft in
                let task = draft.original ?? ProjectTask(title: draft.title)
                if draft.original == nil { context.insert(task) }
                task.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                task.isComplete = draft.isComplete
                task.sortOrder = index
                task.project = project
                return task
            }
            let validItems = shoppingItems.filter {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            for old in project.shoppingItems
            where !validItems.contains(where: { $0.original === old }) {
                context.delete(old)
            }
            project.shoppingItems = validItems.enumerated().map { index, draft in
                let item = draft.original ?? ProjectShoppingItem(name: draft.name)
                if draft.original == nil { context.insert(item) }
                item.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                item.quantity = draft.quantity
                item.estimatedUnitCost = Self.amount(draft.unitCost) ?? 0
                item.isPurchased = draft.isPurchased
                item.sortOrder = index
                item.project = project
                return item
            }
        }
        try context.save()
        return project
    }
}

private struct ProjectCostField: View {
    @Binding var amount: String
    let label: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text("$").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("0.00", text: $amount)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .focused($isFocused).accessibilityLabel(label)
                .frame(
                    width: max(
                        10,
                        ceil(
                            ((amount.isEmpty ? "0.00" : amount) as NSString)
                                .size(withAttributes: [
                                    .font: UIFont.preferredFont(forTextStyle: .body)
                                ]).width) + 2))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle()).onTapGesture { isFocused = true }
    }
}

struct ProjectFormSections: View {
    @Binding var draft: ProjectDraft
    var listsAreReadOnly = false
    var createSaveButton: AnyView? = nil

    var body: some View {
        Section("Project details") {
            TextField("Project name", text: $draft.name)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { createSaveButton } }
            TextField("Area", text: $draft.area)
            TextField("Notes", text: $draft.detail, axis: .vertical).lineLimit(2...4)
            DatePicker("Target date", selection: $draft.targetDate, displayedComponents: .date)
            Text("Change status from the badge on the project details page.")
                .font(.caption).foregroundStyle(.secondary)
            if listsAreReadOnly {
                Label("Change status from Completed to edit the lists.", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        Section {
            if draft.tasks.isEmpty {
                Text("Break your project into small steps.").foregroundStyle(.secondary)
            }
            ForEach($draft.tasks) { $task in
                HStack(spacing: 12) {
                    Button {
                        task.isComplete.toggle()
                    } label: {
                        Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(task.isComplete ? forest : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(task.isComplete ? "Mark task incomplete" : "Complete task")
                    TextField("Task title", text: $task.title, axis: .vertical)
                        .strikethrough(task.isComplete)
                        .foregroundStyle(task.isComplete ? .secondary : .primary)
                    Button(role: .destructive) {
                        draft.tasks.removeAll { $0.id == task.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless).accessibilityLabel("Remove task")
                }.padding(.vertical, 4)
            }
            .onMove { draft.tasks.move(fromOffsets: $0, toOffset: $1) }
            Button {
                draft.tasks.append(ProjectTaskDraft())
            } label: {
                Label("Add task", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Task list · \(draft.tasks.filter(\.isComplete).count)/\(draft.tasks.count)")
        } footer: {
            Text(
                "Check off steps to update progress. Set the project status from its details page.")
        }.disabled(listsAreReadOnly)
        Section {
            if draft.shoppingItems.isEmpty {
                Text("Add supplies or purchases for this project.").foregroundStyle(.secondary)
            }
            ForEach($draft.shoppingItems) { $item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Button {
                            item.isPurchased.toggle()
                        } label: {
                            Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                                .font(.title2).foregroundStyle(
                                    item.isPurchased ? forest : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            item.isPurchased ? "Mark item unpurchased" : "Mark item purchased")
                        TextField("Shopping item", text: $item.name)
                            .strikethrough(item.isPurchased)
                        Button(role: .destructive) {
                            draft.shoppingItems.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless).accessibilityLabel("Remove shopping item")
                    }
                    HStack {
                        Text("Qty").font(.subheadline)
                        TextField(
                            "Quantity", value: $item.quantity, format: .number.grouping(.never)
                        )
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 45)
                        .accessibilityLabel("Quantity")
                        Spacer()
                        Text("Unit cost").font(.subheadline)
                        Spacer()
                        ProjectCostField(amount: $item.unitCost, label: "Estimated unit cost")
                            .frame(width: 110)
                    }
                    LabeledContent("Item estimate", value: item.estimatedTotal.currency)
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 6)
            }
            .onMove { draft.shoppingItems.move(fromOffsets: $0, toOffset: $1) }
            Button {
                draft.shoppingItems.append(ProjectShoppingDraft())
            } label: {
                Label("Add shopping item", systemImage: "plus.circle.fill")
            }
            LabeledContent("Shopping estimate", value: draft.shoppingEstimate.currency)
                .fontWeight(.semibold)
        } header: {
            Text("Shopping list (optional)")
        } footer: {
            Text(
                "Estimates use quantity × unit cost, including purchased items. Shopping checkmarks do not change task progress."
            )
        }.disabled(listsAreReadOnly)
        Section {
            HStack {
                Text("Project estimate")
                Spacer()
                ProjectCostField(amount: $draft.estimatedCost, label: "Project estimate")
                    .frame(width: 140)
            }
            HStack {
                Text("Actual cost")
                Spacer()
                ProjectCostField(amount: $draft.actualCost, label: "Actual cost")
                    .frame(width: 140)
            }
            if !draft.shoppingItems.isEmpty {
                Button("Use shopping total as project estimate") {
                    draft.estimatedCost = ProjectDraft.costText(draft.shoppingEstimate)
                }.disabled(!draft.costsAreValid)
            }
            if !draft.costsAreValid {
                Text("Enter valid costs of zero or more.").font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Budget")
        } footer: {
            Text(
                "The project estimate can include supplies, labor, and other costs. All amounts are in \(Locale.current.currency?.identifier ?? "USD")."
            )
        }
    }
}

struct ProjectEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft: ProjectDraft
    @State private var saveError = false
    let project: HomeProject?

    init(project: HomeProject? = nil) {
        self.project = project
        _draft = State(initialValue: ProjectDraft(project: project))
    }

    var body: some View {
        NavigationStack {
            Form {
                ProjectFormSections(draft: $draft, listsAreReadOnly: project?.isComplete == true)
            }
            .navigationTitle(project == nil ? "New project" : "Edit project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        do {
                            _ = try draft.save(in: context, project: project)
                            dismiss()
                        } catch { saveError = true }
                    }.buttonStyle(SaveButtonStyle()).disabled(!draft.canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil,
                            for: nil)
                    }
                }
            }
            .alert("Couldn’t save project", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try saving again.")
            }
        }
    }
}

struct ProjectCreateFields: View {
    @Environment(\.modelContext) private var context
    @State private var draft = ProjectDraft()
    @State private var saveError = false
    let done: () -> Void

    var body: some View {
        ProjectFormSections(
            draft: $draft,
            createSaveButton: AnyView(
                Button("Save") {
                    do {
                        _ = try draft.save(in: context)
                        done()
                    } catch { saveError = true }
                }.buttonStyle(SaveButtonStyle()).disabled(!draft.canSave))
        )

        .alert("Couldn’t save project", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try saving again.")
        }
    }
}
