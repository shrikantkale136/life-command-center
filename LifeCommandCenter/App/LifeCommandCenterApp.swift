import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

@main
struct LifeCommandCenterApp: App {
    let container: ModelContainer = {
        let schema = Schema([TaskItem.self, HomeMaintenance.self, HomeProject.self, ProjectTask.self, SubscriptionItem.self, BillItem.self, GroceryItem.self])
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            RootView().modelContainer(container)
        }
    }
}
