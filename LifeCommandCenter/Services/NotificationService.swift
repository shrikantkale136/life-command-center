import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

enum NotificationService {
    @MainActor
    static func makeMaintenanceRequests(for item: HomeMaintenance, asOf now: Date = .now)
        -> [UNNotificationRequest]
    {
        guard item.reminderEnabled, item.dateEnabled, item.isWithinRepeatEnd(item.nextDue) else {
            return []
        }
        let calendar = item.scheduleCalendar
        var day = item.nextDue
        var requests: [UNNotificationRequest] = []
        for _ in 0..<50_000 {
            guard
                let date = item.frequency == .hourly
                    ? day
                    : calendar.date(
                        bySettingHour: item.reminderHour, minute: item.reminderMinute, second: 0,
                        of: day)
            else { break }
            if date > now,
                let request = makeRequest(
                    id: "maintenance-\(item.reminderID)-\(requests.count)", title: item.name,
                    date: date, preferredName: UserDefaults.standard.string(forKey: "preferredName") ?? "", calendar: calendar)
            {
                requests.append(request)
                if requests.count == 12 { break }
            }
            guard let next = item.nextDate(after: day), next > day else { break }
            day = next
        }
        return requests
    }

    @MainActor
    static func syncMaintenance(in context: ModelContext) {
        guard !ProcessInfo.processInfo.arguments.contains("-ui-testing"),
              let items = try? context.fetch(FetchDescriptor<HomeMaintenance>()),
              let tasks = try? context.fetch(FetchDescriptor<TaskItem>()) else { return }
        let prefs = AppPreferences()
        let maintenance = items.flatMap { makeMaintenanceRequests(for: $0) }
        let taskRequests = tasks.filter { $0.reminderEnabled && !$0.isComplete }.compactMap {
            makeRequest(id: taskID($0), title: $0.title, date: $0.dueDate,
                        preferredName: prefs.defaults.string(forKey: "preferredName") ?? "")
        }
        let requests = (maintenance + taskRequests).sorted {
            (($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture)
                < (($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture)
        }
        revision += 1
        let currentRevision = revision
        let previous = syncTask
        syncTask = Task { @MainActor in
            await previous?.value
            guard revision == currentRevision else { return }
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let pending = await center.pendingNotificationRequests()
            guard revision == currentRevision else { return }
            // Numeric identifiers were used for task reminders in earlier versions.
            let owned = pending.filter { $0.identifier.hasPrefix("maintenance-") || $0.identifier.hasPrefix("task-") || Int($0.identifier) != nil }
            center.removePendingNotificationRequests(withIdentifiers: owned.map(\.identifier))
            guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }
            for request in requests.prefix(max(0, 64 - (pending.count - owned.count))) {
                guard revision == currentRevision else { return }
                try? await center.add(request)
            }
        }
    }
    @MainActor private static var revision = 0
    @MainActor private static var syncTask: Task<Void, Never>?
    static func taskID(_ task: TaskItem) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return "task-" + ((try? encoder.encode(task.persistentModelID))?.base64EncodedString() ?? task.persistentModelID.hashValue.description)
    }

    static func makeRequest(
        id: String,
        title: String,
        date: Date,
        preferredName: String = "",
        calendar: Calendar = .current,
        preferences: AppPreferences = .init()
    ) -> UNNotificationRequest? {
        guard date > .now else { return nil }
        let name = preferences.personalizedReminders ? preferredName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let content = UNMutableNotificationContent()
        content.title = name.isEmpty ? "Coming up" : "Hey \(name)! 👋"
        content.body = "\(title) is coming up."
        content.sound = preferences.soundEnabled(at: date) ? .default : nil
        var dateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        dateComponents.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
    }

    static func schedule(id: String, title: String, date: Date) {
        UNUserNotificationCenter.current().requestAuthorization(options: [
            .alert, .sound,
        ]) { granted, _ in
            guard granted,
                let request = makeRequest(
                    id: id,
                    title: title,
                    date: date,
                    preferredName: UserDefaults.standard.string(
                        forKey: "preferredName"
                    ) ?? ""
                )
            else { return }
            UNUserNotificationCenter.current().add(request)
        }
    }
    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [id])
    }
}
