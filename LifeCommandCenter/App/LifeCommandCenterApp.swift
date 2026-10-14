import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

@main
struct LifeCommandCenterApp: App {
    @State private var showsOpening = !ProcessInfo.processInfo.arguments.contains("-ui-testing") && AppPreferences().openingEnabled
    @State private var appLock = AppLockController()

    init() { AppPreferences().register() }

    let container: ModelContainer = {
        let schema = Schema([TaskItem.self, HomeMaintenance.self, HomeProject.self, ProjectTask.self, ProjectShoppingItem.self, SubscriptionItem.self, BillItem.self, GroceryItem.self, VisitingCard.self])
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            AppOpeningContainer(showsOpening: $showsOpening)
                .environment(appLock)
                .modelContainer(container)
        }
    }
}

private struct AppOpeningContainer: View {
    @Binding var showsOpening: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppLockController.self) private var appLock
    @Environment(\.modelContext) private var context
    @AppStorage("reduceDecorativeMotion") private var appReduceMotion = false
    @AppStorage("openingStyle") private var openingStyle = OpeningStyle.sky.rawValue
    @AppStorage("openingDuration") private var openingDuration = 2.5
    @AppStorage("followSystemTextSize") private var followSystemTextSize = false
    @State private var ready = false
    @State private var hasUnlocked = false
    @State private var restoreRevision = UUID()
    @State private var recoveryError: String?
    private var reduceMotion: Bool { systemReduceMotion || appReduceMotion || openingStyle == OpeningStyle.staticScreen.rawValue }
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("appFontSize") private var appFontSize = "Medium"
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            // Keep startup work running while the opening screen is visible.
            if ready && hasUnlocked {
                RootView().id(restoreRevision)
                    .allowsHitTesting(!showsOpening && !appLock.isLocked)
                    .accessibilityHidden(showsOpening || appLock.isLocked)
            } else {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            }
            if let recoveryError {
                VStack(spacing: 18) {
                    Text("Restore recovery").font(.title2.bold())
                    Text(recoveryError).multilineTextAlignment(.center)
                    Button("Retry recovery") { recover() }.buttonStyle(.borderedProminent)
                }.padding(32)
            }
            if showsOpening && ready && hasUnlocked && !appLock.isLocked {
                BrandedOpeningView(contentVisible: contentVisible || reduceMotion)
                    .transition(reduceMotion ? .identity : .opacity)
                    .zIndex(1)
                    .task {
                        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) {
                            contentVisible = true
                        }
                        do {
                            try await Task.sleep(for: .seconds(max(0, AppPreferences().openingDuration - (reduceMotion ? 0 : 0.25))))
                        } catch {
                            return
                        }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                            showsOpening = false
                        }
                    }
            }
        }
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        .transformEnvironment(\.dynamicTypeSize) { value in
            if !followSystemTextSize { value = AppFontSize.dynamicTypeSize(for: appFontSize) }
        }
        .background(AppPrivacyShield(controller: appLock, colorScheme: appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil,
                                     visible: appLock.isLocked || appLock.privacyCovered))
        .task {
            recover()
            if appLock.isLocked { await appLock.authenticateToUnlock() }
            hasUnlocked = !appLock.isLocked
        }
        .onChange(of: appLock.isLocked) { _, locked in if !locked { hasUnlocked = true } }
        .onChange(of: scenePhase) { _, phase in appLock.sceneChanged(phase) }
        .onReceive(NotificationCenter.default.publisher(for: .backupRecoveryRequired)) { _ in
            ready = false; recoveryError = BackupError.recovery.localizedDescription
        }
        .onReceive(NotificationCenter.default.publisher(for: .backupRestored)) { _ in
            restoreRevision = UUID()
            AppBrand.updateIcon(color: UserDefaults.standard.string(forKey: "appAccentColor") ?? "Forest")
        }
    }
    private func recover() {
        do { try BackupService().recoverIfNeeded(in: context); recoveryError = nil; ready = true }
        catch { recoveryError = error.localizedDescription; ready = false }
    }
}

struct OpeningPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("reduceDecorativeMotion") private var appReduceMotion = false
    @AppStorage("openingStyle") private var style = OpeningStyle.sky.rawValue
    @State private var visible = false
    var body: some View {
        BrandedOpeningView(contentVisible: visible)
            .task {
                let reduced = systemReduceMotion || appReduceMotion || style == OpeningStyle.staticScreen.rawValue
                withAnimation(reduced ? nil : .easeIn(duration: 0.25)) { visible = true }
                do { try await Task.sleep(for: .seconds(AppPreferences().openingDuration)) } catch { return }
                dismiss()
            }
    }
}

private struct BrandedOpeningView: View {
    let contentVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("reduceDecorativeMotion") private var appReduceMotion = false
    @AppStorage("openingStyle") private var style = OpeningStyle.sky.rawValue
    private var reduceMotion: Bool { systemReduceMotion || appReduceMotion || style == OpeningStyle.staticScreen.rawValue }
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("preferredName") private var preferredName = ""
    @AppStorage("personalizedGreetings") private var personalizedGreetings = true
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 112
    @State private var fillsLoader = false
    @State private var revealsSky = false
    @State private var timeOfDay = OpeningTimeOfDay(date: .now)

    private let starPositions: [CGPoint] = [
        CGPoint(x: -94, y: -55), CGPoint(x: -65, y: -100),
        CGPoint(x: 4, y: -112), CGPoint(x: 99, y: -24),
        CGPoint(x: -103, y: 20), CGPoint(x: 68, y: 79),
        CGPoint(x: 108, y: -99)
    ]

    private var iconGlow: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [timeOfDay.glowColor.opacity(colorScheme == .dark ? 0.55 : 0.4),
                             timeOfDay.glowColor.opacity(0.16), .clear],
                    center: .center, startRadius: 12, endRadius: 120
                ))
                .frame(width: 240, height: 240)
                .offset(y: revealsSky || reduceMotion ? -14 : 48)
                .opacity(revealsSky || reduceMotion ? 1 : 0)

            if timeOfDay == .evening {
                Image(systemName: "moon.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color.indigo.opacity(0.65))
                    .shadow(color: timeOfDay.glowColor.opacity(0.5), radius: 14)
                    .offset(x: 74, y: revealsSky || reduceMotion ? -79 : -58)
                    .opacity(revealsSky || reduceMotion ? 1 : 0)

                ForEach(starPositions.indices, id: \.self) { index in
                    Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "circle.fill")
                        .font(.system(size: index.isMultiple(of: 3) ? 10 : 3))
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.indigo)
                        .offset(x: starPositions[index].x, y: starPositions[index].y)
                        .opacity(revealsSky || reduceMotion ? 0.55 : 0)
                        .animation(reduceMotion ? nil : .easeIn(duration: 0.8).delay(Double(index) * 0.08), value: revealsSky)
                }
            }
        }
        .frame(width: 240, height: 240)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var openingIconAsset: String {
        switch UIApplication.shared.alternateIconName {
        case "AppIconBlue": "OpeningIconBlue"
        case "AppIconIndigo": "OpeningIconIndigo"
        case "AppIconPurple": "OpeningIconPurple"
        case "AppIconPink": "OpeningIconPink"
        case "AppIconOrange": "OpeningIconOrange"
        case "AppIconTeal": "OpeningIconTeal"
        default: "OpeningIcon"
        }
    }

    private var greeting: String {
        let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !personalizedGreetings || name.isEmpty ? timeOfDay.greeting : "\(timeOfDay.greeting), \(name)"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: style == OpeningStyle.sky.rawValue ? timeOfDay.backgroundColors(dark: colorScheme == .dark) : [Color(uiColor: .systemGroupedBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .background(Color(uiColor: .systemGroupedBackground))
            .ignoresSafeArea()

            GeometryReader { geometry in
                Ellipse()
                    .fill(timeOfDay.skyColor.opacity(colorScheme == .dark ? 0.04 : 0.07))
                    .frame(width: geometry.size.width * 1.8, height: geometry.size.height * 0.38)
                    .position(x: geometry.size.width * 0.3, y: geometry.size.height)
            }
            .clipped()
            .ignoresSafeArea()
            .opacity(style == OpeningStyle.sky.rawValue ? 1 : 0)
            .accessibilityHidden(true)

            VStack(spacing: 24) {
                Image(openingIconAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(iconSize, 160), height: min(iconSize, 160))
                    .clipShape(RoundedRectangle(cornerRadius: min(iconSize, 160) * 0.22))
                    .background { if style == OpeningStyle.sky.rawValue { iconGlow } }
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(greeting)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Home Manager")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                    Text("Your day, in focus.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(forest.opacity(0.12))
                        Capsule().fill(forest)
                            .frame(width: geometry.size.width * (reduceMotion ? 0.5 : fillsLoader ? 1 : 0.05))
                    }
                }
                .frame(width: 140, height: 4)
                .padding(.top, 8)
                .accessibilityHidden(true)
            }
            .padding(32)
            .opacity(contentVisible ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("branded-opening-screen")
        .task {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.4)) {
                revealsSky = true
            }
            withAnimation(reduceMotion ? nil : .linear(duration: max(0.25, AppPreferences().openingDuration - 0.25))) {
                fillsLoader = true
            }
        }
    }
}

private enum OpeningTimeOfDay {
    case morning, daylight, evening

    init(date: Date) {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: self = .morning
        case 12..<17: self = .daylight
        default: self = .evening
        }
    }

    var greeting: String {
        switch self {
        case .morning: "Good morning"
        case .daylight: "Good afternoon"
        case .evening: "Good evening"
        }
    }

    var glowColor: Color {
        switch self {
        case .morning: .orange
        case .daylight: Color(red: 1, green: 0.72, blue: 0.3)
        case .evening: Color(red: 0.52, green: 0.61, blue: 1)
        }
    }

    var skyColor: Color {
        switch self {
        case .morning: .orange
        case .daylight: .cyan
        case .evening: .indigo
        }
    }

    func backgroundColors(dark: Bool) -> [Color] {
        let base = Color(uiColor: .systemGroupedBackground)
        return [skyColor.opacity(dark ? 0.14 : 0.13), base, base]
    }
}
