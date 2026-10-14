import LocalAuthentication
import Observation
import SwiftUI
import UIKit

@MainActor
protocol DeviceAuthenticating {
    func authenticate(reason: String) async throws -> Bool
}

@MainActor
struct DeviceAuthenticator: DeviceAuthenticating {
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? NSError(domain: LAError.errorDomain, code: LAError.passcodeNotSet.rawValue)
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}

@Observable @MainActor
final class AppLockController {
    private let preferences: AppPreferences
    private let authenticator: any DeviceAuthenticating
    private(set) var enabled: Bool
    var isLocked: Bool
    var privacyCovered = false
    var isAuthenticating = false
    var errorMessage: String?
    private var didBackground = false
    init(preferences: AppPreferences = .init(), authenticator: (any DeviceAuthenticating)? = nil) {
        self.preferences = preferences
        self.authenticator = authenticator ?? DeviceAuthenticator()
        enabled = preferences.lockEnabled
        isLocked = preferences.lockEnabled
    }
    func authenticateToUnlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            if try await authenticator.authenticate(reason: "Unlock Home Manager") {
                isLocked = false
                errorMessage = nil
            }
        } catch { errorMessage = "Authentication didn’t complete. Try again to unlock." }
    }
    func setEnabled(_ enabled: Bool) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            if try await authenticator.authenticate(reason: enabled ? "Enable Home Manager app lock" : "Disable Home Manager app lock") {
                preferences.lockEnabled = enabled
                self.enabled = enabled
                isLocked = false
                errorMessage = nil
            }
        } catch { errorMessage = "App lock wasn’t changed. Set up a device passcode and try again." }
    }
    func sceneChanged(_ phase: ScenePhase) {
        switch phase {
        case .inactive: privacyCovered = enabled
        case .background:
            privacyCovered = enabled
            didBackground = true; isLocked = enabled
        case .active:
            privacyCovered = false
            if didBackground {
                didBackground = false
                if enabled { isLocked = true; Task { await authenticateToUnlock() } }
            }
        @unknown default: break
        }
    }
}

private struct PrivacyCover: View {
    let controller: AppLockController
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 22) {
                Image(AppBrand.iconAsset).resizable().frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 17)).accessibilityHidden(true)
                Text("Home Manager").font(.title2.bold()).fontDesign(.rounded)
                if controller.isLocked && !controller.privacyCovered {
                    Text("Unlock to continue").foregroundStyle(.secondary)
                    if let message = controller.errorMessage { Text(message).font(.footnote).multilineTextAlignment(.center) }
                    Button(controller.isAuthenticating ? "Authenticating…" : "Unlock", systemImage: "lock.open") {
                        Task { await controller.authenticateToUnlock() }
                    }.buttonStyle(.borderedProminent).disabled(controller.isAuthenticating)
                        .accessibilityIdentifier("unlock-app")
                }
            }.padding(32)
        }.tint(forest)
    }
}

/// A separate window also covers presented editors, importers, and share sheets.
struct AppPrivacyShield: UIViewRepresentable {
    let controller: AppLockController
    let colorScheme: ColorScheme?
    let visible: Bool
    func makeUIView(context: Context) -> ShieldAnchor { ShieldAnchor() }
    func updateUIView(_ view: ShieldAnchor, context: Context) {
        view.controller = controller
        view.scheme = colorScheme
        view.updateShield()
    }
    static func dismantleUIView(_ view: ShieldAnchor, coordinator: ()) { view.shield?.isHidden = true; view.shield = nil }
    final class ShieldAnchor: UIView {
        var controller: AppLockController?
        var scheme: ColorScheme?
        var shield: UIWindow?
        private var observers: [NSObjectProtocol] = []
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil && observers.isEmpty {
                for (name, phase) in [(UIApplication.willResignActiveNotification, ScenePhase.inactive),
                                      (UIApplication.didEnterBackgroundNotification, ScenePhase.background),
                                      (UIApplication.didBecomeActiveNotification, ScenePhase.active)] {
                    observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.controller?.sceneChanged(phase)
                            self?.updateShield()
                        }
                    })
                }
            }
            updateShield()
        }
        deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
        func updateShield() {
            guard let scene = window?.windowScene, let controller else { return }
            let visible = controller.privacyCovered || controller.isLocked
            guard visible else { shield?.isHidden = true; return }
            if shield == nil {
                let overlay = UIWindow(windowScene: scene)
                overlay.windowLevel = .alert + 1
                overlay.accessibilityViewIsModal = true
                shield = overlay
            }
            shield?.rootViewController = UIHostingController(rootView: PrivacyCover(controller: controller).preferredColorScheme(scheme))
            shield?.isHidden = false
        }
    }
}
