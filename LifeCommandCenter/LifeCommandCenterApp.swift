import SwiftUI
import SwiftData
import UserNotifications

@main
struct LifeCommandCenterApp: App {
    let container: ModelContainer = {
        let schema = Schema([TaskItem.self, HomeMaintenance.self, HomeProject.self, ProjectTask.self, SubscriptionItem.self, BillItem.self, GroceryItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            RootView().modelContainer(container)
        }
    }
}

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case low = "Low", medium = "Medium", high = "High", urgent = "Urgent"
    var id: String { rawValue }
    var color: Color { switch self { case .low: .blue; case .medium: .orange; case .high: .pink; case .urgent: .red } }
}

enum RepeatRule: String, CaseIterable, Identifiable, Codable {
    case none = "Never", daily = "Daily", weekly = "Weekly", monthly = "Monthly", quarterly = "Quarterly", yearly = "Yearly"
    var id: String { rawValue }
    func next(after date: Date) -> Date? {
        let c: Calendar = .current
        switch self {
        case .none: return nil
        case .daily: return c.date(byAdding: .day, value: 1, to: date)
        case .weekly: return c.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return c.date(byAdding: .month, value: 1, to: date)
        case .quarterly: return c.date(byAdding: .month, value: 3, to: date)
        case .yearly: return c.date(byAdding: .year, value: 1, to: date)
        }
    }
}

@Model final class TaskItem {
    var title: String
    var detail: String
    var dueDate: Date
    var priorityRaw: String
    var category: String
    var repeatRaw: String
    var isComplete: Bool
    var isSnoozed: Bool
    var createdAt: Date
    var completedAt: Date?
    var reminderEnabled: Bool
    var project: HomeProject?
    init(title: String, detail: String = "", dueDate: Date = .now, priority: TaskPriority = .medium, category: String = "Personal", repeatRule: RepeatRule = .none, reminderEnabled: Bool = false, project: HomeProject? = nil) {
        self.title = title; self.detail = detail; self.dueDate = dueDate; self.priorityRaw = priority.rawValue
        self.category = category; self.repeatRaw = repeatRule.rawValue; self.isComplete = false; self.isSnoozed = false
        self.createdAt = .now; self.reminderEnabled = reminderEnabled; self.project = project
    }
    var priority: TaskPriority { TaskPriority(rawValue: priorityRaw) ?? .medium }
    var repeatRule: RepeatRule { RepeatRule(rawValue: repeatRaw) ?? .none }
}

@Model final class HomeMaintenance {
    var name: String; var area: String; var detail: String; var nextDue: Date; var frequencyRaw: String
    var cost: Double; var provider: String; var notes: String; var lastCompleted: Date?
    init(name: String, area: String = "Home", detail: String = "", nextDue: Date = .now, frequency: RepeatRule = .quarterly, cost: Double = 0, provider: String = "", notes: String = "", lastCompleted: Date? = nil) {
        self.name = name; self.area = area; self.detail = detail; self.nextDue = nextDue; self.frequencyRaw = frequency.rawValue
        self.cost = cost; self.provider = provider; self.notes = notes; self.lastCompleted = lastCompleted
    }
}

@Model final class HomeProject {
    var name: String; var detail: String; var area: String; var startDate: Date; var targetDate: Date
    var status: String; var priorityRaw: String; var estimatedCost: Double; var actualCost: Double
    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project) var tasks: [ProjectTask] = []
    init(name: String, detail: String = "", area: String = "Home", startDate: Date = .now, targetDate: Date = .now, status: String = "In Progress", estimatedCost: Double = 0, actualCost: Double = 0) {
        self.name = name; self.detail = detail; self.area = area; self.startDate = startDate; self.targetDate = targetDate
        self.status = status; self.priorityRaw = TaskPriority.medium.rawValue; self.estimatedCost = estimatedCost; self.actualCost = actualCost
    }
    var progress: Double { tasks.isEmpty ? 0 : Double(tasks.filter(\.isComplete).count) / Double(tasks.count) }
}

@Model final class ProjectTask {
    var title: String; var isComplete: Bool; var project: HomeProject?
    init(title: String, project: HomeProject? = nil) { self.title = title; self.isComplete = false; self.project = project }
}

@Model final class SubscriptionItem {
    var name: String; var category: String; var cost: Double; var frequencyRaw: String; var nextDate: Date
    var paymentMethod: String; var autoRenew: Bool; var notes: String; var isActive: Bool
    init(name: String, category: String = "Streaming", cost: Double = 0, frequency: String = "Monthly", nextDate: Date = .now, paymentMethod: String = "", autoRenew: Bool = true, notes: String = "", isActive: Bool = true) {
        self.name = name; self.category = category; self.cost = cost; self.frequencyRaw = frequency; self.nextDate = nextDate
        self.paymentMethod = paymentMethod; self.autoRenew = autoRenew; self.notes = notes; self.isActive = isActive
    }
    var monthlyCost: Double { switch frequencyRaw { case "Weekly": cost * 52 / 12; case "Quarterly": cost / 3; case "Semi-Annual": cost / 6; case "Annual": cost / 12; default: cost } }
}

@Model final class BillItem {
    var name: String; var amount: Double; var dueDate: Date; var frequencyRaw: String; var autoPay: Bool; var paymentMethod: String; var notes: String
    init(name: String, amount: Double = 0, dueDate: Date = .now, frequency: String = "Monthly", autoPay: Bool = false, paymentMethod: String = "", notes: String = "") {
        self.name = name; self.amount = amount; self.dueDate = dueDate; self.frequencyRaw = frequency; self.autoPay = autoPay; self.paymentMethod = paymentMethod; self.notes = notes
    }
}

@Model final class GroceryItem {
    var name: String
    var category: String
    var isStaged: Bool
    var isPurchased: Bool = false
    var quantity: Int
    var lastPurchasedAt: Date?
    var createdAt: Date
    init(name: String, category: String = "Other", isStaged: Bool = false, isPurchased: Bool = false, quantity: Int = 1) {
        self.name = name
        self.category = category
        self.isStaged = isStaged
        self.isPurchased = isPurchased
        self.quantity = quantity
        self.createdAt = .now
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @Query(sort: \HomeMaintenance.nextDue) private var maintenance: [HomeMaintenance]
    @Query(sort: \HomeProject.targetDate) private var projects: [HomeProject]
    @Query(sort: \SubscriptionItem.nextDate) private var subscriptions: [SubscriptionItem]
    @Query(sort: \BillItem.dueDate) private var bills: [BillItem]
    @Query(sort: \GroceryItem.name) private var groceries: [GroceryItem]
    @State private var selectedTab = 0
    @State private var quickAdd = false
    @State private var quickAddType = "Task"
    @State private var quickAddGeneration = 0
    @State private var editTask: TaskItem?
    @AppStorage("didSeedInitialData") private var didSeed = false
    @AppStorage("didSeedGroceryCatalog") private var didSeedGroceries = false
    @AppStorage("appearance") private var appearance = "System"

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(tasks: tasks, maintenance: maintenance, projects: projects, subscriptions: subscriptions, bills: bills, add: openQuickAdd, edit: { editTask = $0 }, toggle: toggleTask)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }.tag(0)
            TasksView(tasks: tasks, add: openQuickAdd, edit: { editTask = $0 }, toggle: toggleTask)
                .tabItem { Label("Tasks", systemImage: "checklist") }.tag(1)
            GroceriesView(items: groceries, add: openQuickAdd)
                .tabItem { Label("Groceries", systemImage: "basket.fill") }.tag(2)
            HomeView(maintenance: maintenance, projects: projects, add: openQuickAdd)
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(3)
            SubscriptionsView(items: subscriptions, bills: bills, add: openQuickAdd)
                .tabItem { Label("Money", systemImage: "creditcard.fill") }.tag(4)
        }
        .tint(Color(red: 0.27, green: 0.42, blue: 0.35))
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        .sheet(isPresented: $quickAdd) { QuickAddView(initialType: quickAddType).id(quickAddGeneration) }
        .sheet(item: $editTask) { task in TaskEditor(task: task) }
        .task { seedIfNeeded() }
    }

    private func toggleTask(_ task: TaskItem) {
        task.isComplete.toggle(); task.completedAt = task.isComplete ? .now : nil
        if task.isComplete, let next = task.repeatRule.next(after: task.dueDate) {
            let occurrence = TaskItem(title: task.title, detail: task.detail, dueDate: next, priority: task.priority, category: task.category, repeatRule: task.repeatRule, reminderEnabled: task.reminderEnabled)
            context.insert(occurrence)
        }
        if task.reminderEnabled { NotificationService.cancel(id: task.persistentModelID.hashValue.description) }
    }

    private func openQuickAdd() {
        switch selectedTab {
        case 2: quickAddType = "Grocery item"
        case 3: quickAddType = "Maintenance"
        case 4: quickAddType = "Subscription"
        default: quickAddType = "Task"
        }
        quickAddGeneration += 1
        quickAdd = true
    }

    private func seedIfNeeded() {
        if !didSeedGroceries && groceries.isEmpty {
            [
                GroceryItem(name: "Milk", category: "Dairy & Eggs"),
                GroceryItem(name: "Eggs", category: "Dairy & Eggs"),
                GroceryItem(name: "Rice", category: "Pantry"),
                GroceryItem(name: "Bread", category: "Bakery"),
                GroceryItem(name: "Bananas", category: "Produce"),
                GroceryItem(name: "Coffee", category: "Pantry")
            ].forEach { context.insert($0) }
            didSeedGroceries = true
        }
        guard !didSeed else { return }; didSeed = true
        guard tasks.isEmpty && maintenance.isEmpty && projects.isEmpty && subscriptions.isEmpty && bills.isEmpty && groceries.isEmpty else { return }
        let cal = Calendar.current
        let samples = [
            TaskItem(title: "Buy groceries", dueDate: .now, category: "Shopping", reminderEnabled: false),
            TaskItem(title: "Pay water bill", dueDate: .now, priority: .high, category: "Finance"),
            TaskItem(title: "Clean garage", dueDate: cal.date(byAdding: .day, value: 1, to: .now) ?? .now, category: "Home"),
            TaskItem(title: "Call plumber", dueDate: cal.date(byAdding: .day, value: 2, to: .now) ?? .now, priority: .high, category: "Home"),
            TaskItem(title: "Take trash out", dueDate: .now, category: "Home", repeatRule: .weekly)
        ]
        samples.forEach { context.insert($0) }
        context.insert(HomeMaintenance(name: "Replace HVAC filter", area: "HVAC", nextDue: .now, frequency: .quarterly, lastCompleted: cal.date(byAdding: .month, value: -3, to: .now)))
        context.insert(HomeMaintenance(name: "Clean gutters", area: "Exterior", nextDue: cal.date(byAdding: .day, value: 4, to: .now) ?? .now, frequency: .quarterly))
        let project = HomeProject(name: "Garage organization", detail: "Make room for projects and tools", area: "Garage", targetDate: cal.date(byAdding: .day, value: 14, to: .now) ?? .now, estimatedCost: 450)
        context.insert(project)
        ["Measure wall", "Buy shelves", "Assemble shelves", "Sort tools", "Donate extras"].forEach { title in
            let part = ProjectTask(title: title, project: project); project.tasks.append(part); context.insert(part)
        }
        context.insert(HomeProject(name: "Living room painting", area: "Living Room", targetDate: cal.date(byAdding: .day, value: 30, to: .now) ?? .now, status: "Planned", estimatedCost: 700))
        context.insert(SubscriptionItem(name: "Netflix", cost: 22.99, nextDate: cal.date(byAdding: .day, value: 3, to: .now) ?? .now))
        context.insert(SubscriptionItem(name: "Spotify", category: "Music", cost: 11.99, nextDate: cal.date(byAdding: .day, value: 6, to: .now) ?? .now))
        context.insert(SubscriptionItem(name: "iCloud", category: "Software", cost: 2.99, nextDate: cal.date(byAdding: .day, value: 10, to: .now) ?? .now))
        context.insert(BillItem(name: "Internet", amount: 80, dueDate: cal.date(byAdding: .day, value: 3, to: .now) ?? .now))
        context.insert(BillItem(name: "Electricity", amount: 96.40, dueDate: cal.date(byAdding: .day, value: 7, to: .now) ?? .now))
        context.insert(BillItem(name: "Mortgage", amount: 3200, dueDate: cal.date(byAdding: .day, value: 12, to: .now) ?? .now))
    }
}

enum NotificationService {
    static func schedule(id: String, title: String, date: Date) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted, date > .now else { return }
            let name = UserDefaults.standard.string(forKey: "preferredName")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let content = UNMutableNotificationContent()
            content.title = name.isEmpty ? "Coming up" : "Hey \(name)! 👋"
            content.body = "\(title) is coming up."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
    static func cancel(id: String) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]) }
}
