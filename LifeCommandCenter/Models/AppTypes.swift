import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case low = "Low", medium = "Medium", high = "High", urgent = "Urgent"
    var id: String { rawValue }
    var color: Color { switch self { case .low: .blue; case .medium: .orange; case .high: .pink; case .urgent: .red } }
}

enum AppAccentColor: String, CaseIterable, Identifiable {
    case forest = "Forest", blue = "Blue", indigo = "Indigo", purple = "Purple", pink = "Pink", orange = "Orange", teal = "Teal"
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
    static func color(named name: String) -> Color { allCases.first { $0.rawValue == name }?.color ?? .init(red: 0.27, green: 0.42, blue: 0.35) }
}

enum AppFontSize {
    static func dynamicTypeSize(for selection: String) -> DynamicTypeSize {
        switch selection { case "Small": .small; case "Large": .xxxLarge; default: .large }
    }
}

enum RepeatRule: String, CaseIterable, Identifiable, Codable {
    case none = "Never", daily = "Daily", weekly = "Weekly", monthly = "Monthly", quarterly = "Quarterly", yearly = "Yearly"
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
