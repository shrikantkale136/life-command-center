import XCTest
import SwiftData
@testable import LifeCommandCenter

@MainActor
final class PersistenceTests: XCTestCase {
    func testModelsPersistAcrossContainerRecreation() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HomeManager-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(atPath: url.path + "-shm"); try? FileManager.default.removeItem(atPath: url.path + "-wal") }
        let schema = Schema([TaskItem.self, HomeMaintenance.self, HomeProject.self, ProjectTask.self, SubscriptionItem.self, BillItem.self, GroceryItem.self])
        let configuration = ModelConfiguration("TestStore", schema: schema, url: url)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let task = TaskItem(title: "Persist me")
            let project = HomeProject(name: "Kitchen")
            let step = ProjectTask(title: "Choose faucet", project: project)
            project.tasks.append(step)
            container.mainContext.insert(task)
            container.mainContext.insert(project)
            container.mainContext.insert(step)
            container.mainContext.insert(SubscriptionItem(name: "Music", cost: 10))
            container.mainContext.insert(BillItem(name: "Water", amount: 40))
            try container.mainContext.save()
        }
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<TaskItem>()).map(\.title), ["Persist me"])
        let projects = try reopened.mainContext.fetch(FetchDescriptor<HomeProject>())
        XCTAssertEqual(projects.first?.tasks.map(\.title), ["Choose faucet"])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<SubscriptionItem>()).count, 1)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<BillItem>()).count, 1)
    }
}
