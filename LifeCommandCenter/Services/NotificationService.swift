import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

enum NotificationService {
    static func makeRequest(id: String, title: String, date: Date, preferredName: String = "") -> UNNotificationRequest? {
        guard date > .now else { return nil }
        let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = UNMutableNotificationContent()
        content.title = name.isEmpty ? "Coming up" : "Hey \(name)! 👋"
        content.body = "\(title) is coming up."
        content.sound = .default
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    static func schedule(id: String, title: String, date: Date) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted, let request = makeRequest(
                id: id,
                title: title,
                date: date,
                preferredName: UserDefaults.standard.string(forKey: "preferredName") ?? ""
            ) else { return }
            UNUserNotificationCenter.current().add(request)
        }
    }
    static func cancel(id: String) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]) }
}
