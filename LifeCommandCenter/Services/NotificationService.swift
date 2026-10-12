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
                    date: date, calendar: calendar)
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
        guard let items = try? context.fetch(FetchDescriptor<HomeMaintenance>()) else { return }
        let requests = items.flatMap { makeMaintenanceRequests(for: $0) }
            .sorted {
                (($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture)
                    < (($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                        ?? .distantFuture)
            }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let maintenanceIDs = pending.filter { $0.identifier.hasPrefix("maintenance-") }.map(
                \.identifier)
            center.removePendingNotificationRequests(withIdentifiers: maintenanceIDs)
            guard !requests.isEmpty else { return }
            let available = max(0, 64 - (pending.count - maintenanceIDs.count))
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                for request in requests.prefix(available) { center.add(request) }
            }
        }
    }

    static func makeRequest(
        id: String,
        title: String,
        date: Date,
        preferredName: String = "",
        calendar: Calendar = .current
    ) -> UNNotificationRequest? {
        guard date > .now else { return nil }
        let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = UNMutableNotificationContent()
        content.title = name.isEmpty ? "Coming up" : "Hey \(name)! 👋"
        content.body = "\(title) is coming up."
        content.sound = .default
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
