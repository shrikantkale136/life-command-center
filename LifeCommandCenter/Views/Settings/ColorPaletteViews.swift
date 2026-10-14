import SwiftUI
import UIKit

struct PreferredColorSettingsView: View {
    @AppStorage("appAccentColor") private var accent = "Forest"
    @AppStorage("customAccentHex") private var customHex = "#456B59"
    private let library = ColorPaletteStore.shared
    @State private var showingPicker = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                    ForEach(AppAccentColor.allCases) { option in
                        Button { AppTheme.shared.select(name: option.rawValue) } label: {
                            ColorDot(color: option.color, selected: accent == option.rawValue)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("\(option.rawValue) app color")
                        .accessibilityAddTraits(accent == option.rawValue ? .isSelected : [])
                    }
                    ForEach(library.savedColors) { color in
                        let selected = accent == "Custom" && customHex.caseInsensitiveCompare(color.hex) == .orderedSame
                        Button { AppTheme.shared.select(name: "Custom", hex: color.hex) } label: {
                            ColorDot(color: AppPalette.color(hex: color.hex), selected: selected)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Custom color \(color.hex)")
                        .accessibilityIdentifier("saved-color-\(color.hex)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .contextMenu {
                            Button("Remove color", systemImage: "trash", role: .destructive) {
                                do { try library.removeCustomColor(hex: color.hex) }
                                catch { message = error.localizedDescription }
                            }
                        }
                    }
                    Button { showingPicker = true } label: {
                        Image(systemName: "plus").font(.body.weight(.medium))
                            .frame(width: 34, height: 34)
                            .background(.quaternary, in: Circle())
                            .overlay { Circle().strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3])) }
                            .frame(width: 44, height: 44).contentShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add custom color")
                    .accessibilityIdentifier("add-custom-color")
                }
                .padding(.vertical, 4)
            } header: { Text("Text color") } footer: {
                Text("Tap + to add a color, then tap its dot to use it. Touch and hold a custom color to remove it.")
            }
            Section("Preview") {
                Label("Your text color", systemImage: "checkmark.circle.fill").foregroundStyle(forest)
                Text("Changes apply immediately across the app.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Text color").navigationBarTitleDisplayMode(.inline)
        .background {
            CustomColorPicker(isPresented: showingPicker, initialColor: AppTheme.shared.color) { hex in
                save(hex: hex)
            } onFinish: {
                showingPicker = false
            }
            .frame(width: 0, height: 0)
        }
        .alert("Couldn’t save color", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }
    private func save(hex: String) {
        do { try library.saveCustomColor(hex: hex) }
        catch { message = error.localizedDescription }
    }
}

private struct ColorDot: View {
    let color: Color
    let selected: Bool
    var body: some View {
        Circle().fill(color).frame(width: 34, height: 34)
            .overlay { Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1) }
            .overlay {
                if selected {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.primary)
                        .padding(4).background(.background, in: Circle())
                }
            }
            .frame(width: 44, height: 44).contentShape(Circle())
    }
}

private struct CustomColorPicker: UIViewControllerRepresentable {
    let isPresented: Bool
    let initialColor: Color
    let onAdd: (String) -> Void
    let onFinish: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil, !context.coordinator.presenting else { return }
        let picker = PaletteColorPicker()
        picker.onAdd = { [weak coordinator = context.coordinator, weak picker] in
            guard let picker else { return }
            picker.view.endEditing(true)
            coordinator?.parent.onAdd(AppPalette.hex(color: Color(uiColor: picker.selectedColor)))
            picker.dismiss(animated: true) { coordinator?.finish() }
        }
        picker.supportsAlpha = false
        picker.selectedColor = UIColor(initialColor)
        picker.delegate = context.coordinator
        picker.view.accessibilityIdentifier = "custom-color-picker"
        context.coordinator.presenting = true
        host.present(picker, animated: true)
        picker.presentationController?.delegate = context.coordinator
    }
    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
        var parent: CustomColorPicker
        var presenting = false
        init(parent: CustomColorPicker) { self.parent = parent }
        func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            (viewController as? PaletteColorPicker)?.updateAddButton()
        }
        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            finish()
        }
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            finish()
        }
        func finish() {
            guard presenting else { return }
            presenting = false
            parent.onFinish()
        }
    }
}

private final class PaletteColorPicker: UIColorPickerViewController {
    var onAdd: (() -> Void)?
    private let addButton = UIButton(type: .system)
    override func viewDidLoad() {
        super.viewDidLoad()
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.accessibilityIdentifier = "save-custom-color"
        addButton.addTarget(self, action: #selector(addColor), for: .touchUpInside)
        view.addSubview(addButton)
        NSLayoutConstraint.activate([
            addButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            addButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        updateAddButton()
    }
    func updateAddButton() {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "Add color"
        configuration.image = UIImage(systemName: "circle.fill")
        configuration.imagePadding = 10
        configuration.imageColorTransformer = UIConfigurationColorTransformer { [selectedColor] _ in selectedColor }
        configuration.cornerStyle = .large
        addButton.configuration = configuration
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.bringSubviewToFront(addButton)
    }
    @objc private func addColor() { onAdd?() }
}
