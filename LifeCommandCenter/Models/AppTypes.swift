import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .low: .blue
        case .medium: .orange
        case .high: .pink
        case .urgent: .red
        }
    }
}

enum AppAccentColor: String, CaseIterable, Identifiable {
    case forest = "Forest"
    case blue = "Blue"
    case indigo = "Indigo"
    case purple = "Purple"
    case pink = "Pink"
    case orange = "Orange"
    case teal = "Teal"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .forest: Color(red: 0.27, green: 0.42, blue: 0.35)
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .orange: .orange
        case .teal: .teal
        }
    }
    static func color(named name: String) -> Color {
        allCases.first { $0.rawValue == name }?.color
            ?? .init(red: 0.27, green: 0.42, blue: 0.35)
    }
}

enum AppFontSize {
    static func dynamicTypeSize(for selection: String) -> DynamicTypeSize {
        switch selection {
        case "Small": .small
        case "Large": .xxxLarge
        default: .large
        }
    }
}

enum RepeatRule: String, CaseIterable, Identifiable, Codable {
    case none = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
    var id: String { rawValue }
    func next(after date: Date) -> Date? {
        let c: Calendar = .current
        switch self {
        case .none: return nil
        case .daily: return c.date(byAdding: .day, value: 1, to: date)
        case .weekly: return c.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return c.date(byAdding: .month, value: 1, to: date)
        case .quarterly: return c.date(byAdding: .month, value: 3, to: date)
        case .yearly: return c.date(byAdding: .year, value: 1, to: date)
        }
    }
}

enum MaintenanceIntervalUnit: String, CaseIterable, Identifiable {
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"
    case years = "Years"
    var id: String { rawValue }
    var component: Calendar.Component {
        switch self {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        case .years: .year
        }
    }
}

enum MaintenanceFrequency: String, CaseIterable, Identifiable {
    case none = "Never"
    case hourly = "Hourly"
    case daily = "Daily"
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case semiannual = "Semiannual"
    case yearly = "Yearly"
    case custom = "Custom"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Never"
        case .biweekly: "Biweekly"
        case .quarterly: "Every 3 months"
        case .semiannual: "Every 6 months"
        default: rawValue
        }
    }
    func next(
        after date: Date, interval: Int = 1, unit: MaintenanceIntervalUnit = .days,
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .none: nil
        case .hourly: calendar.date(byAdding: .hour, value: 1, to: date)
        case .daily: calendar.date(byAdding: .day, value: 1, to: date)
        case .weekdays: nextMatchingDay(after: date, weekend: false, calendar: calendar)
        case .weekends: nextMatchingDay(after: date, weekend: true, calendar: calendar)
        case .weekly: calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly: calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly: calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly: calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual: calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly: calendar.date(byAdding: .year, value: 1, to: date)
        case .custom:
            interval > 0 ? calendar.date(byAdding: unit.component, value: interval, to: date) : nil
        }
    }
    private func nextMatchingDay(after date: Date, weekend: Bool, calendar: Calendar) -> Date? {
        for offset in 1...7 {
            guard let next = calendar.date(byAdding: .day, value: offset, to: date) else {
                return nil
            }
            let day = calendar.component(.weekday, from: next)
            if ([1, 7].contains(day)) == weekend { return next }
        }
        return nil
    }

}
