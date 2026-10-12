import Charts
import Observation
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

private enum RootSheet: Identifiable {
    case quickAdd
    case task(TaskItem)
    case project(HomeProject)
    case newProject
    case maintenance(HomeMaintenance)

    var id: String {
        switch self {
        case .quickAdd: "quick-add"
        case .task(let task): "task-\(task.persistentModelID)"
        case .project(let project): "project-\(project.persistentModelID)"
        case .newProject: "new-project"
        case .maintenance(let item): "maintenance-\(item.persistentModelID)"
        }
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
    @State private var viewModel = RootViewModel()
    @State private var activeSheet: RootSheet?
    @State private var quickAddType = "Task"
    @AppStorage("didSeedInitialData") private var didSeed = false
    @AppStorage("didSeedGroceryCatalog") private var didSeedGroceries = false
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("appAccentColor") private var appAccentColor = "Forest"
    @AppStorage("appFontSize") private var appFontSize = "Medium"

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            TodayView(
                tasks: tasks, maintenance: maintenance, projects: projects,
                subscriptions: subscriptions,
                bills: bills, add: { openQuickAdd(defaultType: "Task") },
                edit: { activeSheet = .task($0) }, toggle: toggleTask
            )
            .tabItem { Label("Today", systemImage: "sun.max.fill") }.tag(0)
            GroceriesView(items: groceries, add: { openQuickAdd(defaultType: "Grocery item") })
                .tabItem { Label("Groceries", systemImage: "basket.fill") }.tag(1)
            HomeView(
                maintenance: maintenance, projects: projects,
                addMaintenance: { openQuickAdd(defaultType: "Maintenance") },
                addProject: { activeSheet = .newProject },
                editProject: { activeSheet = .project($0) },
                editMaintenance: { activeSheet = .maintenance($0) }
            )
            .tabItem { Label("Home", systemImage: "house.fill") }.tag(2)
            SubscriptionsView(
                items: subscriptions, bills: bills,
                add: { openQuickAdd(defaultType: "Subscription") }
            )
            .tabItem { Label("Money", systemImage: "creditcard.fill") }.tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(4)
        }
        .tint(AppAccentColor.color(named: appAccentColor))
        .environment(\.dynamicTypeSize, AppFontSize.dynamicTypeSize(for: appFontSize))
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .quickAdd: QuickAddView(type: $quickAddType)
            case .task(let task): TaskEditor(task: task)
            case .project(let project): ProjectEditor(project: project)
            case .newProject: ProjectEditor()
            case .maintenance(let item): MaintenanceEditor(item: item)
            }
        }
        .task {
            seedIfNeeded()
            if !ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                NotificationService.syncMaintenance(in: context)
            }
        }
    }

    private func selectTab(_ index: Int) {
        viewModel.selectTab(index)
    }

    private func toggleTask(_ task: TaskItem) {
        TaskRepository(context: context).toggleCompletion(for: task)
    }

    private func openQuickAdd(defaultType: String) {
        quickAddType = defaultType
        activeSheet = .quickAdd
    }

    private func seedIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            didSeed = false
            didSeedGroceries = false
        }
        let repository = SampleDataRepository(context: context)
        repository.seedGroceryCatalogIfNeeded(
            hasSeeded: didSeedGroceries, isEmpty: groceries.isEmpty
        ) {
            didSeedGroceries = true
        }
        repository.seedSampleDataIfNeeded(
            hasSeeded: didSeed,
            isEmpty: tasks.isEmpty && maintenance.isEmpty && projects.isEmpty
                && subscriptions.isEmpty
                && bills.isEmpty
        ) { didSeed = true }
    }
}
