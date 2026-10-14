import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

struct SettingsRow: View {
    let title: String
    let icon: String
    var value: String?
    init(_ title: String, icon: String, value: String? = nil) { self.title = title; self.icon = icon; self.value = value }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(forest)
                .frame(width: 24, height: 24).background(forest.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
            Text(title).font(.subheadline).foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let value { Text(value).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
        }
    }
}

struct ProfileSettingsView: View {
    @AppStorage("preferredName") private var name = ""
    @AppStorage("personalizedGreetings") private var greetings = true
    @AppStorage("personalizedReminders") private var reminders = true
    var body: some View {
        Form {
            Section("Preferred name") { TextField("Your name", text: $name).textContentType(.givenName).autocorrectionDisabled().accessibilityIdentifier("preferred-name") }
            Section("Make it personal") {
                Toggle("Use my name in greetings", isOn: $greetings)
                Toggle("Use my name in reminders", isOn: $reminders)
            }
            Section("Your greeting") {
                Text(AppGreeting.text(name: name, personalized: greetings)).font(.title3).fontDesign(.rounded)
            }
            Section("Reminder preview") {
                Text(reminders && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Hey \(name.trimmingCharacters(in: .whitespacesAndNewlines))! 👋" : "Coming up").font(.headline)
                Text("Your next task is coming up.").foregroundStyle(.secondary)
            }
        }.navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("appAccentColor") private var accent = "Forest"
    @AppStorage("appFontSize") private var fontSize = "Medium"
    @AppStorage("followSystemTextSize") private var followsSystem = false
    @AppStorage("openingEnabled") private var openingEnabled = true
    @AppStorage("startPage") private var startPage = "Today"
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
                    .pickerStyle(.menu).accessibilityIdentifier("theme-picker")
            }
            Section("Personalize") {
                NavigationLink { PreferredColorSettingsView() } label: {
                    HStack {
                        SettingsRow("Text color", icon: "circle.lefthalf.filled")
                        Circle().fill(AppTheme.shared.color).frame(width: 18, height: 18)
                            .overlay { Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1) }
                            .accessibilityLabel("Selected color")
                    }
                }.accessibilityIdentifier("settings-color")
                NavigationLink { TextSizeSettingsView() } label: { SettingsRow("Text size", icon: "textformat.size", value: followsSystem ? "System" : fontSize) }.accessibilityIdentifier("settings-text-size")
                NavigationLink { OpeningSettingsView() } label: { SettingsRow("Opening screen", icon: "sparkles", value: openingEnabled ? "On" : "Off") }.accessibilityIdentifier("settings-opening")
                NavigationLink { StartPageSettingsView() } label: { SettingsRow("Start page", icon: "house", value: startPage) }.accessibilityIdentifier("settings-start-page")
            }
            Section("Live preview") {
                HStack(spacing: 16) {
                    Image(accent == "Custom" ? AppBrand.iconAsset : accent == "Forest" ? "OpeningIcon" : "OpeningIcon\(accent)")
                        .resizable().frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 13)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your day, in focus.").font(.headline)
                        Label("Ready for today", systemImage: "checkmark.circle.fill").foregroundStyle(AppAccentColor.color(named: accent)).font(.subheadline)
                    }
                }.padding(.vertical, 8)
            }
        }.navigationTitle("Appearance").navigationBarTitleDisplayMode(.inline)
    }
}

struct OpeningSettingsView: View {
    @AppStorage("openingEnabled") private var enabled = true
    @AppStorage("openingStyle") private var style = OpeningStyle.sky.rawValue
    @AppStorage("openingDuration") private var duration = 2.5
    @State private var preview = false
    var body: some View {
        Form {
            Section { Toggle("Show opening screen", isOn: $enabled) }
            Section("Opening screen") {
                Picker("Style", selection: $style) { ForEach(OpeningStyle.allCases) { Text($0.rawValue).tag($0.rawValue) } }
                Picker("Duration", selection: $duration) { ForEach([2.0, 2.5, 3.0], id: \.self) { Text("\($0, specifier: "%g") seconds").tag($0) } }
                Button("Preview opening screen", systemImage: "play.circle") { preview = true }
            }
            Section { Text("Shown on fresh launches. Your app icon and greeting are included in every style. Reduce Motion uses a static presentation.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Opening screen").navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $preview) { OpeningPreviewView() }
    }
}

struct StartPageSettingsView: View {
    @AppStorage("startPage") private var selection = "Today"
    var body: some View {
        Form {
            Section { Picker("Start page", selection: $selection) { ForEach(StartPage.allCases) { Text($0.rawValue).tag($0.rawValue) } }.pickerStyle(.inline) }
            Section { Text("Used when the app starts. Returning from the background keeps your current page.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Start page").navigationBarTitleDisplayMode(.inline)
    }
}

struct AccessibilitySettingsView: View {
    @AppStorage("reduceDecorativeMotion") private var reducesMotion = false
    var body: some View {
        Form {
            Section { NavigationLink("Text size") { TextSizeSettingsView() } }
            Section { Toggle("Reduce decorative motion", isOn: $reducesMotion) } footer: {
                Text("The system’s Reduce Motion setting is always respected. This also disables opening-screen and decorative animations.")
            }
        }.navigationTitle("Accessibility").navigationBarTitleDisplayMode(.inline)
    }
}

struct TextSizeSettingsView: View {
    @AppStorage("followSystemTextSize") private var followsSystem = false
    @AppStorage("appFontSize") private var size = "Medium"
    var body: some View {
        Form {
            Section {
                Toggle("Follow system text size", isOn: $followsSystem)
                Picker("Font size", selection: $size) {
                    ForEach(["Small", "Medium", "Large"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented).disabled(followsSystem).accessibilityIdentifier("font-size-picker")
            } footer: { Text("Turn off Follow system text size to choose Small, Medium, or Large.") }
            Section("Preview") {
                Text("Your day, in focus.").font(.headline)
                Text("Keep tasks, groceries, and home plans comfortably readable.").foregroundStyle(.secondary)
            }
        }.navigationTitle("Text size").navigationBarTitleDisplayMode(.inline)
    }
}

struct TaskDefaultsSettingsView: View {
    @AppStorage("defaultPriority") private var priority = "Medium"
    @AppStorage("defaultCategory") private var category = "Personal"
    @AppStorage("defaultTaskReminders") private var reminders = false
    var body: some View {
        Form {
            Section {
                Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0.rawValue) } }.accessibilityIdentifier("default-priority")
                Picker("Category", selection: $category) { ForEach(AppPreferences.categories, id: \.self) { Text($0) } }.accessibilityIdentifier("default-category")
                Toggle("Remind me by default", isOn: $reminders)
            } footer: { Text("Used for new tasks and reminders. Chores use the Home category. Existing items stay as they are; task reminders use the selected due time.") }
        }.navigationTitle("Task defaults").navigationBarTitleDisplayMode(.inline)
    }
}

extension UNAuthorizationStatus {
    var settingsTitle: String {
        switch self { case .authorized, .provisional, .ephemeral: "Enabled"; case .denied: "Not enabled"; case .notDetermined: "Not set up"; @unknown default: "Unavailable" }
    }
}

struct ReminderSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage("maintenanceReminderMinutes") private var maintenanceMinutes = 540
    @AppStorage("notificationSound") private var sound = true
    @AppStorage("quietHoursEnabled") private var quietEnabled = false
    @AppStorage("quietHoursStart") private var quietStart = 1320
    @AppStorage("quietHoursEnd") private var quietEnd = 420
    @State private var draftStart = 1320
    @State private var draftEnd = 420
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var message: String?
    var body: some View {
        Form {
            Section("Permission") {
                LabeledContent("Notifications", value: status.settingsTitle)
                if status == .notDetermined {
                    Button("Enable notifications") { Task {
                        do { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]); await refresh() }
                        catch { message = error.localizedDescription }
                    } }
                } else {
                    Button("Open iOS Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                }
            }
            Section {
                DatePicker("Default maintenance time", selection: minuteBinding($maintenanceMinutes), displayedComponents: .hourAndMinute)
                Toggle("Notification sound", isOn: $sound)
            } footer: { Text("The default time applies to new maintenance items without an explicit time. Existing reminders keep their scheduled time.") }
            Section {
                Toggle("Quiet hours", isOn: $quietEnabled)
                if quietEnabled {
                    DatePicker("Start", selection: minuteBinding($draftStart), displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: minuteBinding($draftEnd), displayedComponents: .hourAndMinute)
                    if draftStart == draftEnd { Text("Choose different start and end times.").font(.footnote).foregroundStyle(.red) }
                    Button("Save quiet hours") { quietStart = draftStart; quietEnd = draftEnd }
                        .disabled(draftStart == draftEnd || (draftStart == quietStart && draftEnd == quietEnd))
                }
            } header: { Text("Quiet hours") } footer: { Text("Reminders still arrive on time during quiet hours, without sound. Banners follow your iOS settings. Times use your device’s local time zone.") }
        }.navigationTitle("Reminders").navigationBarTitleDisplayMode(.inline)
            .task { draftStart = quietStart; draftEnd = quietEnd; await refresh() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
            .alert("Notifications", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
    private func refresh() async { status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }
}

private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
    Binding(get: {
        Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now) ?? .now
    }, set: { minutes.wrappedValue = Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) })
}

struct AppLockSettingsView: View {
    @Environment(AppLockController.self) private var controller
    @State private var enabled = false
    var body: some View {
        Form {
            Section {
                Toggle("Require device authentication", isOn: Binding(get: { enabled }, set: { desired in Task { await controller.setEnabled(desired); enabled = controller.enabled } }))
                    .disabled(controller.isAuthenticating)
            } footer: { Text("Use Face ID, Touch ID, or your device passcode on launch and every return from the background. App-switcher previews are hidden. Authentication is required to change this setting.") }
            if let error = controller.errorMessage { Section { Text(error).font(.footnote).foregroundStyle(.secondary) } }
        }.navigationTitle("App lock").navigationBarTitleDisplayMode(.inline).onAppear { enabled = controller.enabled }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(AppBrand.iconAsset).resizable().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) { Text("Home Manager").font(.headline); Text("Version \(AppBrand.version) (\(AppBrand.build))").foregroundStyle(.secondary).font(.subheadline) }
                }.padding(.vertical, 8)
            }
            Section("Your data") {
                Text("Your records and visiting-card images are stored on this device. Home Manager does not run a cloud sync service.")
                Text("Exported backups go to a location you choose in Files, which may include a cloud storage provider. Device backups are controlled by iOS.").foregroundStyle(.secondary)
            }
        }.navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpSettingsView: View {
    @State private var draft: FeedbackKind?
    enum FeedbackKind: String, Identifiable { case problem = "Report a problem", suggestion = "Suggest a feature"; var id: String { rawValue } }
    var body: some View {
        List {
            Section {
                NavigationLink("Getting started") { GettingStartedView() }
                Button("Report a problem") { draft = .problem }
                Button("Suggest a feature") { draft = .suggestion }
            } footer: { Text("Review your feedback, then choose where to share it. No personal records are included automatically.") }
        }.navigationTitle("Help & feedback").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $draft) { FeedbackDraftView(kind: $0) }
    }
}

private struct GettingStartedView: View {
    var body: some View {
        List {
            Section("Plan your day") { Text("Today brings tasks and scheduled items together. Use Quick Add to create a task, reminder, bill, or other item. Open Calendar to review your schedule.") }
            Section("Manage your home") { Text("Track maintenance and projects in Home. Projects can include checklists and shopping estimates. Choose reminder times when adding maintenance.") }
            Section("Groceries & money") { Text("Stage groceries for your next trip and mark purchases as you shop. Money keeps subscriptions and bills together.") }
            Section("Visiting Cards") { Text("Open Visiting Cards from Settings to scan, import, or enter contact details. Review recognized details before saving or exporting to Contacts.") }
            Section("Keep a backup") { Text("Export a password-protected backup from Settings. Keep the password somewhere safe: Home Manager cannot recover it. Restoring replaces the current records after you confirm.") }
        }.navigationTitle("Getting started").navigationBarTitleDisplayMode(.inline)
    }
}

private struct FeedbackDraftView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var shares = false
    init(kind: HelpSettingsView.FeedbackKind) {
        _text = State(initialValue: "\(kind.rawValue)\n\nDescribe your feedback here:\n\n\nHome Manager \(AppBrand.version) (\(AppBrand.build))\niOS \(UIDevice.current.systemVersion)")
    }
    var body: some View {
        NavigationStack {
            Form { Section("Review before sharing") { TextEditor(text: $text).frame(minHeight: 240).accessibilityLabel("Feedback draft") } }
                .navigationTitle("Feedback").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Share") { shares = true }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
                .sheet(isPresented: $shares) { FeedbackShareSheet(text: text) }
        }
    }
}

private struct FeedbackShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [text], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
