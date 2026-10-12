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
    @State private var tabSwipeState = MainTabSwipeState()
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
                edit: { presentSheet(.task($0)) }, toggle: toggleTask
            )
            .tabItem { Label("Today", systemImage: "sun.max.fill") }.tag(0)
            GroceriesView(items: groceries, add: { openQuickAdd(defaultType: "Grocery item") })
                .tabItem { Label("Groceries", systemImage: "basket.fill") }.tag(1)
            HomeView(
                maintenance: maintenance, projects: projects,
                addMaintenance: { openQuickAdd(defaultType: "Maintenance") },
                addProject: { presentSheet(.newProject) },
                editProject: { presentSheet(.project($0)) },
                editMaintenance: { presentSheet(.maintenance($0)) }
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
        .background(MainTabSwipeObserver(
            allowsSwipe: { start, width in
                viewModel.selectedTab != 0 || start.x < 24 || start.x > width - 24
            },
            onSwipe: { direction in selectTab(viewModel.selectedTab + direction) },
            onActivity: { active in
                if active { tabSwipeState.isActive = true }
                else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { tabSwipeState.isActive = false } }
            }
        ))
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

    private func presentSheet(_ sheet: RootSheet) {
        guard !tabSwipeState.isActive else { return }
        activeSheet = sheet
    }

    private func selectTab(_ index: Int) {
        viewModel.selectTab(index)
    }

    private func toggleTask(_ task: TaskItem) {
        TaskRepository(context: context).toggleCompletion(for: task)
    }

    private func openQuickAdd(defaultType: String) {
        guard !tabSwipeState.isActive else { return }
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
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") && arguments.contains("-ui-testing-long-today"),
            !((try? context.fetch(FetchDescriptor<TaskItem>())) ?? []).contains(where: {
                $0.title.hasPrefix("Scroll fixture ")
            })
        {
            for index in 1...16 {
                context.insert(TaskItem(title: "Scroll fixture \(index)", dueDate: .now))
            }
        }
    }
}

@MainActor
private final class MainTabSwipeState { var isActive = false }

private struct MainTabSwipeObserver: UIViewRepresentable {
    var allowsSwipe: (CGPoint, CGFloat) -> Bool
    var onSwipe: (Int) -> Void
    var onActivity: (Bool) -> Void

    func makeUIView(context: Context) -> SwipeAnchor {
        SwipeAnchor()
    }
    func updateUIView(_ view: SwipeAnchor, context: Context) {
        view.allowsSwipe = allowsSwipe
        view.onSwipe = onSwipe
        view.onActivity = onActivity
    }

    final class SwipeAnchor: UIView, UIGestureRecognizerDelegate {
        var allowsSwipe: ((CGPoint, CGFloat) -> Bool)?
        var onSwipe: ((Int) -> Void)?
        var onActivity: ((Bool) -> Void)?
        private var pan: UIPanGestureRecognizer?
        private weak var observedWindow: UIWindow?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let pan { observedWindow?.removeGestureRecognizer(pan) }
            guard let window else { return }
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = true
            window.addGestureRecognizer(recognizer)
            pan = recognizer
            observedWindow = window
        }
        override func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let pan = gesture as? UIPanGestureRecognizer, let window,
                window.rootViewController?.presentedViewController == nil,
                !hasPushedNavigation(in: window.rootViewController)
            else { return false }
            let velocity = pan.velocity(in: window)
            let translation = pan.translation(in: window)
            let location = pan.location(in: window)
            let start = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
            let allowed = abs(velocity.x) > abs(velocity.y)
                && (allowsSwipe?(start, window.bounds.width) ?? false)
            if allowed { onActivity?(true) }
            return allowed
        }
        private func hasPushedNavigation(in controller: UIViewController?) -> Bool {
            guard let controller, controller.viewIfLoaded?.window != nil else { return false }
            if let navigation = controller as? UINavigationController,
                navigation.viewControllers.count > 1 { return true }
            return controller.children.contains { hasPushedNavigation(in: $0) }
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
        @objc private func dragged(_ recognizer: UIPanGestureRecognizer) {
            if recognizer.state == .cancelled || recognizer.state == .failed { onActivity?(false) }
            guard recognizer.state == .ended else { return }
            defer { onActivity?(false) }
            let translation = recognizer.translation(in: window)
            guard abs(translation.x) > 60, abs(translation.x) > abs(translation.y) else { return }
            onSwipe?(translation.x < 0 ? 1 : -1)
        }
    }
}
