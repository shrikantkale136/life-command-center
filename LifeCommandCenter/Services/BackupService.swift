import Foundation
import SwiftUI
import SwiftData
import CryptoKit
import CommonCrypto
import UIKit
import UniformTypeIdentifiers

enum BackupError: LocalizedError {
    case invalid, version, password, shortPassword, recovery
    var errorDescription: String? {
        switch self {
        case .invalid: "This backup is damaged or contains invalid records or images."
        case .version: "This backup format is not supported by this version of Home Manager."
        case .password: "The password is incorrect or the backup has been changed."
        case .shortPassword: "Use a backup password with at least 12 characters."
        case .recovery: "The previous restore needs recovery. Your recovery copy has been retained. Try again before continuing."
        }
    }
}

extension UTType {
    static let homeManagerBackup = UTType(exportedAs: "com.example.LifeCommandCenter.backup", conformingTo: .data)
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.homeManagerBackup] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw BackupError.invalid }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupEnvelope: Codable {
    var version: Int
    var salt: Data
    var sealed: Data
    static let header = Data("HomeManagerBackup:1:PBKDF2-SHA256:600000:AES256GCM".utf8)
}

enum BackupCrypto {
    private static func key(password: String, salt: Data) throws -> SymmetricKey {
        let bytes = Array(password.utf8)
        var result = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self), bytes.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 600_000, &result, 32)
            }
        }
        guard status == kCCSuccess else { throw BackupError.invalid }
        return SymmetricKey(data: result)
    }
    static func encrypt(_ payload: Data, password: String) throws -> Data {
        guard password.count >= 12 else { throw BackupError.shortPassword }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw BackupError.invalid }
        let box = try AES.GCM.seal(payload, using: key(password: password, salt: salt), authenticating: BackupEnvelope.header)
        guard let combined = box.combined else { throw BackupError.invalid }
        return try JSONEncoder().encode(BackupEnvelope(version: 1, salt: salt, sealed: combined))
    }
    static func decrypt(_ data: Data, password: String) throws -> Data {
        guard data.count <= 512 * 1024 * 1024 else { throw BackupError.invalid }
        let envelope: BackupEnvelope
        do { envelope = try JSONDecoder().decode(BackupEnvelope.self, from: data) } catch { throw BackupError.invalid }
        guard envelope.version == 1 else { throw BackupError.version }
        guard envelope.salt.count == 16, envelope.sealed.count >= 28 else { throw BackupError.invalid }
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.sealed),
                using: key(password: password, salt: envelope.salt), authenticating: BackupEnvelope.header)
        } catch { throw BackupError.password }
    }
}

struct TaskItemBackup: Codable {
    var backupID: UUID
    var projectID: UUID?
    var completedScheduleDates: [Date]
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
    init(_ item: TaskItem, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        projectID = item.project.flatMap { ids[$0.persistentModelID] }
        completedScheduleDates = item.completedScheduleDates
        title = item.title
        detail = item.detail
        dueDate = item.dueDate
        priorityRaw = item.priorityRaw
        category = item.category
        repeatRaw = item.repeatRaw
        isComplete = item.isComplete
        isSnoozed = item.isSnoozed
        createdAt = item.createdAt
        completedAt = item.completedAt
        reminderEnabled = item.reminderEnabled
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> TaskItem {
        let item = TaskItem(title: title)
        context.insert(item)
        item.completedScheduleDates = completedScheduleDates
        item.title = title
        item.detail = detail
        item.dueDate = dueDate
        item.priorityRaw = priorityRaw
        item.category = category
        item.repeatRaw = repeatRaw
        item.isComplete = isComplete
        item.isSnoozed = isSnoozed
        item.createdAt = createdAt
        item.completedAt = completedAt
        item.reminderEnabled = reminderEnabled
        item.project = projectID.flatMap { projects[$0] }
        return item
    }
}

struct HomeMaintenanceBackup: Codable {
    var backupID: UUID
    var completedScheduleDates: [Date]
    var name: String
    var area: String
    var detail: String
    var nextDue: Date
    var frequencyRaw: String
    var cost: Double
    var provider: String
    var notes: String
    var lastCompleted: Date?
    var dateEnabled: Bool
    var timeEnabled: Bool
    var timeZoneEnabled: Bool
    var timeZoneID: String
    var repeatEndDate: Date?
    var customInterval: Int
    var customIntervalUnitRaw: String
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var reminderID: String
    init(_ item: HomeMaintenance, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        completedScheduleDates = item.completedScheduleDates
        name = item.name
        area = item.area
        detail = item.detail
        nextDue = item.nextDue
        frequencyRaw = item.frequencyRaw
        cost = item.cost
        provider = item.provider
        notes = item.notes
        lastCompleted = item.lastCompleted
        dateEnabled = item.dateEnabled
        timeEnabled = item.timeEnabled
        timeZoneEnabled = item.timeZoneEnabled
        timeZoneID = item.timeZoneID
        repeatEndDate = item.repeatEndDate
        customInterval = item.customInterval
        customIntervalUnitRaw = item.customIntervalUnitRaw
        reminderEnabled = item.reminderEnabled
        reminderHour = item.reminderHour
        reminderMinute = item.reminderMinute
        reminderID = item.reminderID
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> HomeMaintenance {
        let item = HomeMaintenance(name: name)
        context.insert(item)
        item.completedScheduleDates = completedScheduleDates
        item.name = name
        item.area = area
        item.detail = detail
        item.nextDue = nextDue
        item.frequencyRaw = frequencyRaw
        item.cost = cost
        item.provider = provider
        item.notes = notes
        item.lastCompleted = lastCompleted
        item.dateEnabled = dateEnabled
        item.timeEnabled = timeEnabled
        item.timeZoneEnabled = timeZoneEnabled
        item.timeZoneID = timeZoneID
        item.repeatEndDate = repeatEndDate
        item.customInterval = customInterval
        item.customIntervalUnitRaw = customIntervalUnitRaw
        item.reminderEnabled = reminderEnabled
        item.reminderHour = reminderHour
        item.reminderMinute = reminderMinute
        item.reminderID = reminderID
        return item
    }
}

struct HomeProjectBackup: Codable {
    var backupID: UUID
    var completedScheduleDates: [Date]
    var name: String
    var detail: String
    var area: String
    var startDate: Date
    var targetDate: Date
    var status: String
    var priorityRaw: String
    var estimatedCost: Double
    var actualCost: Double
    init(_ item: HomeProject, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        completedScheduleDates = item.completedScheduleDates
        name = item.name
        detail = item.detail
        area = item.area
        startDate = item.startDate
        targetDate = item.targetDate
        status = item.status
        priorityRaw = item.priorityRaw
        estimatedCost = item.estimatedCost
        actualCost = item.actualCost
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> HomeProject {
        let item = HomeProject(name: name)
        context.insert(item)
        item.completedScheduleDates = completedScheduleDates
        item.name = name
        item.detail = detail
        item.area = area
        item.startDate = startDate
        item.targetDate = targetDate
        item.status = status
        item.priorityRaw = priorityRaw
        item.estimatedCost = estimatedCost
        item.actualCost = actualCost
        return item
    }
}

struct ProjectTaskBackup: Codable {
    var backupID: UUID
    var projectID: UUID?
    var title: String
    var isComplete: Bool
    var sortOrder: Int
    init(_ item: ProjectTask, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        projectID = item.project.flatMap { ids[$0.persistentModelID] }
        title = item.title
        isComplete = item.isComplete
        sortOrder = item.sortOrder
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> ProjectTask {
        let item = ProjectTask(title: title)
        context.insert(item)
        item.title = title
        item.isComplete = isComplete
        item.sortOrder = sortOrder
        item.project = projectID.flatMap { projects[$0] }
        return item
    }
}

struct ProjectShoppingItemBackup: Codable {
    var backupID: UUID
    var projectID: UUID?
    var name: String
    var quantity: Int
    var estimatedUnitCost: Double
    var isPurchased: Bool
    var sortOrder: Int
    init(_ item: ProjectShoppingItem, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        projectID = item.project.flatMap { ids[$0.persistentModelID] }
        name = item.name
        quantity = item.quantity
        estimatedUnitCost = item.estimatedUnitCost
        isPurchased = item.isPurchased
        sortOrder = item.sortOrder
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> ProjectShoppingItem {
        let item = ProjectShoppingItem(name: name)
        context.insert(item)
        item.name = name
        item.quantity = quantity
        item.estimatedUnitCost = estimatedUnitCost
        item.isPurchased = isPurchased
        item.sortOrder = sortOrder
        item.project = projectID.flatMap { projects[$0] }
        return item
    }
}

struct SubscriptionItemBackup: Codable {
    var backupID: UUID
    var completedScheduleDates: [Date]
    var name: String
    var category: String
    var cost: Double
    var frequencyRaw: String
    var nextDate: Date
    var paymentMethod: String
    var autoRenew: Bool
    var notes: String
    var isActive: Bool
    init(_ item: SubscriptionItem, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        completedScheduleDates = item.completedScheduleDates
        name = item.name
        category = item.category
        cost = item.cost
        frequencyRaw = item.frequencyRaw
        nextDate = item.nextDate
        paymentMethod = item.paymentMethod
        autoRenew = item.autoRenew
        notes = item.notes
        isActive = item.isActive
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> SubscriptionItem {
        let item = SubscriptionItem(name: name)
        context.insert(item)
        item.completedScheduleDates = completedScheduleDates
        item.name = name
        item.category = category
        item.cost = cost
        item.frequencyRaw = frequencyRaw
        item.nextDate = nextDate
        item.paymentMethod = paymentMethod
        item.autoRenew = autoRenew
        item.notes = notes
        item.isActive = isActive
        return item
    }
}

struct BillItemBackup: Codable {
    var backupID: UUID
    var completedScheduleDates: [Date]
    var name: String
    var amount: Double
    var dueDate: Date
    var frequencyRaw: String
    var autoPay: Bool
    var paymentMethod: String
    var notes: String
    init(_ item: BillItem, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        completedScheduleDates = item.completedScheduleDates
        name = item.name
        amount = item.amount
        dueDate = item.dueDate
        frequencyRaw = item.frequencyRaw
        autoPay = item.autoPay
        paymentMethod = item.paymentMethod
        notes = item.notes
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> BillItem {
        let item = BillItem(name: name)
        context.insert(item)
        item.completedScheduleDates = completedScheduleDates
        item.name = name
        item.amount = amount
        item.dueDate = dueDate
        item.frequencyRaw = frequencyRaw
        item.autoPay = autoPay
        item.paymentMethod = paymentMethod
        item.notes = notes
        return item
    }
}

struct GroceryItemBackup: Codable {
    var backupID: UUID
    var name: String
    var category: String
    var isStaged: Bool
    var isPurchased: Bool
    var quantity: Int
    var lastPurchasedAt: Date?
    var createdAt: Date
    init(_ item: GroceryItem, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        name = item.name
        category = item.category
        isStaged = item.isStaged
        isPurchased = item.isPurchased
        quantity = item.quantity
        lastPurchasedAt = item.lastPurchasedAt
        createdAt = item.createdAt
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> GroceryItem {
        let item = GroceryItem(name: name)
        context.insert(item)
        item.name = name
        item.category = category
        item.isStaged = isStaged
        item.isPurchased = isPurchased
        item.quantity = quantity
        item.lastPurchasedAt = lastPurchasedAt
        item.createdAt = createdAt
        return item
    }
}

struct VisitingCardBackup: Codable {
    var backupID: UUID
    var id: UUID
    var name: String
    var company: String
    var jobTitle: String
    var phones: [String]
    var emails: [String]
    var website: String
    var address: String
    var tags: [String]
    var notes: String
    var frontText: String
    var backText: String
    var frontImage: String?
    var backImage: String?
    var frontThumbnail: String?
    var backThumbnail: String?
    var createdAt: Date
    var updatedAt: Date
    init(_ item: VisitingCard, ids: [PersistentIdentifier: UUID]) {
        backupID = ids[item.persistentModelID]!
        id = item.id
        name = item.name
        company = item.company
        jobTitle = item.jobTitle
        phones = item.phones
        emails = item.emails
        website = item.website
        address = item.address
        tags = item.tags
        notes = item.notes
        frontText = item.frontText
        backText = item.backText
        frontImage = item.frontImage
        backImage = item.backImage
        frontThumbnail = item.frontThumbnail
        backThumbnail = item.backThumbnail
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }
    @MainActor func insert(in context: ModelContext, projects: [UUID: HomeProject]) -> VisitingCard {
        let item = VisitingCard(name: name)
        context.insert(item)
        item.id = id
        item.name = name
        item.company = company
        item.jobTitle = jobTitle
        item.phones = phones
        item.emails = emails
        item.website = website
        item.address = address
        item.tags = tags
        item.notes = notes
        item.frontText = frontText
        item.backText = backText
        item.frontImage = frontImage
        item.backImage = backImage
        item.frontThumbnail = frontThumbnail
        item.backThumbnail = backThumbnail
        item.createdAt = createdAt
        item.updatedAt = updatedAt
        return item
    }
}

struct BackupSnapshot: Codable {
    var version = 1
    var createdAt = Date.now
    var preferences: [String: PreferenceValue]
    var images: [String: Data]
    var tasks: [TaskItemBackup]
    var maintenance: [HomeMaintenanceBackup]
    var projects: [HomeProjectBackup]
    var projectTasks: [ProjectTaskBackup]
    var shopping: [ProjectShoppingItemBackup]
    var subscriptions: [SubscriptionItemBackup]
    var bills: [BillItemBackup]
    var groceries: [GroceryItemBackup]
    var cards: [VisitingCardBackup]
    var recordCount: Int { tasks.count + maintenance.count + projects.count + projectTasks.count + shopping.count + subscriptions.count + bills.count + groceries.count + cards.count }
    func validate() throws {
        guard version == 1 else { throw BackupError.version }
        try AppPreferences.validate(preferences)
        let ids = tasks.map(\.backupID) + maintenance.map(\.backupID) + projects.map(\.backupID) + projectTasks.map(\.backupID) + shopping.map(\.backupID) + subscriptions.map(\.backupID) + bills.map(\.backupID) + groceries.map(\.backupID) + cards.map(\.backupID)
        guard Set(ids).count == ids.count else { throw BackupError.invalid }
        let projectIDs = Set(projects.map(\.backupID))
        let links = tasks.compactMap(\.projectID) + projectTasks.compactMap(\.projectID) + shopping.compactMap(\.projectID)
        guard links.allSatisfy({ projectIDs.contains($0) }),
              Set(cards.map(\.id)).count == cards.count,
              maintenance.allSatisfy({ $0.customInterval > 0 && (0..<24).contains($0.reminderHour) && (0..<60).contains($0.reminderMinute) }),
              groceries.allSatisfy({ $0.quantity >= 0 }), shopping.allSatisfy({ $0.quantity >= 0 }) else { throw BackupError.invalid }
        for (name, data) in images {
            guard Self.safeFilename(name), UIImage(data: data) != nil else { throw BackupError.invalid }
        }
        for card in cards {
            for reference in [card.frontImage, card.backImage, card.frontThumbnail, card.backThumbnail].compactMap({ $0 }) {
                guard Self.safeFilename(reference), images[reference] != nil else { throw BackupError.invalid }
            }
        }
    }
    static func safeFilename(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\\")
    }
}

@MainActor
struct BackupService {
    let preferences: AppPreferences
    let images: VisitingCardImageStore
    let journalURL: URL
    var beforeCommit: (() throws -> Void)?
    init(preferences: AppPreferences = .init(), images: VisitingCardImageStore = .init(), journalURL: URL? = nil, beforeCommit: (() throws -> Void)? = nil) {
        self.beforeCommit = beforeCommit
        self.preferences = preferences
        self.images = images
        self.journalURL = journalURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RestoreRecovery.json")
    }
    func capture(in context: ModelContext) throws -> BackupSnapshot {
        try context.save()
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        let maintenance = try context.fetch(FetchDescriptor<HomeMaintenance>())
        let projects = try context.fetch(FetchDescriptor<HomeProject>())
        let projectTasks = try context.fetch(FetchDescriptor<ProjectTask>())
        let shopping = try context.fetch(FetchDescriptor<ProjectShoppingItem>())
        let subscriptions = try context.fetch(FetchDescriptor<SubscriptionItem>())
        let bills = try context.fetch(FetchDescriptor<BillItem>())
        let groceries = try context.fetch(FetchDescriptor<GroceryItem>())
        let cards = try context.fetch(FetchDescriptor<VisitingCard>())
        var ids: [PersistentIdentifier: UUID] = [:]
        for item in tasks { ids[item.persistentModelID] = UUID() }
        for item in maintenance { ids[item.persistentModelID] = UUID() }
        for item in projects { ids[item.persistentModelID] = UUID() }
        for item in projectTasks { ids[item.persistentModelID] = UUID() }
        for item in shopping { ids[item.persistentModelID] = UUID() }
        for item in subscriptions { ids[item.persistentModelID] = UUID() }
        for item in bills { ids[item.persistentModelID] = UUID() }
        for item in groceries { ids[item.persistentModelID] = UUID() }
        for item in cards { ids[item.persistentModelID] = UUID() }
        var data: [String: Data] = [:]
        for card in cards {
            for reference in card.imageFiles {
                guard BackupSnapshot.safeFilename(reference), let image = images.data(for: reference) else { throw BackupError.invalid }
                data[reference] = image
            }
        }
        return BackupSnapshot(preferences: preferences.portable(), images: data,
            tasks: tasks.map { TaskItemBackup($0, ids: ids) },
            maintenance: maintenance.map { HomeMaintenanceBackup($0, ids: ids) },
            projects: projects.map { HomeProjectBackup($0, ids: ids) },
            projectTasks: projectTasks.map { ProjectTaskBackup($0, ids: ids) },
            shopping: shopping.map { ProjectShoppingItemBackup($0, ids: ids) },
            subscriptions: subscriptions.map { SubscriptionItemBackup($0, ids: ids) },
            bills: bills.map { BillItemBackup($0, ids: ids) },
            groceries: groceries.map { GroceryItemBackup($0, ids: ids) },
            cards: cards.map { VisitingCardBackup($0, ids: ids) })
    }
    func restore(_ snapshot: BackupSnapshot, in context: ModelContext) throws {
        try snapshot.validate()
        guard !FileManager.default.fileExists(atPath: journalURL.path) else { throw BackupError.recovery }
        let previous = try capture(in: context)
        try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(previous).write(to: journalURL, options: [.atomic, .completeFileProtection])
        do {
            try replace(snapshot, in: context)
            try FileManager.default.removeItem(at: journalURL)
        } catch {
            do {
                try replace(previous, in: context)
                try FileManager.default.removeItem(at: journalURL)
                finish(in: context)
            } catch {
                NotificationCenter.default.post(name: .backupRecoveryRequired, object: nil)
                throw BackupError.recovery
            }
            throw error
        }
        finish(in: context)
    }
    func recoverIfNeeded(in context: ModelContext) throws {
        guard FileManager.default.fileExists(atPath: journalURL.path) else { return }
        let previous = try JSONDecoder().decode(BackupSnapshot.self, from: Data(contentsOf: journalURL))
        try previous.validate()
        try replace(previous, in: context)
        try FileManager.default.removeItem(at: journalURL)
        finish(in: context)
    }
    private func finish(in context: ModelContext) {
        preferences.defaults.set(true, forKey: "didSeedInitialData")
        preferences.defaults.set(true, forKey: "didSeedGroceryCatalog")
        try? VisitingCardRepository(context: context, images: images).removeOrphanedImages()
        NotificationService.syncMaintenance(in: context)
        NotificationCenter.default.post(name: .backupRestored, object: nil)
    }
    private func replace(_ original: BackupSnapshot, in context: ModelContext) throws {
        try original.validate()
        var snapshot = original
        var references: [String: String] = [:]
        var written: [String] = []
        try FileManager.default.createDirectory(at: images.directory, withIntermediateDirectories: true)
        do {
            for (name, data) in snapshot.images {
                let reference = "restore-" + UUID().uuidString + ".jpg"
                try data.write(to: images.directory.appendingPathComponent(reference), options: [.atomic, .completeFileProtection])
                references[name] = reference
                written.append(reference)
            }
            for index in snapshot.cards.indices {
                snapshot.cards[index].frontImage = snapshot.cards[index].frontImage.flatMap { references[$0] }
                snapshot.cards[index].backImage = snapshot.cards[index].backImage.flatMap { references[$0] }
                snapshot.cards[index].frontThumbnail = snapshot.cards[index].frontThumbnail.flatMap { references[$0] }
                snapshot.cards[index].backThumbnail = snapshot.cards[index].backThumbnail.flatMap { references[$0] }
            }
            for item in try context.fetch(FetchDescriptor<TaskItem>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<ProjectTask>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<ProjectShoppingItem>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<HomeProject>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<HomeMaintenance>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<SubscriptionItem>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<BillItem>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<GroceryItem>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<VisitingCard>()) { context.delete(item) }
            var projects: [UUID: HomeProject] = [:]
            for record in snapshot.projects { projects[record.backupID] = record.insert(in: context, projects: [:]) }
            for record in snapshot.tasks { _ = record.insert(in: context, projects: projects) }
            for record in snapshot.maintenance { _ = record.insert(in: context, projects: projects) }
            for record in snapshot.projectTasks { _ = record.insert(in: context, projects: projects) }
            for record in snapshot.shopping { _ = record.insert(in: context, projects: projects) }
            for record in snapshot.subscriptions { _ = record.insert(in: context, projects: projects) }
            for record in snapshot.bills { _ = record.insert(in: context, projects: projects) }
            for record in snapshot.groceries { _ = record.insert(in: context, projects: projects) }
            for record in snapshot.cards { _ = record.insert(in: context, projects: projects) }
            try beforeCommit?()
            try context.save()
        } catch {
            context.rollback()
            images.remove(written)
            throw error
        }
        preferences.apply(snapshot.preferences)
    }
}
