import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct MoreView: View {
    let add: () -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CalendarView(addEvent: add, editTask: { _ in })
                    } label: {
                        Label("Calendar", systemImage: "calendar")
                    }
                    NavigationLink {
                        SearchView()
                    } label: {
                        Label(
                            "Search everything",
                            systemImage: "magnifyingglass"
                        )
                    }
                    NavigationLink {
                        StatisticsView()
                    } label: {
                        Label("Statistics", systemImage: "chart.bar.fill")
                    }
                }
                Section("Create") {
                    Button(action: add) {
                        Label("Quick add", systemImage: "plus.circle")
                    }
                }
                Section("Preferences") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    Label(
                        "Your data stays on this device",
                        systemImage: "lock.shield"
                    ).foregroundStyle(.secondary)
                }
            }.navigationTitle("More")
        }
    }
}

struct SearchView: View {
    @Query private var tasks: [TaskItem]
    @Query private var projects: [HomeProject]
    @Query private var maint: [HomeMaintenance]
    @Query private var subs: [SubscriptionItem]
    @Query private var bills: [BillItem]
    @Query private var groceries: [GroceryItem]
    @State private var query = ""
    var body: some View {
        List {
            ForEach(tasks.filter { matches($0.title, $0.detail) }) {
                Label($0.title, systemImage: "checkmark.circle")
            }
            ForEach(projects.filter { matches($0.name, $0.detail) }) {
                Label($0.name, systemImage: "hammer")
            }
            ForEach(maint.filter { matches($0.name, $0.detail, $0.notes) }) {
                Label($0.name, systemImage: "wrench.and.screwdriver")
            }
            ForEach(subs.filter { matches($0.name, $0.category, $0.notes) }) {
                Label($0.name, systemImage: "arrow.clockwise")
            }
            ForEach(bills.filter { matches($0.name, $0.notes) }) {
                Label($0.name, systemImage: "doc.text")
            }
            ForEach(groceries.filter { matches($0.name, $0.category) }) {
                Label($0.name, systemImage: "basket")
            }
        }.searchable(text: $query, prompt: "Tasks, home, groceries…")
            .navigationTitle("Search")
    }
    private func matches(_ values: String...) -> Bool {
        !query.isEmpty
            && values.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

struct StatisticsView: View {
    @Query private var tasks: [TaskItem]
    @Query private var projects: [HomeProject]
    @Query private var maintenance: [HomeMaintenance]
    @Query private var subs: [SubscriptionItem]
    var body: some View {
        List {
            Section("Tasks") {
                LabeledContent(
                    "Completed this week",
                    value:
                        "\(tasks.filter { $0.isComplete && ($0.completedAt ?? .distantPast) > Calendar.current.date(byAdding: .day, value: -7, to: .now)! }.count)"
                )
                LabeledContent(
                    "Overdue",
                    value:
                        "\(tasks.filter { !$0.isComplete && $0.dueDate < Calendar.current.startOfDay(for: .now) }.count)"
                )
                LabeledContent(
                    "Completion",
                    value:
                        "\(tasks.isEmpty ? 0 : Int(Double(tasks.filter(\.isComplete).count) / Double(tasks.count) * 100))%"
                )
            }
            Section("Home") {
                LabeledContent(
                    "Active projects",
                    value:
                        "\(projects.filter { $0.status == "In Progress" }.count)"
                )
                LabeledContent(
                    "Maintenance reminders",
                    value: "\(maintenance.filter { $0.reminderEnabled }.count)"
                )
            }
            Section("Subscriptions") {
                LabeledContent(
                    "Monthly cost",
                    value: subs.reduce(0) { $0 + $1.monthlyCost }.currency
                )
                LabeledContent("Active subscriptions", value: "\(subs.count)")
            }
        }.navigationTitle("Statistics")
    }
}

struct SettingsView: View {
    @Environment(AppLockController.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("preferredName") private var name = ""
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("appAccentColor") private var accentColor = "Forest"
    @AppStorage("personalizedGreetings") private var personalizedGreetings = true
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmsReset = false
    @State private var iconError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { ProfileSettingsView() } label: {
                        HStack(spacing: 12) {
                            Text(initials).font(.title2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.5)
                                .frame(width: 40, height: 40)
                                .foregroundStyle(forest).background(forest.opacity(0.1), in: Circle()).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName).font(.headline)
                                Text(AppGreeting.text(name: name, personalized: personalizedGreetings)).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 2)
                    }.accessibilityIdentifier("settings-profile")
                }
                Section("Personalization") {
                    NavigationLink { AppearanceSettingsView() } label: { SettingsRow("Appearance", icon: "paintpalette", value: appearance) }.accessibilityIdentifier("settings-appearance")
                    NavigationLink { AccessibilitySettingsView() } label: { SettingsRow("Accessibility", icon: "accessibility") }.accessibilityIdentifier("settings-accessibility")
                }
                Section("Tasks & reminders") {
                    NavigationLink { TaskDefaultsSettingsView() } label: { SettingsRow("Task defaults", icon: "checkmark.circle") }.accessibilityIdentifier("settings-task-defaults")
                    NavigationLink { ReminderSettingsView() } label: { SettingsRow("Reminders", icon: "bell", value: notificationStatus.settingsTitle) }.accessibilityIdentifier("settings-reminders")
                }
                Section("Privacy & data") {
                    NavigationLink { AppLockSettingsView() } label: { SettingsRow("App lock", icon: "lock", value: appLock.enabled ? "On" : "Off") }.accessibilityIdentifier("settings-app-lock")
                    NavigationLink { BackupSettingsView() } label: { SettingsRow("Backup & restore", icon: "externaldrive") }.accessibilityIdentifier("settings-backup")
                }
                Section("Tools") {
                    NavigationLink { VisitingCardsView() } label: { SettingsRow("Visiting Cards", icon: "person.crop.rectangle.stack") }
                        .accessibilityIdentifier("visiting-cards-library")
                    NavigationLink { SearchView() } label: { SettingsRow("Search everything", icon: "magnifyingglass") }
                    NavigationLink { StatisticsView() } label: { SettingsRow("Statistics", icon: "chart.bar") }
                }
                Section("Help & about") {
                    NavigationLink { HelpSettingsView() } label: { SettingsRow("Help & feedback", icon: "questionmark.circle") }.accessibilityIdentifier("settings-help")
                    NavigationLink { AboutSettingsView() } label: { SettingsRow("About Home Manager", icon: "info.circle") }.accessibilityIdentifier("settings-about")
                }
                Section {
                    Button("Reset preferences", role: .destructive) { confirmsReset = true }
                } footer: { Text("Your records stay on this device. Export a backup to keep a separate copy.") }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(12)
            .environment(\.defaultMinListRowHeight, 44)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Reset preferences?", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Reset preferences", role: .destructive) { AppPreferences().reset() }
            } message: { Text("Appearance, task defaults, reminders, and opening preferences will reset. Your profile name, saved colors, records, images, backup history, and app lock will remain.") }
            .alert("App icon couldn’t change", isPresented: Binding(get: { iconError != nil }, set: { if !$0 { iconError = nil } })) {
                Button("OK") { iconError = nil }
            } message: { Text(iconError ?? "") }
        }
        .task { await refreshNotifications(); AppBrand.updateIcon(color: accentColor) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refreshNotifications() } } }
        .onChange(of: accentColor) { old, new in
            AppTheme.shared.refresh()
            AppBrand.updateIcon(color: new) { error in
                if let error { DispatchQueue.main.async { accentColor = old; AppTheme.shared.refresh(); iconError = error.localizedDescription } }
            }
        }
    }
    private var displayName: String { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your profile" : name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var initials: String {
        let parts = name.split(whereSeparator: \.isWhitespace)
        return parts.isEmpty ? "HM" : parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
    private func refreshNotifications() async { notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }
}
