import XCTest
import SwiftData
@testable import LifeCommandCenter

@MainActor
final class RepositoryTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([TaskItem.self, HomeMaintenance.self, HomeProject.self, ProjectTask.self, SubscriptionItem.self, BillItem.self, GroceryItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    func testCompletingRecurringTaskCreatesNextAndSchedulesNotification() throws {
        let context = try makeContext()
        let dueDate = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        let task = TaskItem(title: "Filter", dueDate: dueDate, repeatRule: .quarterly, reminderEnabled: true)
        context.insert(task)
        var scheduled: [(String, String, Date)] = []
        var cancelled: [String] = []
        let repository = TaskRepository(context: context, scheduleNotification: { scheduled.append(($0, $1, $2)) }, cancelNotification: { cancelled.append($0) })

        repository.toggleCompletion(for: task)

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(task.isComplete)
        XCTAssertNotNil(task.completedAt)
        XCTAssertEqual(cancelled.count, 1)
        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(scheduled[0].1, "Filter")
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day], from: scheduled[0].2), Calendar.current.dateComponents([.year, .month, .day], from: Calendar.current.date(byAdding: .month, value: 3, to: dueDate)!))
        XCTAssertEqual(tasks.first(where: { !$0.isComplete })?.repeatRule, .quarterly)
    }

    func testCompletingNonRepeatingTaskDoesNotCreateOccurrence() throws {
        let context = try makeContext()
        let task = TaskItem(title: "One-off")
        context.insert(task)
        TaskRepository(context: context).toggleCompletion(for: task)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).count, 1)
        XCTAssertTrue(task.isComplete)
    }

    func testReopeningTaskClearsCompletionAndRestoresReminder() throws {
        let context = try makeContext()
        let task = TaskItem(title: "Pay bill", dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)!, reminderEnabled: true)
        task.isComplete = true
        task.completedAt = .now
        context.insert(task)
        var scheduled = 0
        let repository = TaskRepository(context: context, scheduleNotification: { _, _, _ in scheduled += 1 }, cancelNotification: { _ in })
        repository.toggleCompletion(for: task)
        XCTAssertFalse(task.isComplete)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(scheduled, 1)
    }

    func testSampleSeedingPopulatesCoreModelsAndIsIdempotent() throws {
        let context = try makeContext()
        let repository = SampleDataRepository(context: context)
        var marked = false
        repository.seedSampleDataIfNeeded(hasSeeded: false, isEmpty: true) { marked = true }
        XCTAssertTrue(marked)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).count, 5)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HomeMaintenance>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HomeProject>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SubscriptionItem>()).count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BillItem>()).count, 3)
        repository.seedSampleDataIfNeeded(hasSeeded: true, isEmpty: true) { XCTFail("must not reseed") }
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).count, 5)
    }

    func testSampleSeedingDoesNotOverwriteExistingUserData() throws {
        let context = try makeContext()
        context.insert(TaskItem(title: "My task"))
        var marked = false
        SampleDataRepository(context: context).seedSampleDataIfNeeded(hasSeeded: false, isEmpty: false) { marked = true }
        XCTAssertTrue(marked)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).map(\.title), ["My task"])
    }

    func testGroceryCatalogSeedsOnlyOnceWhenEmpty() throws {
        let context = try makeContext()
        let repository = SampleDataRepository(context: context)
        var marked = false
        repository.seedGroceryCatalogIfNeeded(hasSeeded: false, isEmpty: true) { marked = true }
        XCTAssertTrue(marked)
        XCTAssertEqual(try context.fetch(FetchDescriptor<GroceryItem>()).count, 6)
        repository.seedGroceryCatalogIfNeeded(hasSeeded: true, isEmpty: true) { XCTFail("must not reseed") }
        XCTAssertEqual(try context.fetch(FetchDescriptor<GroceryItem>()).count, 6)
    }
}
