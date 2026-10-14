import XCTest
import Observation
import SwiftData
import UIKit
import UserNotifications
@testable import LifeCommandCenter

@MainActor
final class SettingsFeatureTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var prefs: AppPreferences!
    private var directory: URL!
    override func setUp() {
        suite = "SettingsFeatureTests-" + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
        prefs = AppPreferences(defaults: defaults, domainName: suite)
        prefs.register()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
    private func container() throws -> ModelContainer {
        try ModelContainer(for: TaskItem.self, HomeMaintenance.self, HomeProject.self, ProjectTask.self,
            ProjectShoppingItem.self, SubscriptionItem.self, BillItem.self, GroceryItem.self, VisitingCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private func service() -> BackupService {
        BackupService(preferences: prefs, images: VisitingCardImageStore(directory: directory.appendingPathComponent("Images")),
                      journalURL: directory.appendingPathComponent("Recovery.json"))
    }
    func testExistingFontSizeIsPreservedAndNewUsersFollowSystem() {
        XCTAssertTrue(defaults.bool(forKey: "followSystemTextSize"))
        defaults.removePersistentDomain(forName: suite)
        defaults.set("Large", forKey: "appFontSize")
        // Remove registration defaults as well to emulate a pre-upgrade installation.
        let legacy = UserDefaults(suiteName: suite + "-legacy")!
        defer { legacy.removePersistentDomain(forName: suite + "-legacy") }
        legacy.set("Large", forKey: "appFontSize")
        AppPreferences(defaults: legacy, domainName: suite + "-legacy").register()
        XCTAssertFalse(legacy.bool(forKey: "followSystemTextSize"))
        XCTAssertEqual(legacy.string(forKey: "appFontSize"), "Large")
    }
    func testResetPreservesProfileSecurityAndHistoryAndResetsPortableDefaults() throws {
        defaults.set("Alex", forKey: "preferredName")
        defaults.set(true, forKey: "appLockEnabled")
        defaults.set(123.0, forKey: "lastBackupExport")
        defaults.set(true, forKey: "didSeedInitialData")
        defaults.set("Money", forKey: "startPage")
        defaults.set("Urgent", forKey: "defaultPriority")
        defaults.set("Work", forKey: "defaultCategory")
        prefs.reset()
        XCTAssertEqual(prefs.startPage, .today)
        XCTAssertEqual(prefs.priority, .medium)
        XCTAssertEqual(prefs.category, "Personal")
        XCTAssertEqual(defaults.string(forKey: "preferredName"), "Alex")
        XCTAssertTrue(prefs.lockEnabled)
        XCTAssertEqual(defaults.double(forKey: "lastBackupExport"), 123)
        XCTAssertTrue(defaults.bool(forKey: "didSeedInitialData"))
        let portable = prefs.portable()
        XCTAssertNil(portable["appLockEnabled"])
        XCTAssertNil(portable["lastBackupExport"])
        XCTAssertNil(portable["didSeedInitialData"])
        try AppPreferences.validate(portable)
    }
    func testQuietHoursAreSilentAcrossMidnightAndRespectBoundary() throws {
        defaults.set(true, forKey: "quietHoursEnabled")
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2030, month: 1, day: 1, hour: hour, minute: minute))!
        }
        XCTAssertFalse(prefs.soundEnabled(at: date(22), calendar: calendar))
        XCTAssertFalse(prefs.soundEnabled(at: date(1), calendar: calendar))
        XCTAssertFalse(prefs.soundEnabled(at: date(6, 59), calendar: calendar))
        XCTAssertTrue(prefs.soundEnabled(at: date(7), calendar: calendar))
        XCTAssertTrue(prefs.soundEnabled(at: date(21, 59), calendar: calendar))
        let request = try XCTUnwrap(NotificationService.makeRequest(id: "test", title: "Task", date: date(1), calendar: calendar, preferences: prefs))
        // Quiet hours use the device's local time zone even for a zoned reminder.
        XCTAssertEqual(request.content.sound != nil, prefs.soundEnabled(at: date(1)))
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 1)
        defaults.set(false, forKey: "notificationSound")
        XCTAssertFalse(prefs.soundEnabled(at: date(12), calendar: calendar))
        var values = prefs.portable(); values["quietHoursStart"] = .number(420)
        XCTAssertThrowsError(try AppPreferences.validate(values))
    }
    func testNewDefaultsAndStartPageMapping() {
        defaults.set("High", forKey: "defaultPriority")
        defaults.set("Work", forKey: "defaultCategory")
        defaults.set(true, forKey: "defaultTaskReminders")
        defaults.set("Money", forKey: "startPage")
        XCTAssertEqual(prefs.priority, .high)
        XCTAssertEqual(prefs.category, "Work")
        XCTAssertTrue(prefs.taskReminders)
        XCTAssertEqual(RootViewModel(startPage: prefs.startPage).selectedTab, 3)
        XCTAssertEqual(prefs.openingDuration, 2.5)
    }
    func testThemeChangesNotifyExistingViewsForPresetsAndRepeatedCustomSelections() {
        final class ChangeFlag: @unchecked Sendable { var changed = false }
        let theme = AppTheme(defaults: defaults)
        let flag = ChangeFlag()
        withObservationTracking { _ = theme.color } onChange: { flag.changed = true }
        theme.select(name: "Custom", hex: "#1A73E8")
        XCTAssertTrue(flag.changed)
        XCTAssertEqual(AppPalette.hex(color: theme.color), "#1A73E8")
        flag.changed = false
        withObservationTracking { _ = theme.color } onChange: { flag.changed = true }
        theme.select(name: "Custom", hex: "#E34F4F")
        XCTAssertTrue(flag.changed, "Changing a custom color again must invalidate existing views too")
        XCTAssertEqual(AppPalette.hex(color: theme.color), "#E34F4F")
        flag.changed = false
        withObservationTracking { _ = theme.color } onChange: { flag.changed = true }
        theme.select(name: "Teal")
        XCTAssertTrue(flag.changed)
        XCTAssertEqual(defaults.string(forKey: "appAccentColor"), "Teal")
        flag.changed = false
        withObservationTracking { _ = theme.color } onChange: { flag.changed = true }
        theme.refresh()
        theme.select(name: "Teal")
        XCTAssertFalse(flag.changed, "Unchanged preference notifications must not cause a view-refresh loop")
    }

    func testCustomPaletteAndPersonalizedReminderPreferences() throws {
        var values = prefs.portable()
        values["appAccentColor"] = .string("Custom")
        values["customAccentHex"] = .string("#1A73E8")
        values["personalizedGreetings"] = .bool(false)
        values["personalizedReminders"] = .bool(false)
        try AppPreferences.validate(values)
        prefs.apply(values)
        XCTAssertFalse(prefs.personalizedGreetings)
        XCTAssertFalse(prefs.personalizedReminders)
        let request = try XCTUnwrap(NotificationService.makeRequest(id: "personal", title: "Task", date: .now.addingTimeInterval(3600), preferredName: "Alex", preferences: prefs))
        XCTAssertEqual(request.content.title, "Coming up")
        XCTAssertFalse(AppGreeting.text(name: "Alex", personalized: false).contains("Alex"))
        XCTAssertTrue(AppGreeting.text(name: "Alex", personalized: true).contains("Alex"))
        values["customAccentHex"] = .string("#invalid")
        XCTAssertThrowsError(try AppPreferences.validate(values))
        prefs.reset()
        XCTAssertEqual(defaults.string(forKey: "appAccentColor"), "Forest")
    }

    func testCustomPaletteLifecyclePersistenceAndResetPreservation() throws {
        let library = ColorPaletteStore(defaults: defaults)
        let id = try library.savePalette(name: "Weekend")
        let color = try library.saveColor(name: "Ocean", hex: "#1a73e8", paletteID: id)
        let duplicate = try library.saveColor(name: "Same shade", hex: "#1A73E8", paletteID: id)
        XCTAssertEqual(color.id, duplicate.id)
        XCTAssertEqual(library.palettes.first(where: { $0.id == id })?.colors.count, 1)
        try library.savePalette(name: "Favorites", id: id)
        XCTAssertThrowsError(try library.savePalette(name: "favorites"))
        let edited = try library.saveColor(name: "Evening blue", hex: "#5F73D9", paletteID: id, colorID: color.id)
        XCTAssertEqual(edited.id, color.id)
        XCTAssertEqual(ColorPaletteStore(defaults: defaults).palettes, library.palettes)
        let beforeReset = defaults.string(forKey: ColorPaletteStore.preferenceKey)
        prefs.reset()
        XCTAssertEqual(defaults.string(forKey: ColorPaletteStore.preferenceKey), beforeReset)
        let theme = AppTheme(defaults: defaults)
        theme.select(name: "Custom", hex: edited.hex)
        try library.deleteColor(id: edited.id, paletteID: id)
        XCTAssertEqual(theme.customHex, edited.hex, "Removing a saved swatch must not change the applied color")
        try library.deletePalette(id: id)
        XCTAssertEqual(library.palettes.count, 1)
        try library.deletePalette(id: ColorPaletteStore.defaultID)
        XCTAssertEqual(library.palettes.count, 1)
    }

    func testNamelessColorsFlattenDeduplicateAndPersist() throws {
        let library = ColorPaletteStore(defaults: defaults)
        let oldPalette = try library.savePalette(name: "Old palette")
        let oldColor = try library.saveColor(name: "Old color", hex: "#123456", paletteID: oldPalette)
        XCTAssertEqual(try library.saveCustomColor(hex: "#123456").id, oldColor.id)
        let newColor = try library.saveCustomColor(hex: "#abcdef")
        XCTAssertEqual(try library.saveCustomColor(hex: "#ABCDEF").id, newColor.id)
        XCTAssertEqual(library.savedColors.map(\.hex), ["#ABCDEF", "#123456"])
        XCTAssertEqual(ColorPaletteStore(defaults: defaults).savedColors, library.savedColors)
        try library.removeCustomColor(hex: "#123456")
        XCTAssertEqual(library.savedColors.map(\.hex), ["#ABCDEF"])
    }

    func testPaletteMigrationAndPortableBackupValidation() throws {
        defaults.set("#A1B2C3", forKey: "customAccentHex")
        defaults.set("Custom", forKey: "appAccentColor")
        let library = ColorPaletteStore(defaults: defaults)
        XCTAssertEqual(library.palettes[0].colors.map(\.hex), ["#A1B2C3"])
        XCTAssertEqual(ColorPaletteStore(defaults: defaults).palettes[0].colors.count, 1)
        let id = try library.savePalette(name: "Work")
        try library.saveColor(name: "Ink", hex: "#123456", paletteID: id)
        let portable = prefs.portable()
        try AppPreferences.validate(portable)
        let otherName = suite + "-restore"
        let other = UserDefaults(suiteName: otherName)!
        defer { other.removePersistentDomain(forName: otherName) }
        AppPreferences(defaults: other, domainName: otherName).apply(portable)
        XCTAssertEqual(ColorPaletteStore(defaults: other).palettes, library.palettes)
        var bad = portable; bad[ColorPaletteStore.preferenceKey] = .string("not json")
        XCTAssertThrowsError(try AppPreferences.validate(bad))
        var duplicate = library.palettes
        duplicate[1].colors.append(duplicate[1].colors[0])
        XCTAssertThrowsError(try ColorPaletteStore.decode(String(decoding: JSONEncoder().encode(duplicate), as: UTF8.self)))
    }

    func testEncryptionRejectsWrongPasswordTamperingAndUnsupportedVersion() throws {
        let source = Data("private records".utf8)
        let encrypted = try BackupCrypto.encrypt(source, password: "strong-password-123")
        XCTAssertEqual(try BackupCrypto.decrypt(encrypted, password: "strong-password-123"), source)
        XCTAssertThrowsError(try BackupCrypto.encrypt(source, password: "short"))
        XCTAssertThrowsError(try BackupCrypto.decrypt(encrypted, password: "wrong-password"))
        var envelope = try JSONDecoder().decode(BackupEnvelope.self, from: encrypted)
        envelope.sealed[envelope.sealed.count - 1] ^= 1
        XCTAssertThrowsError(try BackupCrypto.decrypt(JSONEncoder().encode(envelope), password: "strong-password-123"))
        envelope.version = 99
        XCTAssertThrowsError(try BackupCrypto.decrypt(JSONEncoder().encode(envelope), password: "strong-password-123"))
        let second = try BackupCrypto.encrypt(source, password: "strong-password-123")
        XCTAssertNotEqual(second, encrypted)
    }
    func testRoundTripAllModelsRelationshipsImagesAndPreferences() throws {
        let container = try container(); let context = container.mainContext; let service = service()
        let project = HomeProject(name: "Kitchen", estimatedCost: 300, actualCost: 75)
        context.insert(project)
        let task = TaskItem(title: "Book contractor", priority: .high, repeatRule: .weekly, reminderEnabled: true, project: project)
        task.completedScheduleDates = [Date(timeIntervalSince1970: 100)]
        task.isSnoozed = true; context.insert(task)
        let child = ProjectTask(title: "Paint", project: project); child.sortOrder = 3; child.isComplete = true; context.insert(child)
        let shopping = ProjectShoppingItem(name: "Tiles", quantity: 8, estimatedUnitCost: 12, project: project)
        shopping.isPurchased = true; context.insert(shopping)
        let maintenance = HomeMaintenance(name: "Filter"); maintenance.reminderEnabled = true; maintenance.reminderHour = 13
        context.insert(maintenance)
        context.insert(SubscriptionItem(name: "Music", cost: 12, frequency: "Annual"))
        context.insert(BillItem(name: "Water", amount: 45, autoPay: true))
        let grocery = GroceryItem(name: "Milk", isStaged: true, isPurchased: true, quantity: 2); grocery.lastPurchasedAt = .now; context.insert(grocery)
        let data = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).jpegData(withCompressionQuality: 1) { ctx in
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let files = try service.images.write(data)
        let card = VisitingCard(name: "Sam"); card.emails = ["sam@example.test"]; card.frontImage = files.image; card.frontThumbnail = files.thumbnail; context.insert(card)
        defaults.set("Alex", forKey: "preferredName"); defaults.set("Dark", forKey: "appearance"); defaults.set(true, forKey: "appLockEnabled")
        let expectedDates = task.completedScheduleDates
        let expectedCardID = card.id
        let snapshot = try service.capture(in: context)
        try snapshot.validate()
        let encrypted = try BackupCrypto.encrypt(JSONEncoder().encode(snapshot), password: "round-trip-password")
        let decoded = try JSONDecoder().decode(BackupSnapshot.self, from: BackupCrypto.decrypt(encrypted, password: "round-trip-password"))
        context.insert(TaskItem(title: "Remove me")); try context.save()
        defaults.set("Light", forKey: "appearance")
        try service.restore(decoded, in: context)
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.count, 1); XCTAssertEqual(tasks.first?.title, "Book contractor")
        XCTAssertEqual(tasks.first?.project?.name, "Kitchen"); XCTAssertEqual(tasks.first?.completedScheduleDates, expectedDates)
        let projects = try context.fetch(FetchDescriptor<HomeProject>())
        XCTAssertEqual(projects.first?.tasks.first?.sortOrder, 3)
        XCTAssertEqual(projects.first?.shoppingItems.first?.quantity, 8)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HomeMaintenance>()).first?.reminderHour, 13)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SubscriptionItem>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BillItem>()).first?.amount, 45)
        XCTAssertEqual(try context.fetch(FetchDescriptor<GroceryItem>()).first?.quantity, 2)
        let restoredCard = try XCTUnwrap(context.fetch(FetchDescriptor<VisitingCard>()).first)
        XCTAssertEqual(restoredCard.id, expectedCardID)
        XCTAssertEqual(restoredCard.emails, ["sam@example.test"])
        XCTAssertNotNil(service.images.data(for: restoredCard.frontImage))
        XCTAssertEqual(defaults.string(forKey: "appearance"), "Dark"); XCTAssertTrue(prefs.lockEnabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.journalURL.path))
    }
    func testFailedCommitRetainsRecoveryAndRejectsMissingImages() throws {
        let container = try container(); let context = container.mainContext
        let service = service()
        context.insert(TaskItem(title: "Original"))
        context.insert(VisitingCard(name: "Card"))
        let original = try service.capture(in: context)
        var missing = original; missing.cards[0].frontImage = "missing.jpg"
        XCTAssertThrowsError(try service.restore(missing, in: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).first?.title, "Original")
        var incoming = original; incoming.tasks[0].title = "Replacement"
        var failing = service
        failing.beforeCommit = { throw NSError(domain: "SimulatedDiskFailure", code: 1) }
        XCTAssertThrowsError(try failing.restore(incoming, in: context))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.journalURL.path))
        try service.recoverIfNeeded(in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).map(\.title), ["Original"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.journalURL.path))
    }

    func testInvalidBackupLeavesExistingDataAndRecoveryRestoresPreviousSnapshot() throws {
        let container = try container(); let context = container.mainContext; let service = service()
        context.insert(TaskItem(title: "Keep me")); try context.save()
        let original = try service.capture(in: context)
        var broken = original
        broken.tasks[0].projectID = UUID()
        XCTAssertThrowsError(try service.restore(broken, in: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).first?.title, "Keep me")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(original).write(to: service.journalURL)
        context.insert(TaskItem(title: "Interrupted restore")); try context.save()
        try service.recoverIfNeeded(in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).map(\.title), ["Keep me"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.journalURL.path))
        var empty = original; empty.tasks = []
        try service.restore(empty, in: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }
}

@MainActor
final class AppLockFeatureTests: XCTestCase {
    @MainActor final class Authenticator: DeviceAuthenticating {
        var succeeds = true
        var count = 0
        func authenticate(reason: String) async throws -> Bool { count += 1; return succeeds }
    }
    func testLockEnrollmentCancellationAndSystemDialogs() async {
        let suite = "AppLockFeatureTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults, domainName: suite)
        let auth = Authenticator()
        let controller = AppLockController(preferences: preferences, authenticator: auth)
        auth.succeeds = false
        await controller.setEnabled(true)
        XCTAssertFalse(controller.enabled)
        auth.succeeds = true
        await controller.setEnabled(true)
        XCTAssertTrue(controller.enabled)
        let previousCount = auth.count
        controller.sceneChanged(.inactive); XCTAssertTrue(controller.privacyCovered)
        controller.sceneChanged(.active); XCTAssertFalse(controller.isLocked)
        XCTAssertEqual(auth.count, previousCount)
        controller.sceneChanged(.background); XCTAssertTrue(controller.isLocked)
        auth.succeeds = false
        await controller.authenticateToUnlock(); XCTAssertTrue(controller.isLocked)
        auth.succeeds = true
        await controller.authenticateToUnlock(); XCTAssertFalse(controller.isLocked)
        await controller.setEnabled(false); XCTAssertFalse(preferences.lockEnabled)
    }
}
