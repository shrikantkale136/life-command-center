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
                                    .accessibilityIdentifier("maintenance-row-\(item.name)")
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

struct MaintenanceDraft: Equatable {
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

// Observe taps alongside native menu controls without consuming their touches.
@MainActor
private final class ReminderPickerTouchMonitor: NSObject, UIGestureRecognizerDelegate {
    private final class WeakView {
        weak var view: UIView?
        init(_ view: UIView) { self.view = view }
    }
    private var anchors: [WeakView] = []
    private weak var window: UIWindow?
    private var recognizer: UITapGestureRecognizer?
    var onOutsideTap: () -> Void = {}

    func register(_ view: UIView) {
        anchors.removeAll { $0.view == nil }
        if !anchors.contains(where: { $0.view === view }) { anchors.append(WeakView(view)) }
        guard let window = view.window, self.window !== window else { return }
        if let recognizer { self.window?.removeGestureRecognizer(recognizer) }
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)
        self.window = window
        self.recognizer = recognizer
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        onOutsideTap()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch)
        -> Bool
    {
        guard let window else { return false }
        let point = touch.location(in: window)
        return !anchors.contains { anchor in
            guard let view = anchor.view, view.window === window else { return false }
            return view.convert(view.bounds, to: window).contains(point)
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    deinit {
        if let recognizer {
            let observedWindow = window
            DispatchQueue.main.async { [weak observedWindow] in
                observedWindow?.removeGestureRecognizer(recognizer)
            }
        }
    }
}

private struct ReminderPickerTouchAnchor: UIViewRepresentable {
    let monitor: ReminderPickerTouchMonitor

    final class AnchorView: UIView {
        weak var monitor: ReminderPickerTouchMonitor?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            monitor?.register(self)
        }
    }

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.monitor = monitor
        return view
    }

    func updateUIView(_ view: AnchorView, context: Context) { monitor.register(view) }
}

private struct MaintenanceFormSections: View {
    @Binding var draft: MaintenanceDraft
    var lastCompleted: Date? = nil
    var createSaveButton: AnyView? = nil
    @State private var focusedPicker: PickerFocus?
    @State private var touchMonitor = ReminderPickerTouchMonitor()
    @FocusState private var editingText: Bool
    private enum PickerFocus { case date, time }

    var body: some View {
        Section("Maintenance details") {
            TextField("Maintenance item", text: $draft.name).focused($editingText)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { createSaveButton }
                        .formIconBackground()
                }
            TextField("Area", text: $draft.area).focused($editingText)
            TextField("Description", text: $draft.detail, axis: .vertical).focused($editingText)
        }
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
            .background(ReminderPickerTouchAnchor(monitor: touchMonitor))
            if draft.dateEnabled && focusedPicker == .date {
                DatePicker("Due date", selection: $draft.nextDue, displayedComponents: .date)
                    .datePickerStyle(.graphical).labelsHidden()
                    .accessibilityIdentifier("maintenance-date-picker")
                    .background(ReminderPickerTouchAnchor(monitor: touchMonitor))
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
            .background(ReminderPickerTouchAnchor(monitor: touchMonitor))
            if draft.timeEnabled && focusedPicker == .time {
                DatePicker(
                    "Time", selection: $draft.reminderTime, displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel).labelsHidden().frame(height: 170).clipped()
                .accessibilityIdentifier("maintenance-time-picker")
                .background(ReminderPickerTouchAnchor(monitor: touchMonitor))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

        }
        .onAppear {
            touchMonitor.onOutsideTap = { [picker = $focusedPicker] in picker.wrappedValue = nil }
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
                    .focused($editingText)
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
                        displayedComponents: .date
                    )

                }
            }
        }
        .environment(\.calendar, draft.calendar).environment(\.timeZone, draft.calendar.timeZone)
        .onChange(of: draft.frequency) { _, frequency in
            focusedPicker = nil
            if frequency != .none && !draft.dateEnabled {
                draft.dateEnabled = true
                draft.nextDue = .now
            }
            if frequency == .hourly { draft.setTimeEnabled(true) }
        }
        Section("Notifications") {
            Toggle(
                "Remind me",
                isOn: Binding(
                    get: { draft.reminderEnabled },
                    set: { enabled in
                        focusedPicker = nil
                        draft.reminderEnabled = enabled
                    }))
            if draft.reminderEnabled && !draft.timeEnabled {
                Text(
                    "Reminders arrive at 9:00 AM on the due date. Turn on Time to choose a time."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        Section("Service") {
            TextField("Provider", text: $draft.provider).focused($editingText)
            HStack {
                Text("Cost")
                Spacer()
                ProjectCostField(
                    amount: $draft.cost, label: "Maintenance cost",
                    onFocus: {
                        focusedPicker = nil
                    }
                ).frame(width: 140, alignment: .trailing)
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
                ToolbarItem(placement: .cancellationAction) { FormCancelButton() }
                    .formIconBackground()
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        do {
                            try draft.save(in: context, item: item)
                            dismiss()
                        } catch { saveError = true }
                    }.buttonStyle(SaveButtonStyle()).disabled(!draft.canSave)
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
            .alert("Couldn’t save maintenance", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try saving again.")
            }
        }.formDiscardProtection(tracking: draft)
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

struct ProjectTaskDraft: Identifiable, Equatable {
    let id = UUID()
    var title = ""
    var isComplete = false
    var original: ProjectTask?
}

struct ProjectShoppingDraft: Identifiable, Equatable {
    let id = UUID()
    var name = ""
    var quantity = 1
    var unitCost = ""
    var isPurchased = false
    var original: ProjectShoppingItem?
    var estimatedTotal: Double { Double(quantity) * (ProjectDraft.amount(unitCost) ?? 0) }
}

struct ProjectDraft: Equatable {
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
    var onFocus: () -> Void = {}
    var visibleLabel: String? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 2) {
            if let visibleLabel {
                Text(visibleLabel).font(.subheadline).foregroundStyle(.secondary).padding(
                    .trailing, 4)
            }
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
        .onChange(of: isFocused) { _, focused in
            if focused { onFocus() }
        }
        .contentShape(Rectangle()).onTapGesture { isFocused = true }
    }
}

struct ProjectFormSections: View {
    @Binding var draft: ProjectDraft
    var listsAreReadOnly = false
    var createSaveButton: AnyView? = nil
    @State private var taskRowFrames: [UUID: CGRect] = [:]
    @State private var shoppingRowFrames: [UUID: CGRect] = [:]

    var body: some View {
        Section("Project details") {
            TextField("Project name", text: $draft.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { createSaveButton }
                        .formIconBackground()
                }
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
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary).padding(.vertical, 10)
                        .accessibilityLabel("Reorder \(task.title)")
                        .accessibilityAddTraits(.isButton)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                                .onChanged { value in
                                    reorder(
                                        task.id, at: value.location, frames: taskRowFrames,
                                        items: $draft.tasks)
                                }
                        )
                        .allowsHitTesting(!listsAreReadOnly)
                    TextField("Task title", text: $task.title, axis: .vertical)
                        .accessibilityLabel("Task title").accessibilityIdentifier(
                            "project-task-title")
                    Button(role: .destructive) {
                        draft.tasks.removeAll { $0.id == task.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless).accessibilityLabel("Remove task")
                }.padding(.vertical, 4)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.onAppear {
                                taskRowFrames[task.id] = geometry.frame(in: .global)
                            }
                            .onChange(of: geometry.frame(in: .global)) { _, frame in
                                taskRowFrames[task.id] = frame
                            }
                        })
            }
            Button {
                draft.tasks.append(ProjectTaskDraft())
            } label: {
                Label("Add task", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Task list")
        } footer: {
            Text(
                "Drag the handles to reorder tasks. Check tasks off on the project details page.")
        }.disabled(listsAreReadOnly)
        Section {
            if draft.shoppingItems.isEmpty {
                Text("Add supplies or purchases for this project.").foregroundStyle(.secondary)
            }
            ForEach($draft.shoppingItems) { $item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary).padding(.vertical, 10)
                        .accessibilityLabel("Reorder \(item.name)")
                        .accessibilityAddTraits(.isButton)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                                .onChanged { value in
                                    reorder(
                                        item.id, at: value.location, frames: shoppingRowFrames,
                                        items: $draft.shoppingItems)
                                }
                        )
                        .allowsHitTesting(!listsAreReadOnly)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            TextField("Shopping item", text: $item.name)
                            Button(role: .destructive) {
                                draft.shoppingItems.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless).accessibilityLabel("Remove shopping item")
                        }
                        HStack {
                            HStack(spacing: 6) {
                                Text("Qty").font(.subheadline).foregroundStyle(.secondary)
                                QuantitySwipeControl(value: $item.quantity)
                            }
                            Spacer()
                            ProjectCostField(
                                amount: $item.unitCost, label: "Estimated unit cost",
                                visibleLabel: "Unit cost")
                        }
                        LabeledContent("Item estimate", value: item.estimatedTotal.currency)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.onAppear {
                                shoppingRowFrames[item.id] = geometry.frame(in: .global)
                            }
                            .onChange(of: geometry.frame(in: .global)) { _, frame in
                                shoppingRowFrames[item.id] = frame
                            }
                        })
            }
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
                "Drag handles to reorder. Swipe quantities up or down. Estimates use quantity × unit cost."
            )
        }.disabled(listsAreReadOnly)
        Section {
            HStack {
                Text("Project estimate")
                Spacer()
                ProjectCostField(amount: $draft.estimatedCost, label: "Project estimate")
                    .frame(width: 140, alignment: .trailing)
            }
            HStack {
                Text("Actual cost")
                Spacer()
                ProjectCostField(amount: $draft.actualCost, label: "Actual cost")
                    .frame(width: 140, alignment: .trailing)
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
    private func reorder<Item: Identifiable>(
        _ id: UUID, at point: CGPoint,
        frames: [UUID: CGRect], items: Binding<[Item]>
    ) where Item.ID == UUID {
        guard !listsAreReadOnly,
            let target = frames.first(where: { $0.value.contains(point) })?.key,
            target != id,
            let source = items.wrappedValue.firstIndex(where: { $0.id == id }),
            let destination = items.wrappedValue.firstIndex(where: { $0.id == target })
        else { return }
        var reordered = items.wrappedValue
        reordered.move(
            fromOffsets: IndexSet(integer: source),
            toOffset: destination > source ? destination + 1 : destination)
        withAnimation(.easeInOut(duration: 0.15)) { items.wrappedValue = reordered }
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
                ToolbarItem(placement: .cancellationAction) { FormCancelButton() }
                    .formIconBackground()
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        do {
                            _ = try draft.save(in: context, project: project)
                            dismiss()
                        } catch { saveError = true }
                    }.buttonStyle(SaveButtonStyle()).disabled(!draft.canSave)
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
            .alert("Couldn’t save project", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try saving again.")
            }
        }.formDiscardProtection(tracking: draft)
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
