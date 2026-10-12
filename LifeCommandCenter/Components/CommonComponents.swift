import Charts
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SectionHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct MetricCard: View {
    let icon: String
    let color: Color
    let value: String
    let caption: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(color)
            Text(value).font(.title2.bold())
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(15).cardStyle()
    }
}

struct EmptyCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let button: String
    let action: () -> Void
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol).font(.title2).foregroundStyle(forest)
            Text(title).font(.subheadline.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(
                .center)
            Button(button, action: action).font(.subheadline.weight(.semibold)).padding(.top, 3)
        }.frame(maxWidth: .infinity).padding(22).cardStyle()
    }
}

extension View {
    func cardStyle() -> some View {
        self.background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension Double {
    var currency: String {
        formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

struct SaveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: "checkmark").font(.body.weight(.semibold))
            .accessibilityLabel("Save")
            .foregroundStyle(.green).frame(width: 40, height: 40)
            .overlay(Circle().strokeBorder(Color.green, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
            .contentShape(Circle())
    }
}

private struct FormDiscardActionKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var requestFormDiscard: () -> Void {
        get { self[FormDiscardActionKey.self] }
        set { self[FormDiscardActionKey.self] = newValue }
    }
}

struct FormCancelButton: View {
    @Environment(\.requestFormDiscard) private var requestDiscard
    var label = "Cancel"
    var body: some View {
        Button(action: requestDiscard) {
            Image(systemName: "xmark").font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .foregroundStyle(.secondary)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1))
                .contentShape(Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

private struct FormDiscardProtection: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDiscard = false
    var hasChanges: Bool

    private func requestClose() {
        if hasChanges { confirmingDiscard = true } else { dismiss() }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.requestFormDiscard, requestClose)
            .background(FormDismissAttemptObserver(hasChanges: hasChanges, onAttempt: requestClose))
            .alert("Discard your changes?", isPresented: $confirmingDiscard) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your changes haven’t been saved.")
            }
    }
}

extension View {
    func formDiscardProtection(hasChanges: Bool = true) -> some View {
        modifier(FormDiscardProtection(hasChanges: hasChanges))
    }

    func formDiscardProtection<Value: Equatable>(tracking value: Value) -> some View {
        modifier(FormChangeTracking(value: value))
    }
}

private struct FormChangeTracking<Value: Equatable>: ViewModifier {
    let value: Value
    @State private var initialValue: Value

    init(value: Value) {
        self.value = value
        _initialValue = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content.formDiscardProtection(hasChanges: value != initialValue)
    }
}

private struct FormDismissAttemptObserver: UIViewControllerRepresentable {
    var hasChanges: Bool
    var onAttempt: () -> Void

    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        var onAttempt: () -> Void = {}
        var hasChanges = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installDelegate()
        }
        func installDelegate() {
            guard var controller = view.window?.rootViewController else { return }
            while let presented = controller.presentedViewController,
                !(presented is UIAlertController)
            {
                controller = presented
            }
            guard controller.presentingViewController != nil,
                let presentation = controller.presentationController
            else { return }
            controller.isModalInPresentation = hasChanges
            presentation.delegate = self
        }
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController)
            -> Bool
        { !hasChanges }
        func presentationControllerDidAttemptToDismiss(
            _ presentationController: UIPresentationController
        ) { onAttempt() }
    }
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onAttempt = onAttempt
        controller.hasChanges = hasChanges
        DispatchQueue.main.async { [weak controller] in controller?.installDelegate() }
    }
}

// Suppress the system toolbar backdrop so form icons have just one outline.
extension ToolbarContent {
    @ToolbarContentBuilder
    func formIconBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

/// A compact quantity control that keeps the keyboard out of shopping edits.
struct QuantitySwipeControl: View {
    @Binding var value: Int
    @Environment(\.isEnabled) private var isEnabled
    @State private var initialValue: Int?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            Text(value.formatted()).font(.subheadline.monospacedDigit())
                .foregroundStyle(.white)
            Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.secondary)
        .frame(minWidth: 64, minHeight: 28)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { drag in
                    if initialValue == nil { initialValue = value }
                    value = min(999, max(1, (initialValue ?? value) - Int((drag.translation.height / 18).rounded())))
                }
                .onEnded { _ in initialValue = nil }
        )
        .allowsHitTesting(isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quantity")
        .accessibilityValue(String(value))
        .accessibilityHint("Swipe up to increase or down to decrease")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: value = min(999, value + 1)
            case .decrement: value = max(1, value - 1)
            @unknown default: break
            }
        }
    }
}
