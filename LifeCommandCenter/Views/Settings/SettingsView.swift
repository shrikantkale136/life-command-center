import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct MoreView: View {
    let add: () -> Void
    var body: some View { NavigationStack { List {
        Section { NavigationLink { CalendarView(addEvent: add, editTask: { _ in }) } label: { Label("Calendar", systemImage: "calendar") }; NavigationLink { SearchView() } label: { Label("Search everything", systemImage: "magnifyingglass") }; NavigationLink { StatisticsView() } label: { Label("Statistics", systemImage: "chart.bar.fill") } }
        Section("Create") { Button(action: add) { Label("Quick add", systemImage: "plus.circle") } }
        Section("Preferences") { NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }; Label("Your data stays on this device", systemImage: "lock.shield").foregroundStyle(.secondary) }
    }.navigationTitle("More") } }
}

struct SearchView: View {
    @Query private var tasks: [TaskItem]; @Query private var projects: [HomeProject]; @Query private var maint: [HomeMaintenance]; @Query private var subs: [SubscriptionItem]; @Query private var bills: [BillItem]; @Query private var groceries: [GroceryItem]
    @State private var query = ""
    var body: some View { List { ForEach(tasks.filter { matches($0.title, $0.detail) }) { Label($0.title, systemImage: "checkmark.circle") }; ForEach(projects.filter { matches($0.name, $0.detail) }) { Label($0.name, systemImage: "hammer") }; ForEach(maint.filter { matches($0.name, $0.detail, $0.notes) }) { Label($0.name, systemImage: "wrench.and.screwdriver") }; ForEach(subs.filter { matches($0.name, $0.category, $0.notes) }) { Label($0.name, systemImage: "arrow.clockwise") }; ForEach(bills.filter { matches($0.name, $0.notes) }) { Label($0.name, systemImage: "doc.text") }; ForEach(groceries.filter { matches($0.name, $0.category) }) { Label($0.name, systemImage: "basket") } }.searchable(text: $query, prompt: "Tasks, home, groceries…").navigationTitle("Search") }
    private func matches(_ values: String...) -> Bool { !query.isEmpty && values.contains { $0.localizedCaseInsensitiveContains(query) } }
}

struct StatisticsView: View {
    @Query private var tasks: [TaskItem]; @Query private var projects: [HomeProject]; @Query private var maintenance: [HomeMaintenance]; @Query private var subs: [SubscriptionItem]
    var body: some View { List { Section("Tasks") { LabeledContent("Completed this week", value: "\(tasks.filter { $0.isComplete && ($0.completedAt ?? .distantPast) > Calendar.current.date(byAdding: .day, value: -7, to: .now)! }.count)"); LabeledContent("Overdue", value: "\(tasks.filter { !$0.isComplete && $0.dueDate < Calendar.current.startOfDay(for: .now) }.count)"); LabeledContent("Completion", value: "\(tasks.isEmpty ? 0 : Int(Double(tasks.filter(\.isComplete).count) / Double(tasks.count) * 100))%") }; Section("Home") { LabeledContent("Active projects", value: "\(projects.filter { $0.status == "In Progress" }.count)"); LabeledContent("Maintenance overdue", value: "\(maintenance.filter { $0.nextDue < .now }.count)") }; Section("Subscriptions") { LabeledContent("Monthly cost", value: subs.reduce(0) { $0 + $1.monthlyCost }.currency); LabeledContent("Active subscriptions", value: "\(subs.count)") } }.navigationTitle("Statistics") }
}

struct SettingsView: View {
    @AppStorage("defaultPriority") private var defaultPriority = "Medium"
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("preferredName") private var preferredName = ""
    @AppStorage("appAccentColor") private var accentColor = "Forest"
    @AppStorage("appFontSize") private var fontSize = "Medium"

    var body: some View {
        NavigationStack {
            Form {
            Section("Your profile") {
                TextField("What should Home Manager call you?", text: $preferredName)
                    .textContentType(.givenName).autocorrectionDisabled()
            }
            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("App color").font(.subheadline)
                    HStack(spacing: 0) {
                        ForEach(AppAccentColor.allCases) { option in
                            Button { accentColor = option.rawValue } label: {
                                Circle().fill(option.color)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if accentColor == option.rawValue {
                                            Image(systemName: "checkmark").font(.caption.weight(.bold))
                                                .foregroundStyle(option == .orange ? Color.black : Color.white)
                                        }
                                    }
                                    .padding(6)
                                    .overlay(Circle().strokeBorder(accentColor == option.rawValue ? option.color.opacity(0.45) : .clear, lineWidth: 2).padding(1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(option.rawValue) app color\(accentColor == option.rawValue ? ", selected" : "")")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Text("The Home Screen icon follows your selected color.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Picker("Text size", selection: $fontSize) {
                    Text("Small").tag("Small")
                    Text("Medium").tag("Medium")
                    Text("Large").tag("Large")
                }
                .pickerStyle(.segmented)
            }
            Section("Defaults") {
                Picker("Task priority", selection: $defaultPriority) {
                    ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            }
            Section("Notifications") {
                Text("Reminders are delivered locally on this device and can use your preferred name.").font(.footnote).foregroundStyle(.secondary)
                Button("Request notification access") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
            }
            Section("Data") { Text("Your information is stored locally. Cloud sync can be added later.").font(.footnote).foregroundStyle(.secondary) }
            Section("About") { LabeledContent("Home Manager", value: "Version 1.0") }
            Section("More tools") {
                NavigationLink { SearchView() } label: { Label("Search everything", systemImage: "magnifyingglass") }
                NavigationLink { StatisticsView() } label: { Label("Statistics", systemImage: "chart.bar.fill") }
            }
            }
            .navigationTitle("Settings")
        }
        .onAppear { updateHomeScreenIcon(for: accentColor) }
        .onChange(of: accentColor) { oldValue, newValue in
            updateHomeScreenIcon(for: newValue, revertingTo: oldValue)
        }
    }

    private func updateHomeScreenIcon(for color: String, revertingTo previousColor: String? = nil) {
        let iconName = color == "Forest" ? nil : "AppIcon\(color)"
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != iconName else { return }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            guard error != nil, let previousColor else { return }
            DispatchQueue.main.async { accentColor = previousColor }
        }
    }
}
