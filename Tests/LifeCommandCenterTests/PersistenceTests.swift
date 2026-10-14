import XCTest
import SwiftData
import UIKit
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

    func testMaintenanceCreateAndEditRoundTripTheSameScheduleAndServiceFields() throws {
        let container = try ModelContainer(for: HomeMaintenance.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var draft = MaintenanceDraft()
        draft.name = "Filter"
        draft.detail = "HEPA"
        draft.provider = "Service team"
        draft.notes = "Size 20x20"
        draft.cost = "25.50"
        draft.timeEnabled = true
        draft.timeZoneEnabled = true
        draft.timeZoneID = "America/New_York"
        draft.frequency = .biweekly
        draft.endsRepeat = true
        draft.repeatEndDate = Calendar.current.date(byAdding: .month, value: 6, to: draft.nextDue)!
        let item = try draft.save(in: container.mainContext)
        let reopened = MaintenanceDraft(item: item)
        XCTAssertEqual(reopened.detail, draft.detail)
        XCTAssertEqual(reopened.provider, draft.provider)
        XCTAssertEqual(reopened.notes, draft.notes)
        XCTAssertEqual(ProjectDraft.amount(reopened.cost), ProjectDraft.amount(draft.cost))
        XCTAssertTrue(reopened.timeEnabled)
        XCTAssertTrue(reopened.timeZoneEnabled)
        XCTAssertEqual(reopened.timeZoneID, draft.timeZoneID)
        XCTAssertEqual(reopened.frequency, .biweekly)
        XCTAssertTrue(reopened.endsRepeat)
        XCTAssertEqual(reopened.repeatEndDate, draft.repeatEndDate)
        var edited = reopened
        edited.endsRepeat = false
        edited.dateEnabled = false
        edited.timeEnabled = false
        edited.reminderEnabled = true
        _ = try edited.save(in: container.mainContext, item: item)
        XCTAssertNil(item.repeatEndDate)
        XCTAssertFalse(item.dateEnabled)
        XCTAssertFalse(MaintenanceDraft(item: item).timeEnabled)
    }

    func testProjectDraftSavesChecklistAndShoppingEditsAcrossReopening() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Project-\(UUID().uuidString).store")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(atPath: url.path + "-shm")
            try? FileManager.default.removeItem(atPath: url.path + "-wal")
        }
        let schema = Schema([HomeProject.self, ProjectTask.self, ProjectShoppingItem.self])
        let configuration = ModelConfiguration("ProjectTest", schema: schema, url: url)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            var draft = ProjectDraft()
            draft.name = "Garage"
            draft.tasks = [ProjectTaskDraft(title: "Measure"), ProjectTaskDraft(title: "Install")]
            draft.shoppingItems = [ProjectShoppingDraft(name: "Shelves", quantity: 2, unitCost: "50")]
            let project = try draft.save(in: container.mainContext)
            XCTAssertEqual(project.tasks.count, 2)
            XCTAssertEqual(project.shoppingItems.count, 1)
            var cancelled = ProjectDraft(project: project)
            cancelled.name = "Do not save"
            cancelled.tasks[0].isComplete = true
            cancelled.shoppingItems[0].quantity = 9
            XCTAssertEqual(project.name, "Garage")
            XCTAssertEqual(project.progress, 0)
            XCTAssertEqual(project.shoppingEstimate, 100)

            var edited = ProjectDraft(project: project)
            edited.name = "Updated garage"
            edited.tasks.removeFirst()
            edited.tasks[0].title = "Install shelves"
            edited.tasks[0].isComplete = true
            edited.shoppingItems.removeAll()
            edited.shoppingItems.append(ProjectShoppingDraft(name: "Brackets", quantity: 4, unitCost: "10", isPurchased: true))
            _ = try edited.save(in: container.mainContext, project: project)
            XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<ProjectTask>()).count, 1)
            XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<ProjectShoppingItem>()).count, 1)
        }
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let project = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<HomeProject>()).first)
        XCTAssertEqual(project.name, "Updated garage")
        XCTAssertEqual(project.orderedTasks.map(\.title), ["Install shelves"])
        XCTAssertEqual(project.progress, 1)
        XCTAssertFalse(project.isComplete)
        XCTAssertEqual(project.displayStatus, "In Progress")
        XCTAssertEqual(project.shoppingEstimate, 40)
        XCTAssertTrue(try XCTUnwrap(project.shoppingItems.first).isPurchased)
        reopened.mainContext.delete(project)
        try reopened.mainContext.save()
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<ProjectTask>()).count, 0)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<ProjectShoppingItem>()).count, 0)
    }
    func testMaintenanceDraftSavesAllFieldsAndCancelLeavesOriginal() throws {
        let container = try ModelContainer(for: HomeMaintenance.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let item = HomeMaintenance(name: "Filter", lastCompleted: .now)
        context.insert(item)
        try context.save()
        var draft = MaintenanceDraft(item: item)
        draft.name = "Updated filter"
        draft.area = "Utility room"
        draft.detail = "Use a HEPA filter"
        draft.nextDue = Date(timeIntervalSince1970: 2_000_000_000)
        draft.frequency = .monthly
        draft.cost = "25.50"
        draft.provider = "Local service"
        draft.notes = "Size 20x20"
        XCTAssertEqual(item.name, "Filter")
        XCTAssertEqual(item.cost, 0)
        XCTAssertTrue(draft.canSave)
        try draft.save(in: context, item: item)
        XCTAssertEqual(item.name, "Updated filter")
        XCTAssertEqual(item.area, "Utility room")
        XCTAssertEqual(item.detail, "Use a HEPA filter")
        XCTAssertEqual(item.nextDue, draft.nextDue)
        XCTAssertEqual(item.frequencyRaw, "Monthly")
        XCTAssertEqual(item.cost, 25.50)
        XCTAssertEqual(item.provider, "Local service")
        XCTAssertEqual(item.notes, "Size 20x20")
        XCTAssertNotNil(item.lastCompleted)
        draft.cost = "-1"
        XCTAssertFalse(draft.canSave)
        draft.cost = "0"
        draft.name = " "
        XCTAssertFalse(draft.canSave)
    }

    func testCompletedProjectListsStayLockedUntilStatusChanges() throws {
        let container = try ModelContainer(for: HomeProject.self, ProjectTask.self, ProjectShoppingItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        var initial = ProjectDraft()
        initial.name = "Shelves"
        initial.tasks = [ProjectTaskDraft(title: "Install")]
        initial.shoppingItems = [ProjectShoppingDraft(name: "Bracket", unitCost: "25")]
        let project = try initial.save(in: context)
        project.status = "Completed"
        try context.save()
        var edited = ProjectDraft(project: project)
        edited.tasks[0].title = "Changed task"
        edited.tasks[0].isComplete = true
        edited.shoppingItems[0].quantity = 3
        edited.shoppingItems[0].isPurchased = true
        _ = try edited.save(in: context, project: project)
        XCTAssertEqual(project.status, "Completed")
        XCTAssertEqual(project.tasks.first?.title, "Install")
        XCTAssertEqual(project.tasks.first?.isComplete, false)
        XCTAssertEqual(project.shoppingEstimate, 25)
        XCTAssertEqual(project.shoppingItems.first?.isPurchased, false)
        for status in ["In Progress", "On Hold", "Planned"] {
            project.status = status
            _ = try edited.save(in: context, project: project)
            XCTAssertEqual(project.status, status)
            XCTAssertEqual(project.tasks.first?.title, "Changed task")
            XCTAssertEqual(project.tasks.first?.isComplete, true)
            XCTAssertEqual(project.shoppingEstimate, 75)
            XCTAssertEqual(project.shoppingItems.first?.isPurchased, true)
            XCTAssertFalse(project.isComplete)
        }
    }

}

@MainActor
final class VisitingCardTests: XCTestCase {
    private func makeImage() -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 700)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 700))
            let text = "Alex Morgan\nSenior Designer\nExample Studio\nalex@example.com\n+1 (415) 555-0123\nwww.example.com"
            (text as NSString).draw(in: CGRect(x: 60, y: 60, width: 1080, height: 600), withAttributes: [
                .font: UIFont.systemFont(ofSize: 48), .foregroundColor: UIColor.black,
            ])
        }
        return image.pngData()!
    }
    func testExtractionAndDuplicateSuggestions() {
        let fields = CardFieldExtractor.extract("Alex Morgan\nSenior Designer\nExample Studio\nalex@example.com\n+1 (415) 555-0123\nhttps://example.com")
        XCTAssertEqual(fields.name, "Alex Morgan")
        XCTAssertEqual(fields.company, "Example Studio")
        XCTAssertEqual(fields.jobTitle, "Senior Designer")
        XCTAssertEqual(fields.emails, ["alex@example.com"])
        XCTAssertEqual(CardFieldExtractor.normalizedPhone(fields.phones.first ?? ""), "14155550123")
        XCTAssertEqual(fields.website, "https://example.com")
        let card = VisitingCard(name: "Alex")
        card.phones = ["+1 415 555 0123"]; card.emails = ["ALEX@example.com"]
        var draft = VisitingCardDraft()
        draft.phones = [CardContactValue("+1 (415) 555-0123")]
        XCTAssertEqual(draft.duplicates(in: [card], excluding: nil).count, 1)
        XCTAssertTrue(draft.duplicates(in: [card], excluding: card.id).isEmpty)
        draft.phones = []; draft.emails = [CardContactValue("alex@example.com")]
        XCTAssertEqual(draft.duplicates(in: [card], excluding: nil).count, 1)
        draft.emails = [CardContactValue("different@example.com")]
        XCTAssertTrue(draft.duplicates(in: [card], excluding: nil).isEmpty)
    }
    func testRecognitionPreservesEditsMadeWhileProcessing() {
        let snapshot = VisitingCardDraft()
        var draft = snapshot
        draft.name = "Corrected name"; draft.notes = "Keep these notes"; draft.tags = "Friend"
        let fields = CardExtractedFields(name: "OCR name", company: "Example Studio", jobTitle: "Designer", phones: ["4155550123"], emails: ["alex@example.com"], website: "https://example.com", address: "123 Main St")
        draft.apply(fields, preservingEditsSince: snapshot)
        XCTAssertEqual(draft.name, "Corrected name")
        XCTAssertEqual(draft.company, "Example Studio")
        XCTAssertEqual(draft.phoneValues, ["4155550123"])
        XCTAssertEqual(draft.notes, "Keep these notes")
        XCTAssertEqual(draft.tags, "Friend")
    }

    func testOnDeviceRecognitionOfCardImage() async throws {
        let texts = try await VisitingCardOCR.recognize([makeImage()])
        XCTAssertEqual(texts.count, 1)
        XCTAssertTrue(texts[0].contains("Alex Morgan"))
        XCTAssertTrue(texts[0].contains("alex@example.com"))
        XCTAssertEqual(CardFieldExtractor.extract(texts[0]).company, "Example Studio")
    }
    func testImageAndMetadataPersistenceReplacementAndDeletion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let images = VisitingCardImageStore(directory: root.appendingPathComponent("images"))
        let schema = Schema([VisitingCard.self])
        let configuration = ModelConfiguration(schema: schema, url: root.appendingPathComponent("cards.store"))
        var originalFiles: [String] = []
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let repository = VisitingCardRepository(context: container.mainContext, images: images)
            var draft = VisitingCardDraft()
            XCTAssertFalse(draft.canSave)
            draft.frontData = makeImage()
            XCTAssertTrue(draft.canSave)
            let card = try repository.save(draft)
            XCTAssertEqual(card.displayName, "Untitled card")
            XCTAssertEqual(card.imageFiles.count, 2)
            originalFiles = card.imageFiles
            XCTAssertNotNil(images.data(for: card.frontImage))
            XCTAssertNotNil(images.data(for: card.frontThumbnail))
        }
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let card = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<VisitingCard>()).first)
        XCTAssertNotNil(images.data(for: card.frontImage))
        let repository = VisitingCardRepository(context: reopened.mainContext, images: images)
        var draft = VisitingCardDraft(card: card, images: images)
        draft.name = "Alex"; draft.tags = "Design, design, Friend"; draft.notes = "Met at an event"
        draft.phones = [CardContactValue("4155550123")]
        draft.backData = makeImage()
        _ = try repository.save(draft, card: card)
        XCTAssertEqual(card.tags, ["Design", "Friend"])
        XCTAssertEqual(card.phones, ["4155550123"])
        XCTAssertEqual(card.imageFiles.count, 4)
        XCTAssertTrue(originalFiles.allSatisfy { images.data(for: $0) == nil })
        let validFiles = card.imageFiles
        draft.backData = Data("invalid image".utf8); draft.name = "Unsaved"
        XCTAssertThrowsError(try repository.save(draft, card: card))
        XCTAssertEqual(card.name, "Alex")
        XCTAssertEqual(card.imageFiles, validFiles)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: images.directory.path).count, 4)
        try Data("orphan".utf8).write(to: images.directory.appendingPathComponent("orphan.jpg"))
        try repository.removeOrphanedImages()
        XCTAssertNil(images.data(for: "orphan.jpg"))
        XCTAssertTrue(validFiles.allSatisfy { images.data(for: $0) != nil })
        try repository.delete(card)
        XCTAssertTrue(try reopened.mainContext.fetch(FetchDescriptor<VisitingCard>()).isEmpty)
        XCTAssertTrue(validFiles.allSatisfy { images.data(for: $0) == nil })
    }
    func testFailedNewSaveCleansUpImagesAndDraftDoesNotMutateModel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try ModelContainer(for: VisitingCard.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let images = VisitingCardImageStore(directory: root)
        let repository = VisitingCardRepository(context: container.mainContext, images: images)
        var draft = VisitingCardDraft(); draft.frontData = makeImage(); draft.backData = Data()
        XCTAssertThrowsError(try repository.save(draft))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<VisitingCard>()).isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        let card = VisitingCard(name: "Original"); container.mainContext.insert(card)
        var edit = VisitingCardDraft(card: card); edit.name = "Unsaved edit"
        XCTAssertEqual(card.name, "Original")
        XCTAssertNil(images.data(for: "../cards.store"))
    }
    func testAddingCardSchemaPreservesExistingTasks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("existing.store")
        let oldSchema = Schema([TaskItem.self, HomeMaintenance.self, HomeProject.self, ProjectTask.self, SubscriptionItem.self, BillItem.self, GroceryItem.self])
        do {
            let container = try ModelContainer(for: oldSchema, configurations: ModelConfiguration(schema: oldSchema, url: url))
            container.mainContext.insert(TaskItem(title: "Keep existing task"))
            try container.mainContext.save()
        }
        let newSchema = Schema([TaskItem.self, HomeMaintenance.self, HomeProject.self, ProjectTask.self, SubscriptionItem.self, BillItem.self, GroceryItem.self, VisitingCard.self])
        let reopened = try ModelContainer(for: newSchema, configurations: ModelConfiguration(schema: newSchema, url: url))
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<TaskItem>()).first?.title, "Keep existing task")
        XCTAssertTrue(try reopened.mainContext.fetch(FetchDescriptor<VisitingCard>()).isEmpty)
    }
}
