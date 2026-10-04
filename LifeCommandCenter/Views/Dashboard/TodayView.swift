import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct TodayView: View {
    @AppStorage("preferredName") private var preferredName = ""
    @State private var selectedCategory = "All"
    @State private var showingAllTodayTasks = false
    @State private var showingAllUpcoming = false
    @State private var showingAllProjects = false
    let tasks: [TaskItem]; let maintenance: [HomeMaintenance]; let projects: [HomeProject]; let subscriptions: [SubscriptionItem]; let bills: [BillItem]
    let add: () -> Void; let openHome: () -> Void; let openMoney: () -> Void; let edit: (TaskItem) -> Void; let toggle: (TaskItem) -> Void
    private var todayTasks: [TaskItem] {
        tasks.filter { Calendar.current.isDateInToday($0.dueDate) }
            .sorted { $0.dueDate < $1.dueDate }
    }
    private var taskCategories: [String] { ["All"] + Set(todayTasks.map(\.category)).sorted() }
    private var filteredTodayTasks: [TaskItem] {
        selectedCategory == "All" ? todayTasks : todayTasks.filter { $0.category == selectedCategory }
    }
    private var completedTaskCount: Int { filteredTodayTasks.filter(\.isComplete).count }
    private var completionProgress: Double {
        filteredTodayTasks.isEmpty ? 0 : Double(completedTaskCount) / Double(filteredTodayTasks.count)
    }
    private var completionPercentage: Int { Int((completionProgress * 100).rounded()) }
    private var upcomingTasks: [TaskItem] { tasks.filter { !$0.isComplete && !Calendar.current.isDateInToday($0.dueDate) && $0.dueDate >= Calendar.current.startOfDay(for: .now) && $0.dueDate <= Calendar.current.date(byAdding: .day, value: 7, to: .now)! } }
    private var upcomingItems: [DashboardUpcomingItem] {
        let horizon = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let taskEntries = upcomingTasks.map { DashboardUpcomingItem(id: "task-\($0.persistentModelID.hashValue)", title: $0.title, date: $0.dueDate, icon: "checkmark.circle", color: forest, amount: "") }
        let billEntries = bills.filter { $0.dueDate >= .now && $0.dueDate <= horizon }.map { DashboardUpcomingItem(id: "bill-\($0.persistentModelID.hashValue)", title: $0.name, date: $0.dueDate, icon: "dollarsign.circle.fill", color: .orange, amount: $0.amount.currency) }
        let renewalEntries = subscriptions.filter { $0.nextDate >= .now && $0.nextDate <= horizon }.map { DashboardUpcomingItem(id: "subscription-\($0.persistentModelID.hashValue)", title: $0.name, date: $0.nextDate, icon: "arrow.clockwise.circle.fill", color: .purple, amount: $0.cost.currency) }
        return (taskEntries + billEntries + renewalEntries).sorted { $0.date < $1.date }
    }
    private var activeProjects: [HomeProject] { projects.filter { $0.status == "In Progress" } }
    private var taskListHeight: CGFloat {
        let visibleCount = showingAllTodayTasks ? filteredTodayTasks.count : min(filteredTodayTasks.count, 4)
        return CGFloat(max(visibleCount, 1)) * 68
    }
    private var upcomingListHeight: CGFloat {
        let visibleCount = showingAllUpcoming ? upcomingItems.count : min(upcomingItems.count, 4)
        return CGFloat(max(visibleCount, 1)) * 62
    }
    private func showAllButton(isExpanded: Bool, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(isExpanded ? "Show less" : "Show all \(count)")
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(forest)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(greeting).font(.subheadline.weight(.semibold)).foregroundStyle(forest)
                        Text("Your day, in focus.").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center) {
                            SectionHeading(title: "Today's tasks", subtitle: "\(filteredTodayTasks.count - completedTaskCount) remaining")
                            Spacer()
                            Menu {
                                ForEach(taskCategories, id: \.self) { option in
                                    Button {
                                        selectedCategory = option
                                    } label: {
                                        if selectedCategory == option { Label(option, systemImage: "checkmark") }
                                        else { Text(option) }
                                    }
                                }
                            } label: {
                                Image(systemName: selectedCategory == "All" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                    .font(.title3).foregroundStyle(forest).frame(width: 36, height: 36)
                                    .contentShape(Circle())
                            }
                            .accessibilityLabel("Filter today's tasks by category")
                            Text("\(completedTaskCount) / \(filteredTodayTasks.count)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("\(completedTaskCount) of \(filteredTodayTasks.count) tasks completed")
                        }

                        HStack(spacing: 10) {
                            ProgressView(value: completionProgress)
                                .tint(forest)
                            Text("\(completionPercentage)%")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 38, alignment: .trailing)
                        }

                        if filteredTodayTasks.isEmpty {
                            if todayTasks.isEmpty {
                                EmptyCard(symbol: "sun.max", title: "A little breathing room", subtitle: "No tasks for today. Enjoy it.", button: "Add a task", action: add)
                            } else {
                                Text("No tasks in this category today.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(16).cardStyle()
                            }
                        } else {
                            ScrollView(.vertical) {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(filteredTodayTasks.prefix(showingAllTodayTasks ? filteredTodayTasks.count : 4))) { task in
                                        TaskRow(task: task, toggle: { toggle(task) }, edit: { edit(task) })
                                        if task.id != filteredTodayTasks.prefix(showingAllTodayTasks ? filteredTodayTasks.count : 4).last?.id { Divider().padding(.leading, 48) }
                                    }
                                }
                                .padding(.horizontal, 14)
                            }
                            .frame(height: showingAllTodayTasks ? taskListHeight : min(taskListHeight, 280))
                            .scrollIndicators(.visible)
                            .cardStyle()
                            if filteredTodayTasks.count > 4 {
                                showAllButton(isExpanded: showingAllTodayTasks, count: filteredTodayTasks.count) {
                                    withAnimation(.snappy) { showingAllTodayTasks.toggle() }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "Coming up", subtitle: "The next 7 days")
                        if upcomingItems.isEmpty { Text("Nothing else on the horizon.").font(.subheadline).foregroundStyle(.secondary).padding(18).frame(maxWidth: .infinity, alignment: .leading).cardStyle() }
                        else {
                            ScrollView(.vertical) {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(upcomingItems.prefix(showingAllUpcoming ? upcomingItems.count : 4))) { item in
                                        HStack(spacing: 13) {
                                            Image(systemName: item.icon).font(.title3).foregroundStyle(item.color).frame(width: 26)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.title).font(.subheadline.weight(.semibold))
                                                Text(item.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(item.amount).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                        }.padding(15)
                                        if item.id != upcomingItems.prefix(showingAllUpcoming ? upcomingItems.count : 4).last?.id { Divider().padding(.leading, 54) }
                                    }
                                }
                            }
                            .frame(height: showingAllUpcoming ? upcomingListHeight : min(upcomingListHeight, 248))
                            .scrollIndicators(.visible)
                            .cardStyle()
                            if upcomingItems.count > 4 {
                                showAllButton(isExpanded: showingAllUpcoming, count: upcomingItems.count) {
                                    withAnimation(.snappy) { showingAllUpcoming.toggle() }
                                }
                            }
                        }
                    }
                    HStack { SectionHeading(title: "At home", subtitle: "Your home, cared for"); Spacer(); Button(action: openHome) { Image(systemName: "arrow.up.right").font(.subheadline.weight(.bold)).foregroundStyle(forest).padding(10).background(forest.opacity(0.1), in: Circle()) }.accessibilityLabel("Open Home tab") }
                    HStack(spacing: 12) {
                        MetricCard(icon: "wrench.and.screwdriver.fill", color: .orange, value: "\(maintenance.filter { $0.nextDue <= Calendar.current.date(byAdding: .day, value: 7, to: .now)! }.count)", caption: "Due soon")
                        MetricCard(icon: "hammer.fill", color: forest, value: "\(projects.filter { $0.status == "In Progress" }.count)", caption: "Active projects")
                    }
                    if !activeProjects.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(activeProjects.prefix(showingAllProjects ? activeProjects.count : 3))) { project in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(project.name).font(.subheadline.weight(.semibold))
                                            Text("\(project.tasks.filter(\.isComplete).count) of \(project.tasks.count) tasks complete")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(Int((project.progress * 100).rounded()))%")
                                            .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(forest)
                                    }
                                    ProgressView(value: project.progress).tint(forest)
                                }.padding(14)
                                if project.id != activeProjects.prefix(showingAllProjects ? activeProjects.count : 3).last?.id { Divider().padding(.horizontal, 14) }
                            }
                        }.cardStyle()
                            if activeProjects.count > 3 {
                                showAllButton(isExpanded: showingAllProjects, count: activeProjects.count) {
                                    withAnimation(.snappy) { showingAllProjects.toggle() }
                                }
                            }
                    }
                    HStack { SectionHeading(title: "Money", subtitle: "Bills and renewals at a glance"); Spacer(); Button(action: openMoney) { Image(systemName: "arrow.up.right").font(.subheadline.weight(.bold)).foregroundStyle(forest).padding(10).background(forest.opacity(0.1), in: Circle()) }.accessibilityLabel("Open Money tab") }
                    let monthlyCost = subscriptions.reduce(0) { $0 + $1.monthlyCost }
                    let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            MetricCard(icon: "arrow.clockwise", color: .purple, value: monthlyCost.currency, caption: "Monthly subscriptions")
                            MetricCard(icon: "calendar", color: forest, value: (monthlyCost * 12).currency, caption: "Annual subscriptions")
                        }
                        HStack(spacing: 12) {
                            MetricCard(icon: "doc.text.fill", color: .orange, value: "\(bills.filter { $0.dueDate >= .now && $0.dueDate <= nextWeek }.count)", caption: "Bills due in 7 days")
                            MetricCard(icon: "bell.fill", color: .blue, value: "\(subscriptions.filter { $0.nextDate >= .now && $0.nextDate <= nextWeek }.count)", caption: "Renewals in 7 days")
                        }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 100)
            }.background(canvas).navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { CalendarView(addEvent: add, editTask: edit) } label: {
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
        let timeGreeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "\(timeGreeting) 👋" : "\(timeGreeting), \(name) 👋"
    }
}

private struct DashboardUpcomingItem: Identifiable {
    let id: String
    let title: String
    let date: Date
    let icon: String
    let color: Color
    let amount: String
}
