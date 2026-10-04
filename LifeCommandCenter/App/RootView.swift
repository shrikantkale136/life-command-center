import SwiftUI
import SwiftData
import UserNotifications
import Observation
import Charts
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @Query(sort: \HomeMaintenance.nextDue) private var maintenance: [HomeMaintenance]
    @Query(sort: \HomeProject.targetDate) private var projects: [HomeProject]
    @Query(sort: \SubscriptionItem.nextDate) private var subscriptions: [SubscriptionItem]
    @Query(sort: \BillItem.dueDate) private var bills: [BillItem]
    @Query(sort: \GroceryItem.name) private var groceries: [GroceryItem]
    @State private var viewModel = RootViewModel()
    @State private var quickAdd = false
    @State private var quickAddType = "Task"
    @State private var editTask: TaskItem?
    @AppStorage("didSeedInitialData") private var didSeed = false
    @AppStorage("didSeedGroceryCatalog") private var didSeedGroceries = false
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("appAccentColor") private var appAccentColor = "Forest"
    @AppStorage("appFontSize") private var appFontSize = "Medium"

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            TodayView(tasks: tasks, maintenance: maintenance, projects: projects, subscriptions: subscriptions, bills: bills, add: { openQuickAdd(defaultType: "Task") }, openHome: { selectTab(2) }, openMoney: { selectTab(3) }, edit: { editTask = $0 }, toggle: toggleTask)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }.tag(0)
            GroceriesView(items: groceries, add: { openQuickAdd(defaultType: "Grocery item") })
                .tabItem { Label("Groceries", systemImage: "basket.fill") }.tag(1)
            HomeView(maintenance: maintenance, projects: projects, add: { openQuickAdd(defaultType: "Maintenance") })
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(2)
            SubscriptionsView(items: subscriptions, bills: bills, add: { openQuickAdd(defaultType: "Subscription") })
                .tabItem { Label("Money", systemImage: "creditcard.fill") }.tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(4)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height), abs(value.translation.width) > 70 else { return }
                    if value.translation.width < 0 { selectTab(min(viewModel.selectedTab + 1, 4)) }
                    else { selectTab(max(viewModel.selectedTab - 1, 0)) }
                }
        )
        .tint(AppAccentColor.color(named: appAccentColor))
        .environment(\.dynamicTypeSize, AppFontSize.dynamicTypeSize(for: appFontSize))
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        .sheet(isPresented: $quickAdd) { QuickAddView(type: $quickAddType) }
        .sheet(item: $editTask) { task in TaskEditor(task: task) }
        .task { seedIfNeeded() }
    }

    private func selectTab(_ index: Int) {
        viewModel.selectTab(index)
    }

    private func toggleTask(_ task: TaskItem) {
        TaskRepository(context: context).toggleCompletion(for: task)
    }

    private func openQuickAdd(defaultType: String) {
        quickAddType = defaultType
        quickAdd = true
    }

    private func seedIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            didSeed = false
            didSeedGroceries = false
        }
        let repository = SampleDataRepository(context: context)
        repository.seedGroceryCatalogIfNeeded(hasSeeded: didSeedGroceries, isEmpty: groceries.isEmpty) { didSeedGroceries = true }
        repository.seedSampleDataIfNeeded(
            hasSeeded: didSeed,
            isEmpty: tasks.isEmpty && maintenance.isEmpty && projects.isEmpty && subscriptions.isEmpty && bills.isEmpty
        ) { didSeed = true }
    }
}
