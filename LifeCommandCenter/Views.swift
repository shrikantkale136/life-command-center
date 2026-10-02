import SwiftUI
import SwiftData
import UserNotifications
import Charts

private let ink = Color.primary
private let forest = Color(red: 0.27, green: 0.42, blue: 0.35)
private let canvas = Color(uiColor: .systemGroupedBackground)

struct TodayView: View {
    @AppStorage("preferredName") private var preferredName = ""
    let tasks: [TaskItem]; let maintenance: [HomeMaintenance]; let projects: [HomeProject]; let subscriptions: [SubscriptionItem]; let bills: [BillItem]
    let add: () -> Void; let edit: (TaskItem) -> Void; let toggle: (TaskItem) -> Void
    private var todayTasks: [TaskItem] { tasks.filter { Calendar.current.isDateInToday($0.dueDate) && !$0.isComplete }.sorted { $0.priorityRaw > $1.priorityRaw } }
    private var upcomingTasks: [TaskItem] { tasks.filter { !$0.isComplete && !Calendar.current.isDateInToday($0.dueDate) && $0.dueDate >= Calendar.current.startOfDay(for: .now) && $0.dueDate <= Calendar.current.date(byAdding: .day, value: 7, to: .now)! } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(greeting).font(.subheadline.weight(.semibold)).foregroundStyle(forest)
                        Text("Your day, in focus.").font(.system(size: 32, weight: .bold, design: .rounded))
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { SectionHeading(title: "Today", subtitle: "\(todayTasks.count) to take care of"); Spacer(); Button("See all") {}.font(.subheadline.weight(.semibold)) }
                        if todayTasks.isEmpty { EmptyCard(symbol: "sun.max", title: "A little breathing room", subtitle: "No tasks for today. Enjoy it.", button: "Add a task", action: add) }
                        else { VStack(spacing: 0) { ForEach(todayTasks) { task in TaskRow(task: task, toggle: { toggle(task) }, edit: { edit(task) }); if task.id != todayTasks.last?.id { Divider().padding(.leading, 48) } } }.padding(.horizontal, 14).cardStyle() }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "Coming up", subtitle: "The next 7 days")
                        let items = upcomingTasks.map { (title: $0.title, date: $0.dueDate, icon: "checkmark.circle", color: forest, amount: "") } + bills.filter { $0.dueDate >= .now }.map { (title: $0.name, date: $0.dueDate, icon: "dollarsign.circle.fill", color: Color.orange, amount: $0.amount.currency) } + subscriptions.filter { $0.nextDate >= .now }.map { (title: $0.name, date: $0.nextDate, icon: "arrow.clockwise.circle.fill", color: Color.purple, amount: $0.cost.currency) }
                        if items.isEmpty { Text("Nothing else on the horizon.").font(.subheadline).foregroundStyle(.secondary).padding(18).frame(maxWidth: .infinity, alignment: .leading).cardStyle() }
                        else { VStack(spacing: 0) { ForEach(Array(items.sorted { $0.date < $1.date }.prefix(5).enumerated()), id: \.offset) { _, item in HStack(spacing: 13) { Image(systemName: item.icon).font(.title3).foregroundStyle(item.color).frame(width: 26); VStack(alignment: .leading, spacing: 3) { Text(item.title).font(.subheadline.weight(.semibold)); Text(item.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(item.amount).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }.padding(15); if item.title != items.last?.title { Divider().padding(.leading, 54) } } }.cardStyle() }
                    }
                    HStack { SectionHeading(title: "At home", subtitle: "Your home, cared for"); Spacer(); NavigationLink { HomeView(maintenance: maintenance, projects: projects, add: add) } label: { Image(systemName: "arrow.up.right").font(.subheadline.weight(.bold)).foregroundStyle(forest).padding(10).background(forest.opacity(0.1), in: Circle()) } }
                    HStack(spacing: 12) {
                        MetricCard(icon: "wrench.and.screwdriver.fill", color: .orange, value: "\(maintenance.filter { $0.nextDue <= Calendar.current.date(byAdding: .day, value: 7, to: .now)! }.count)", caption: "Due soon")
                        MetricCard(icon: "hammer.fill", color: forest, value: "\(projects.filter { $0.status == "In Progress" }.count)", caption: "Active projects")
                    }
                    if let project = projects.first(where: { $0.status == "In Progress" }) { ProjectCard(project: project) }
                    HStack { SectionHeading(title: "Renewals", subtitle: "\(subscriptions.filter { Calendar.current.isDate($0.nextDate, equalTo: .now, toGranularity: .month) }.count) this month"); Spacer(); Text(subscriptions.reduce(0) { $0 + $1.monthlyCost }.currency + " / mo").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                    if subscriptions.isEmpty { EmptyCard(symbol: "creditcard", title: "No subscriptions yet", subtitle: "Keep renewals and costs in one place.", button: "Add subscription", action: add) }
                    else { VStack(spacing: 0) { ForEach(Array(subscriptions.prefix(3))) { item in HStack { Circle().fill(Color.purple.opacity(0.15)).frame(width: 38, height: 38).overlay(Image(systemName: "arrow.clockwise").foregroundStyle(.purple)); VStack(alignment: .leading, spacing: 3) { Text(item.name).font(.subheadline.weight(.semibold)); Text(item.nextDate.formatted(.dateTime.month(.abbreviated).day())).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(item.cost.currency).font(.subheadline.weight(.semibold)) }.padding(13) } }.cardStyle() }
                }.padding(.horizontal, 20).padding(.bottom, 100)
            }.background(canvas).navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { MoreView(add: add) } label: { Image(systemName: "ellipsis.circle") }
                        .accessibilityLabel("More tools")
                }
                ToolbarItem(placement: .topBarTrailing) { Button(action: add) { Image(systemName: "plus").font(.headline).foregroundStyle(.white).frame(width: 38, height: 38).background(forest, in: Circle()) }.accessibilityLabel("Quick add") }
            }
        }
    }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeGreeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "\(timeGreeting) 👋" : "\(timeGreeting), \(name) 👋"
    }
}

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

struct GroceriesView: View {
    @Environment(\.modelContext) private var context
    let items: [GroceryItem]
    let add: () -> Void
    @State private var search = ""
    @State private var category = "All"

    private let categories = ["All", "Produce", "Dairy & Eggs", "Bakery", "Meat & Seafood", "Pantry", "Frozen", "Household", "Other"]
    private var tripItems: [GroceryItem] { items.filter(\.isStaged).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
    private var catalogItems: [GroceryItem] {
        items.filter { item in
            (category == "All" || item.category == category) &&
            (search.isEmpty || item.name.localizedCaseInsensitiveContains(search) || item.category.localizedCaseInsensitiveContains(search))
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR REUSABLE LIST").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(forest)
                        Text("Groceries").font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Keep your staples here. Tap to add them to today's trip.").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 10)

                    VStack(alignment: .leading, spacing: 13) {
                        SectionHeading(title: "Today's trip", subtitle: tripItems.isEmpty ? "Ready when you are" : "\(tripItems.count) \(tripItems.count == 1 ? "item" : "items")")
                        if tripItems.isEmpty {
                            EmptyCard(symbol: "basket", title: "Your shopping list is clear", subtitle: "Add items from your catalog below. They'll stay saved for next time.", button: "Add grocery", action: add)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(tripItems) { item in
                                    HStack(spacing: 12) {
                                        Button { item.isPurchased.toggle() } label: {
                                            Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle").font(.title2)
                                                .foregroundStyle(item.isPurchased ? forest : forest.opacity(0.65))
                                        }.buttonStyle(.plain).accessibilityLabel(item.isPurchased ? "Mark \(item.name) not purchased" : "Mark \(item.name) purchased")
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name).font(.subheadline.weight(.semibold)).strikethrough(item.isPurchased)
                                                .foregroundStyle(item.isPurchased ? .secondary : .primary)
                                            Text(item.category).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        HStack(spacing: 12) {
                                            Button { item.quantity = max(1, item.quantity - 1) } label: { Image(systemName: "minus.circle").foregroundStyle(.secondary) }
                                                .buttonStyle(.plain).accessibilityLabel("Decrease \(item.name) quantity")
                                            Text("\(item.quantity)").font(.subheadline.monospacedDigit().weight(.semibold)).frame(minWidth: 18)
                                            Button { item.quantity += 1 } label: { Image(systemName: "plus.circle").foregroundStyle(forest) }
                                                .buttonStyle(.plain).accessibilityLabel("Increase \(item.name) quantity")
                                        }.disabled(item.isPurchased)
                                    }.padding(14)
                                    if item.id != tripItems.last?.id { Divider().padding(.leading, 50) }
                                }
                            }.cardStyle()
                            Text("Tap the circle to mark an item purchased. It stays here until you finish the trip.")
                                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 3)
                            HStack {
                                Spacer()
                                Button(action: finishTrip) {
                                    Label("Done for the day", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 11)
                                }.buttonStyle(.borderedProminent).tint(forest)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            SectionHeading(title: "Master catalog", subtitle: "Reusable favorites, ready to stage")
                            Spacer()
                            Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) }
                                .accessibilityLabel("Add grocery to catalog")
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { option in
                                    Button { category = option } label: {
                                        Text(option).font(.caption.weight(.semibold)).padding(.horizontal, 13).padding(.vertical, 8)
                                            .foregroundStyle(category == option ? Color.white : Color.primary)
                                            .background(category == option ? forest : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        if catalogItems.isEmpty {
                            EmptyCard(symbol: "list.bullet.rectangle", title: search.isEmpty ? "No catalog items here" : "No matches", subtitle: "Add an item once and keep it for future shopping trips.", button: "Add grocery", action: add)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(catalogItems) { item in
                                    HStack(spacing: 12) {
                                        Image(systemName: categorySymbol(item.category)).font(.subheadline).foregroundStyle(forest)
                                            .frame(width: 36, height: 36).background(forest.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name).font(.subheadline.weight(.semibold))
                                            Text(item.category).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if item.isStaged {
                                            Label("On trip", systemImage: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(forest)
                                        } else {
                                            Button { stage(item) } label: {
                                                Label("Add", systemImage: "plus").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                                                    .foregroundStyle(forest).background(forest.opacity(0.1), in: Capsule())
                                            }.buttonStyle(.plain)
                                        }
                                    }.padding(13).contentShape(Rectangle())
                                        .onTapGesture { if !item.isStaged { stage(item) } }
                                        .contextMenu {
                                            if !item.isStaged { Button("Add to today's trip", systemImage: "plus") { stage(item) } }
                                            Button("Delete from catalog", systemImage: "trash", role: .destructive) { context.delete(item) }
                                        }
                                    if item.id != catalogItems.last?.id { Divider().padding(.leading, 62) }
                                }
                            }.cardStyle()
                        }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 40)
            }.background(canvas)
                .navigationTitle("Groceries")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "Search your catalog")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: add) { Image(systemName: "plus") } } }
        }
    }

    private func stage(_ item: GroceryItem) { item.quantity = 1; item.isPurchased = false; item.isStaged = true }
    private func finishTrip() {
        tripItems.forEach { item in
            if item.isPurchased { item.lastPurchasedAt = .now }
            item.isStaged = false
            item.isPurchased = false
            item.quantity = 1
        }
    }
    private func categorySymbol(_ category: String) -> String {
        switch category { case "Produce": "leaf.fill"; case "Dairy & Eggs": "drop.fill"; case "Bakery": "basket.fill"; case "Meat & Seafood": "fish.fill"; case "Frozen": "snowflake"; case "Household": "house.fill"; default: "takeoutbag.and.cup.and.straw.fill" }
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    let maintenance: [HomeMaintenance]; let projects: [HomeProject]; let add: () -> Void
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 5) { Text("HOME MANAGEMENT").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(forest); Text("Care for your place.").font(.system(size: 30, weight: .bold, design: .rounded)) }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
        HStack(spacing: 12) { MetricCard(icon: "wrench.and.screwdriver.fill", color: .orange, value: "\(maintenance.filter { $0.nextDue < Calendar.current.startOfDay(for: .now) }.count)", caption: "Overdue"); MetricCard(icon: "hammer.fill", color: forest, value: "\(projects.filter { $0.status == "In Progress" }.count)", caption: "In progress") }
        HStack { SectionHeading(title: "Maintenance", subtitle: "A little upkeep goes a long way"); Spacer(); Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) } }
        if maintenance.isEmpty { EmptyCard(symbol: "wrench.adjustable", title: "No maintenance tracked", subtitle: "Keep service dates and home care together.", button: "Add maintenance", action: add) }
        else { VStack(spacing: 0) { ForEach(maintenance) { item in HStack(spacing: 13) { Image(systemName: "wrench.and.screwdriver.fill").foregroundStyle(.orange).frame(width: 34, height: 34).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 11)); VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.subheadline.weight(.semibold)); Text("\(item.area) · \(item.frequencyRaw)").font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing, spacing: 4) { Text(item.nextDue.formatted(.dateTime.month(.abbreviated).day())).font(.caption.weight(.semibold)); Text(item.nextDue < .now ? "Overdue" : "Due").font(.caption2).foregroundStyle(item.nextDue < .now ? .red : .secondary) } }.padding(14).contentShape(Rectangle()).contextMenu { Button("Mark complete", systemImage: "checkmark") { item.lastCompleted = .now; if let rule = RepeatRule(rawValue: item.frequencyRaw), let next = rule.next(after: item.nextDue) { item.nextDue = next } } }; if item.id != maintenance.last?.id { Divider().padding(.leading, 58) } } }.cardStyle() }
        HStack { SectionHeading(title: "Projects", subtitle: "Make progress, one step at a time"); Spacer(); Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) } }
        if projects.isEmpty { EmptyCard(symbol: "hammer", title: "No active projects", subtitle: "Start planning your next home improvement.", button: "Add project", action: add) }
        else { ForEach(projects) { project in ProjectCard(project: project) } }
    }.padding(20).padding(.bottom, 70) }.background(canvas).navigationTitle("Home").navigationBarTitleDisplayMode(.inline) } }
}

struct SubscriptionsView: View {
    let items: [SubscriptionItem]; let bills: [BillItem]; let add: () -> Void
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 5) { Text("MONEY OVERVIEW").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(forest); Text("Stay ahead of renewals.").font(.system(size: 30, weight: .bold, design: .rounded)) }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
        HStack(spacing: 12) { VStack(alignment: .leading, spacing: 8) { Image(systemName: "arrow.clockwise").foregroundStyle(.purple); Text(items.reduce(0) { $0 + $1.monthlyCost }.currency).font(.title2.bold()); Text("per month").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).cardStyle(); VStack(alignment: .leading, spacing: 8) { Image(systemName: "calendar").foregroundStyle(forest); Text((items.reduce(0) { $0 + $1.monthlyCost } * 12).currency).font(.title2.bold()); Text("per year").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).cardStyle() }
        if !items.isEmpty { VStack(alignment: .leading, spacing: 10) { SectionHeading(title: "By category", subtitle: "Monthly equivalent"); Chart(categoryTotals, id: \.key) { item in BarMark(x: .value("Monthly", item.value), y: .value("Category", item.key)).foregroundStyle(forest.gradient).cornerRadius(6) }.frame(height: CGFloat(max(90, categoryTotals.count * 30))).chartXAxis { AxisMarks(position: .bottom) }; }.padding(16).cardStyle() }
        HStack { SectionHeading(title: "Subscriptions", subtitle: "\(items.count) active"); Spacer(); Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) } }
        if items.isEmpty { EmptyCard(symbol: "creditcard", title: "No subscriptions added", subtitle: "See what renews and what it costs.", button: "Add subscription", action: add) }
        else { VStack(spacing: 0) { ForEach(items) { item in HStack(spacing: 12) { Image(systemName: "arrow.clockwise").foregroundStyle(.purple).frame(width: 34, height: 34).background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 11)); VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.subheadline.weight(.semibold)); Text("\(item.category) · \(item.frequencyRaw)").font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing, spacing: 4) { Text(item.cost.currency).font(.subheadline.weight(.semibold)); Text(item.nextDate.formatted(.dateTime.month(.abbreviated).day())).font(.caption).foregroundStyle(.secondary) } }.padding(14); if item.id != items.last?.id { Divider().padding(.leading, 58) } } }.cardStyle() }
        HStack { SectionHeading(title: "Bills", subtitle: "Upcoming payments"); Spacer(); Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) } }
        if bills.isEmpty { EmptyCard(symbol: "doc.text", title: "No upcoming bills", subtitle: "Track bills alongside your other plans.", button: "Add bill", action: add) }
        else { VStack(spacing: 0) { ForEach(bills) { bill in HStack { Image(systemName: "doc.text.fill").foregroundStyle(.orange).frame(width: 34, height: 34).background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 11)); VStack(alignment: .leading, spacing: 4) { Text(bill.name).font(.subheadline.weight(.semibold)); Text("Due \(bill.dueDate.formatted(.dateTime.month(.abbreviated).day()))").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(bill.amount.currency).font(.subheadline.weight(.semibold)) }.padding(14) } }.cardStyle() }
    }.padding(20).padding(.bottom, 70) }.background(canvas).navigationTitle("Money").navigationBarTitleDisplayMode(.inline) } }
    private var categoryTotals: [(key: String, value: Double)] { Dictionary(grouping: items, by: \.category).map { ($0.key, $0.value.reduce(0) { $0 + $1.monthlyCost }) }.sorted { $0.value > $1.value } }
}

struct MoreView: View {
    let add: () -> Void
    var body: some View { NavigationStack { List {
        Section { NavigationLink { CalendarView() } label: { Label("Calendar", systemImage: "calendar") }; NavigationLink { SearchView() } label: { Label("Search everything", systemImage: "magnifyingglass") }; NavigationLink { StatisticsView() } label: { Label("Statistics", systemImage: "chart.bar.fill") } }
        Section("Create") { Button(action: add) { Label("Quick add", systemImage: "plus.circle") } }
        Section("Preferences") { NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }; Label("Your data stays on this device", systemImage: "lock.shield").foregroundStyle(.secondary) }
    }.navigationTitle("More") } }
}

struct TaskRow: View {
    let task: TaskItem; let toggle: () -> Void; let edit: () -> Void
    var body: some View { HStack(spacing: 13) { Button(action: toggle) { Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(task.isComplete ? forest : .secondary.opacity(0.5)) }.buttonStyle(.plain); VStack(alignment: .leading, spacing: 4) { Text(task.title).font(.subheadline.weight(.semibold)).strikethrough(task.isComplete).foregroundStyle(task.isComplete ? .secondary : ink); HStack(spacing: 7) { Text(task.category); if task.repeatRule != .none { Label(task.repeatRaw, systemImage: "repeat") }; if !Calendar.current.isDateInToday(task.dueDate) { Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day())) } }.font(.caption).foregroundStyle(.secondary) }; Spacer(); Circle().fill(task.priority.color).frame(width: 7, height: 7) }.padding(.vertical, 12).contentShape(Rectangle()).onTapGesture(perform: edit).contextMenu { Button("Edit", systemImage: "pencil", action: edit); Button(task.isComplete ? "Reopen" : "Complete", systemImage: "checkmark", action: toggle); Button("Snooze until tomorrow", systemImage: "zzz") { task.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now } }
    }
}

struct ProjectCard: View {
    let project: HomeProject
    var body: some View { VStack(alignment: .leading, spacing: 12) { HStack { Image(systemName: "hammer.fill").foregroundStyle(forest); Text(project.area.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary); Spacer(); Text(project.status).font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 5).background(forest.opacity(0.1), in: Capsule()) }; Text(project.name).font(.headline); ProgressView(value: project.progress).tint(forest); HStack { Text("\(project.tasks.filter(\.isComplete).count) / \(project.tasks.count) tasks complete"); Spacer(); if project.estimatedCost > 0 { Text("\(project.actualCost.currency) / \(project.estimatedCost.currency)") } }.font(.caption).foregroundStyle(.secondary); if !project.tasks.isEmpty { ForEach(project.tasks.prefix(3)) { task in Button { task.isComplete.toggle() } label: { Label(task.title, systemImage: task.isComplete ? "checkmark.circle.fill" : "circle").font(.caption).foregroundStyle(task.isComplete ? forest : .secondary) } } } }.padding(16).cardStyle() }
}

struct SectionHeading: View { let title: String; let subtitle: String; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.title3.bold()); Text(subtitle).font(.caption).foregroundStyle(.secondary) } } }
struct MetricCard: View { let icon: String; let color: Color; let value: String; let caption: String; var body: some View { VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).font(.subheadline).foregroundStyle(color); Text(value).font(.title2.bold()); Text(caption).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(15).cardStyle() } }
struct EmptyCard: View { let symbol: String; let title: String; let subtitle: String; let button: String; let action: () -> Void; var body: some View { VStack(spacing: 9) { Image(systemName: symbol).font(.title2).foregroundStyle(forest); Text(title).font(.subheadline.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center); Button(button, action: action).font(.subheadline.weight(.semibold)).padding(.top, 3) }.frame(maxWidth: .infinity).padding(22).cardStyle() } }
extension View { func cardStyle() -> some View { self.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous)) } }
extension Double { var currency: String { formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) } }

struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var type: String
    init(initialType: String) { _type = State(initialValue: initialType) }
    private let types = ["Task", "Reminder", "Chore", "Grocery item", "Maintenance", "Project", "Subscription", "Bill"]
    var body: some View { NavigationStack { Form { Section { Picker("What would you like to add?", selection: $type) { ForEach(types, id: \.self) { Text($0) } }.pickerStyle(.menu) }; Section { switch type { case "Task", "Reminder", "Chore": TaskCreateFields(kind: type, done: { dismiss() }); case "Grocery item": GroceryCreateFields(done: { dismiss() }); case "Maintenance": MaintenanceCreateFields(done: { dismiss() }); case "Project": ProjectCreateFields(done: { dismiss() }); case "Subscription": SubscriptionCreateFields(done: { dismiss() }); default: BillCreateFields(done: { dismiss() }) } } }.navigationTitle("Quick add").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } } } }
}

struct TaskCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var title = ""; @State private var date = Date.now; @State private var category = "Personal"; @State private var priority: TaskPriority = .medium; @State private var repeatRule: RepeatRule = .none; @State private var reminder = false
    let kind: String; let done: () -> Void
    var body: some View { TextField("What needs doing?", text: $title); DatePicker("Due", selection: $date, displayedComponents: [.date, .hourAndMinute]); Picker("Category", selection: $category) { ForEach(["Personal", "Work", "Home", "Finance", "Shopping", "Health", "Family", "Other"], id: \.self) { Text($0) } }; Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0) } }; Picker("Repeat", selection: $repeatRule) { ForEach(RepeatRule.allCases) { Text($0.rawValue).tag($0) } }; Toggle("Remind me", isOn: $reminder); Button("Save \(kind)") { guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }; let item = TaskItem(title: title, dueDate: date, priority: priority, category: kind == "Chore" ? "Home" : category, repeatRule: repeatRule, reminderEnabled: reminder); context.insert(item); if reminder { NotificationService.schedule(id: item.persistentModelID.hashValue.description, title: item.title, date: date) }; done() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty) }
}

struct MaintenanceCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var name = ""; @State private var area = "HVAC"; @State private var due = Date.now; @State private var repeatRule: RepeatRule = .quarterly
    let done: () -> Void
    var body: some View { TextField("Maintenance item", text: $name); Picker("Area", selection: $area) { ForEach(["Kitchen", "Living Room", "Bedroom", "Bathroom", "Garage", "Yard", "HVAC", "Plumbing", "Electrical", "Exterior", "Appliances", "Other"], id: \.self) { Text($0) } }; DatePicker("Next due", selection: $due, displayedComponents: .date); Picker("Frequency", selection: $repeatRule) { ForEach(RepeatRule.allCases.filter { $0 != .none }) { Text($0.rawValue).tag($0) } }; Button("Save maintenance") { guard !name.isEmpty else { return }; context.insert(HomeMaintenance(name: name, area: area, nextDue: due, frequency: repeatRule)); done() }.disabled(name.isEmpty) }
}

struct ProjectCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var name = ""; @State private var area = "Home"; @State private var target = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now; @State private var cost = ""; @State private var tasksText = ""
    let done: () -> Void
    var body: some View { TextField("Project name", text: $name); TextField("Area", text: $area); DatePicker("Target date", selection: $target, displayedComponents: .date); TextField("Estimated cost", text: $cost).keyboardType(.decimalPad); TextField("Tasks (one per line)", text: $tasksText, axis: .vertical).lineLimit(3...7); Button("Save project") { guard !name.isEmpty else { return }; let p = HomeProject(name: name, area: area, targetDate: target, estimatedCost: Double(cost) ?? 0); context.insert(p); for line in tasksText.split(whereSeparator: \.isNewline) { let t = ProjectTask(title: String(line), project: p); p.tasks.append(t); context.insert(t) }; done() }.disabled(name.isEmpty) }
}

struct SubscriptionCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var name = ""; @State private var category = "Streaming"; @State private var cost = ""; @State private var frequency = "Monthly"; @State private var next = Date.now
    let done: () -> Void
    var body: some View { TextField("Subscription name", text: $name); TextField("Category", text: $category); TextField("Cost", text: $cost).keyboardType(.decimalPad); Picker("Billing frequency", selection: $frequency) { ForEach(["Weekly", "Monthly", "Quarterly", "Semi-Annual", "Annual"], id: \.self) { Text($0) } }; DatePicker("Next renewal", selection: $next, displayedComponents: .date); Button("Save subscription") { guard !name.isEmpty else { return }; context.insert(SubscriptionItem(name: name, category: category, cost: Double(cost) ?? 0, frequency: frequency, nextDate: next)); done() }.disabled(name.isEmpty) }
}

struct BillCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var name = ""; @State private var amount = ""; @State private var due = Date.now; @State private var frequency = "Monthly"; @State private var reminder = false
    let done: () -> Void
    var body: some View { TextField("Bill name", text: $name); TextField("Amount", text: $amount).keyboardType(.decimalPad); DatePicker("Due date", selection: $due, displayedComponents: .date); Picker("Frequency", selection: $frequency) { ForEach(["Weekly", "Monthly", "Quarterly", "Annual"], id: \.self) { Text($0) } }; Toggle("Remind me", isOn: $reminder); Button("Save bill") { guard !name.isEmpty else { return }; let bill = BillItem(name: name, amount: Double(amount) ?? 0, dueDate: due, frequency: frequency); context.insert(bill); if reminder { NotificationService.schedule(id: bill.persistentModelID.hashValue.description, title: "\(name) is due", date: due) }; done() }.disabled(name.isEmpty) }
}

struct GroceryCreateFields: View {
    @Environment(\.modelContext) private var context
    @Query private var existingItems: [GroceryItem]
    @State private var name = ""
    @State private var category = "Other"
    @State private var addToTrip = true
    let done: () -> Void
    private let categories = ["Produce", "Dairy & Eggs", "Bakery", "Meat & Seafood", "Pantry", "Frozen", "Household", "Other"]

    var body: some View {
        TextField("Item name", text: $name)
        Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0) } }
        Toggle("Add to today's trip", isOn: $addToTrip)
        Button("Save grocery") {
            let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            if let existing = existingItems.first(where: { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) {
                if addToTrip { existing.quantity = 1; existing.isPurchased = false; existing.isStaged = true }
            } else {
                context.insert(GroceryItem(name: cleaned, category: category, isStaged: addToTrip))
            }
            done()
        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context; @Bindable var task: TaskItem
    var body: some View { NavigationStack { Form { TextField("Title", text: $task.title); TextField("Notes", text: $task.detail, axis: .vertical); DatePicker("Due", selection: $task.dueDate, displayedComponents: [.date, .hourAndMinute]); Picker("Priority", selection: $task.priorityRaw) { ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0.rawValue) } }; Picker("Category", selection: $task.category) { ForEach(["Personal", "Work", "Home", "Finance", "Shopping", "Health", "Family", "Other"], id: \.self) { Text($0) } }; Picker("Repeat", selection: $task.repeatRaw) { ForEach(RepeatRule.allCases) { Text($0.rawValue).tag($0.rawValue) } }; Toggle("Remind me", isOn: $task.reminderEnabled); Section { Button("Delete task", role: .destructive) { context.delete(task); dismiss() } } }.navigationTitle("Edit task").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .topBarTrailing) { Button("Save") { if task.reminderEnabled { NotificationService.schedule(id: task.persistentModelID.hashValue.description, title: task.title, date: task.dueDate) }; dismiss() }.fontWeight(.semibold) } } } }
}

struct CalendarView: View {
    @Query private var tasks: [TaskItem]; @Query private var bills: [BillItem]; @Query private var subs: [SubscriptionItem]; @Query private var maint: [HomeMaintenance]
    @State private var selected = Date.now
    var body: some View { VStack { DatePicker("Select a date", selection: $selected, displayedComponents: .date).datePickerStyle(.graphical).padding(.horizontal, 8); List { let day = Calendar.current; ForEach(tasks.filter { day.isDate($0.dueDate, inSameDayAs: selected) }) { Label($0.title, systemImage: "checkmark.circle").foregroundStyle(forest) }; ForEach(bills.filter { day.isDate($0.dueDate, inSameDayAs: selected) }) { Label("\($0.name) · \($0.amount.currency)", systemImage: "dollarsign.circle") }; ForEach(subs.filter { day.isDate($0.nextDate, inSameDayAs: selected) }) { Label("\($0.name) renewal", systemImage: "arrow.clockwise.circle") }; ForEach(maint.filter { day.isDate($0.nextDue, inSameDayAs: selected) }) { Label($0.name, systemImage: "wrench.and.screwdriver") } }.listStyle(.plain) }.navigationTitle("Calendar") }
}

struct SearchView: View {
    @Query private var tasks: [TaskItem]; @Query private var projects: [HomeProject]; @Query private var maint: [HomeMaintenance]; @Query private var subs: [SubscriptionItem]; @Query private var bills: [BillItem]; @Query private var groceries: [GroceryItem]
    @State private var query = ""
    var body: some View { List { ForEach(tasks.filter { matches($0.title, $0.detail) }) { Label($0.title, systemImage: "checkmark.circle") }; ForEach(projects.filter { matches($0.name, $0.detail) }) { Label($0.name, systemImage: "hammer") }; ForEach(maint.filter { matches($0.name, $0.detail, $0.notes) }) { Label($0.name, systemImage: "wrench.and.screwdriver") }; ForEach(subs.filter { matches($0.name, $0.category, $0.notes) }) { Label($0.name, systemImage: "arrow.clockwise") }; ForEach(bills.filter { matches($0.name, $0.notes) }) { Label($0.name, systemImage: "doc.text") }; ForEach(groceries.filter { matches($0.name, $0.category) }) { Label($0.name, systemImage: "basket") } }.searchable(text: $query, prompt: "Tasks, home, groceries…").navigationTitle("Search") }
    private func matches(_ values: String...) -> Bool { !query.isEmpty && values.contains { $0.localizedCaseInsensitiveContains(query) } }
}

struct StatisticsView: View {
    @Query private var tasks: [TaskItem]; @Query private var projects: [HomeProject]; @Query private var maintenance: [HomeMaintenance]; @Query private var subs: [SubscriptionItem]
    var body: some View { List { Section("Tasks") { LabeledContent("Completed this week", value: "\(tasks.filter { $0.isComplete && ($0.completedAt ?? .distantPast) > Calendar.current.date(byAdding: .day, value: -7, to: .now)! }.count)"); LabeledContent("Overdue", value: "\(tasks.filter { !$0.isComplete && $0.dueDate < Calendar.current.startOfDay(for: .now) }.count)"); LabeledContent("Completion", value: "\(tasks.isEmpty ? 0 : Int(Double(tasks.filter(\.isComplete).count) / Double(tasks.count) * 100))%") }; Section("Home") { LabeledContent("Active projects", value: "\(projects.filter { $0.status == "In Progress" }.count)"); LabeledContent("Maintenance overdue", value: "\(maintenance.filter { $0.nextDue < .now }.count)") }; Section("Subscriptions") { LabeledContent("Monthly cost", value: subs.reduce(0) { $0 + $1.monthlyCost }.currency); LabeledContent("Active subscriptions", value: "\(subs.count)") } }.navigationTitle("Statistics") }
}

struct SettingsView: View {
    @AppStorage("defaultPriority") private var defaultPriority = "Medium"; @AppStorage("appearance") private var appearance = "System"
    @AppStorage("preferredName") private var preferredName = ""
    var body: some View { Form { Section("Your profile") { TextField("What should Daykeeper call you?", text: $preferredName).textContentType(.givenName).autocorrectionDisabled() }; Section("Defaults") { Picker("Task priority", selection: $defaultPriority) { ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0.rawValue) } }; Picker("Appearance", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } } }; Section("Notifications") { Text("Reminders are delivered locally on this device and can use your preferred name.").font(.footnote).foregroundStyle(.secondary); Button("Request notification access") { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } } }; Section("Data") { Text("Your information is stored locally. Cloud sync can be added later.").font(.footnote).foregroundStyle(.secondary) }; Section("About") { LabeledContent("Daykeeper", value: "Version 1.0") } }.navigationTitle("Settings") }
}
