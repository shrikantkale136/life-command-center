import Foundation
import Observation
import SwiftUI
import UIKit

enum OpeningStyle: String, CaseIterable, Identifiable {
    case sky = "Sunrise & Moon", fade = "Soft Fade", staticScreen = "Static"
    var id: String { rawValue }
}

enum StartPage: String, CaseIterable, Identifiable {
    case today = "Today", groceries = "Groceries", home = "Home", money = "Money"
    var id: String { rawValue }
    var tab: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// An allowlist keeps security, seed flags, and export history out of portable preferences.
struct AppPreferences {
    let defaults: UserDefaults
    let domainName: String?
    init(defaults: UserDefaults = .standard, domainName: String? = Bundle.main.bundleIdentifier) {
        self.defaults = defaults; self.domainName = domainName
    }
    static let categories = ["Personal", "Work", "Home", "Finance", "Shopping", "Health", "Family", "Other"]
    static let initialValues: [String: PreferenceValue] = [
        "appearance": .string("System"), "appAccentColor": .string("Forest"),
        "savedColorPalettes": .string("[]"),
        "customAccentHex": .string("#456B59"), "personalizedGreetings": .bool(true), "personalizedReminders": .bool(true),
        "appFontSize": .string("Medium"), "followSystemTextSize": .bool(true),
        "reduceDecorativeMotion": .bool(false), "openingEnabled": .bool(true),
        "openingStyle": .string(OpeningStyle.sky.rawValue), "openingDuration": .number(2.5),
        "startPage": .string("Today"), "defaultPriority": .string("Medium"),
        "defaultCategory": .string("Personal"), "defaultTaskReminders": .bool(false),
        "maintenanceReminderMinutes": .number(540), "notificationSound": .bool(true),
        "quietHoursEnabled": .bool(false), "quietHoursStart": .number(1320), "quietHoursEnd": .number(420)
    ]
    func register() {
        // Existing users keep their chosen size. New installations follow iOS.
        if let domainName, let saved = defaults.persistentDomain(forName: domainName),
           saved["followSystemTextSize"] == nil && saved["appFontSize"] != nil {
            defaults.set(false, forKey: "followSystemTextSize")
        }
        defaults.register(defaults: Self.initialValues.mapValues(\.object))
    }
    var startPage: StartPage { StartPage(rawValue: defaults.string(forKey: "startPage") ?? "Today") ?? .today }
    var openingStyle: OpeningStyle { OpeningStyle(rawValue: defaults.string(forKey: "openingStyle") ?? "") ?? .sky }
    var openingDuration: Double {
        let value = defaults.object(forKey: "openingDuration") as? Double ?? 2.5
        return [2, 2.5, 3].contains(value) ? value : 2.5
    }
    var openingEnabled: Bool { defaults.object(forKey: "openingEnabled") as? Bool ?? true }
    var priority: TaskPriority { TaskPriority(rawValue: defaults.string(forKey: "defaultPriority") ?? "") ?? .medium }
    var category: String {
        let value = defaults.string(forKey: "defaultCategory") ?? "Personal"
        return Self.categories.contains(value) ? value : "Personal"
    }
    var taskReminders: Bool { defaults.bool(forKey: "defaultTaskReminders") }
    var maintenanceMinutes: Int { defaults.object(forKey: "maintenanceReminderMinutes") as? Int ?? 540 }
    var notificationValues: [String: PreferenceValue] {
        let values = portable()
        return values.filter { ["preferredName", "personalizedReminders", "notificationSound", "quietHoursEnabled", "quietHoursStart", "quietHoursEnd"].contains($0.key) }
    }
    var personalizedGreetings: Bool { defaults.object(forKey: "personalizedGreetings") as? Bool ?? true }
    var personalizedReminders: Bool { defaults.object(forKey: "personalizedReminders") as? Bool ?? true }
    var reducedMotion: Bool { defaults.bool(forKey: "reduceDecorativeMotion") }
    var lockEnabled: Bool {
        get { defaults.bool(forKey: "appLockEnabled") }
        nonmutating set { defaults.set(newValue, forKey: "appLockEnabled") }
    }
    func soundEnabled(at date: Date, calendar: Calendar = .current) -> Bool {
        guard defaults.object(forKey: "notificationSound") as? Bool ?? true else { return false }
        guard defaults.bool(forKey: "quietHoursEnabled") else { return true }
        let start = defaults.object(forKey: "quietHoursStart") as? Int ?? 1320
        let end = defaults.object(forKey: "quietHoursEnd") as? Int ?? 420
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return !(start < end ? (start..<end).contains(minute) : minute >= start || minute < end)
    }
    func portable() -> [String: PreferenceValue] {
        var values = Self.initialValues.mapValues { $0 }
        for key in Self.initialValues.keys {
            if let value = defaults.object(forKey: key), let portable = PreferenceValue(value) { values[key] = portable }
        }
        values["preferredName"] = .string(defaults.string(forKey: "preferredName") ?? "")
        return values
    }
    func apply(_ values: [String: PreferenceValue]) {
        for (key, value) in values where Self.initialValues[key] != nil || key == "preferredName" {
            defaults.set(value.object, forKey: key)
        }
        if defaults === UserDefaults.standard { AppTheme.shared.refresh() }
    }
    func reset() {
        for key in Self.initialValues.keys where key != ColorPaletteStore.preferenceKey { defaults.set(Self.initialValues[key]!.object, forKey: key) }
        if defaults === UserDefaults.standard { AppTheme.shared.refresh() }
    }
    static func validate(_ values: [String: PreferenceValue]) throws {
        for (key, value) in values {
            guard let expected = initialValues[key] ?? (key == "preferredName" ? .string("") : nil), value.sameType(as: expected) else { throw BackupError.invalid }
        }
        let choices = ["appearance": ["System", "Light", "Dark"], "appAccentColor": AppAccentColor.allCases.map(\.rawValue) + ["Custom"],
                       "appFontSize": ["Small", "Medium", "Large"], "startPage": StartPage.allCases.map(\.rawValue),
                       "openingStyle": OpeningStyle.allCases.map(\.rawValue), "defaultPriority": TaskPriority.allCases.map(\.rawValue),
                       "defaultCategory": categories]
        for (key, allowed) in choices {
            if case .string(let value)? = values[key], !allowed.contains(value) { throw BackupError.invalid }
        }
        for key in ["maintenanceReminderMinutes", "quietHoursStart", "quietHoursEnd"] {
            if case .number(let value)? = values[key], !(value >= 0 && value < 1440 && value.rounded() == value) { throw BackupError.invalid }
        }
        if case .number(let value)? = values["openingDuration"], ![2, 2.5, 3].contains(value) { throw BackupError.invalid }
        if case .string(let value)? = values[ColorPaletteStore.preferenceKey] {
            do { _ = try ColorPaletteStore.decode(value) } catch { throw BackupError.invalid }
        }
        if case .string(let value)? = values["customAccentHex"], !AppPalette.isValid(hex: value) { throw BackupError.invalid }
        if values["quietHoursStart"] == values["quietHoursEnd"], values["quietHoursStart"] != nil { throw BackupError.invalid }
    }
}

enum PreferenceValue: Codable, Equatable {
    case string(String), bool(Bool), number(Double)
    init?(_ object: Any) {
        if let value = object as? NSNumber {
            self = CFGetTypeID(value) == CFBooleanGetTypeID() ? .bool(value.boolValue) : .number(value.doubleValue)
        } else if let value = object as? String { self = .string(value) }
        else { return nil }
    }
    var object: Any {
        switch self { case .string(let v): v; case .bool(let v): v; case .number(let v): v }
    }
    func sameType(as other: Self) -> Bool {
        switch (self, other) { case (.string, .string), (.bool, .bool), (.number, .number): true; default: false }
    }
}

enum AppBrand {
    static var iconAsset: String {
        let name = UIApplication.shared.alternateIconName ?? "AppIcon"
        return name == "AppIcon" ? "OpeningIcon" : name.replacingOccurrences(of: "AppIcon", with: "OpeningIcon")
    }
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
    static func updateIcon(color: String, completion: @escaping (Error?) -> Void = { _ in }) {
        guard color != "Custom" else { return }
        let name = color == "Forest" ? nil : "AppIcon\(color)"
        guard UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name, completionHandler: completion)
    }
}

extension Notification.Name {
    static let backupRestored = Notification.Name("home-manager-backup-restored")
    static let backupRecoveryRequired = Notification.Name("home-manager-backup-recovery-required")
}

enum AppPalette {
    static func isValid(hex: String) -> Bool {
        hex.count == 7 && hex.first == "#" && hex.dropFirst().allSatisfy(\.isHexDigit) && UInt32(hex.dropFirst(), radix: 16) != nil
    }
    static func color(hex: String) -> Color {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x456B59
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    static func hex(color: Color) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int((min(1, max(0, red)) * 255).rounded()), Int((min(1, max(0, green)) * 255).rounded()), Int((min(1, max(0, blue)) * 255).rounded()))
    }
}

enum AppGreeting {
    static func text(name: String, personalized: Bool = true, date: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let greeting = (5..<12).contains(hour) ? "Good morning" : (12..<17).contains(hour) ? "Good afternoon" : "Good evening"
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return personalized && !trimmed.isEmpty ? "\(greeting), \(trimmed)" : greeting
    }
}

/// Views reading the accent (including the legacy `forest` token) observe these values.
/// Updating a color invalidates those views without replacing their navigation state.
@Observable
final class AppTheme {
    static let shared = AppTheme()
    private(set) var accentName: String
    private(set) var customHex: String
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accentName = defaults.string(forKey: "appAccentColor") ?? "Forest"
        customHex = defaults.string(forKey: "customAccentHex") ?? "#456B59"
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            // Never block the posting thread: UIKit also writes preferences while updating icons.
            DispatchQueue.main.async { [weak self] in self?.refresh() }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    var color: Color {
        accentName == "Custom" ? AppPalette.color(hex: customHex) : AppAccentColor.color(named: accentName)
    }
    func select(name: String, hex: String? = nil) {
        guard name == "Custom" || AppAccentColor(rawValue: name) != nil else { return }
        if let hex {
            guard AppPalette.isValid(hex: hex) else { return }
            if defaults.string(forKey: "customAccentHex") != hex { defaults.set(hex, forKey: "customAccentHex") }
            if customHex != hex { customHex = hex }
        }
        if defaults.string(forKey: "appAccentColor") != name { defaults.set(name, forKey: "appAccentColor") }
        if accentName != name { accentName = name }
    }
    func refresh() {
        let name = defaults.string(forKey: "appAccentColor") ?? "Forest"
        if accentName != name { accentName = name }
        let hex = defaults.string(forKey: "customAccentHex") ?? "#456B59"
        let validHex = AppPalette.isValid(hex: hex) ? hex : "#456B59"
        if customHex != validHex { customHex = validHex }
    }
}
