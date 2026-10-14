import Foundation
import Observation

struct SavedAccentColor: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var hex: String
}

struct SavedColorPalette: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var colors: [SavedAccentColor] = []
}

enum ColorPaletteError: LocalizedError {
    case invalidName, duplicateName, invalidColor, missingPalette, duplicateColor, invalidLibrary
    var errorDescription: String? {
        switch self {
        case .invalidName: "Use a name with 1 to 60 characters."
        case .duplicateName: "A palette with that name already exists."
        case .invalidColor: "Choose a color or enter a six-digit hex color, such as #1A73E8."
        case .missingPalette: "This palette is no longer available. Choose another palette."
        case .duplicateColor: "That color is already saved in this palette."
        case .invalidLibrary: "The saved color palettes could not be read."
        }
    }
}

@Observable
final class ColorPaletteStore {
    static let shared = ColorPaletteStore()
    static let preferenceKey = "savedColorPalettes"
    static let defaultID = UUID(uuidString: "E13BD822-7561-4CFD-93F4-7430FD04DE01")!
    static var emptyLibrary: [SavedColorPalette] { [.init(id: defaultID, name: "My colors")] }
    private(set) var palettes: [SavedColorPalette]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.preferenceKey) ?? "[]"
        palettes = (try? Self.decode(raw)) ?? Self.emptyLibrary
        if !defaults.bool(forKey: "didMigrateColorPalettes") {
            let hex = defaults.string(forKey: "customAccentHex") ?? "#456B59"
            if raw == "[]", AppPalette.isValid(hex: hex),
               defaults.string(forKey: "appAccentColor") == "Custom" || hex.uppercased() != "#456B59" {
                palettes[0].colors.append(.init(name: "Custom color", hex: hex.uppercased()))
                if let data = try? JSONEncoder().encode(palettes) {
                    defaults.set(String(decoding: data, as: UTF8.self), forKey: Self.preferenceKey)
                }
            }
            defaults.set(true, forKey: "didMigrateColorPalettes")
        }
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.refresh() }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    func refresh() {
        guard let decoded = try? Self.decode(defaults.string(forKey: Self.preferenceKey) ?? "[]"), decoded != palettes else { return }
        palettes = decoded
    }
    static func decode(_ raw: String) throws -> [SavedColorPalette] {
        guard let data = raw.data(using: .utf8), let decoded = try? JSONDecoder().decode([SavedColorPalette].self, from: data) else { throw ColorPaletteError.invalidLibrary }
        guard Set(decoded.map(\.id)).count == decoded.count,
              Set(decoded.map { $0.name.lowercased() }).count == decoded.count,
              decoded.allSatisfy({ validName($0.name) }) else { throw ColorPaletteError.invalidLibrary }
        let colors = decoded.flatMap(\.colors)
        guard Set(colors.map(\.id)).count == colors.count,
              colors.allSatisfy({ validName($0.name) && AppPalette.isValid(hex: $0.hex) }),
              decoded.allSatisfy({ Set($0.colors.map { $0.hex.uppercased() }).count == $0.colors.count }) else { throw ColorPaletteError.invalidLibrary }
        if decoded.isEmpty { return emptyLibrary }
        guard decoded.contains(where: { $0.id == defaultID }) else { throw ColorPaletteError.invalidLibrary }
        return decoded.map { palette in
            var palette = palette
            palette.colors = palette.colors.map { color in var color = color; color.hex = color.hex.uppercased(); return color }
            return palette
        }
    }
    // Flatten older named palettes into one reusable strip without losing saved shades.
    var savedColors: [SavedAccentColor] {
        var seen = Set<String>()
        return palettes.flatMap(\.colors).filter { seen.insert($0.hex.uppercased()).inserted }
    }
    @discardableResult
    func saveCustomColor(hex: String) throws -> SavedAccentColor {
        if let saved = savedColors.first(where: { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }) { return saved }
        return try saveColor(name: "", hex: hex, paletteID: Self.defaultID)
    }
    func removeCustomColor(hex: String) throws {
        var next = palettes
        for index in next.indices { next[index].colors.removeAll { $0.hex.caseInsensitiveCompare(hex) == .orderedSame } }
        try commit(next)
    }
    static func validName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 60 && trimmed == name
    }
    private func commit(_ next: [SavedColorPalette]) throws {
        let raw = String(decoding: try JSONEncoder().encode(next), as: UTF8.self)
        _ = try Self.decode(raw)
        defaults.set(raw, forKey: Self.preferenceKey)
        if next != palettes { palettes = next }
    }
    @discardableResult
    func savePalette(name: String, id: UUID? = nil) throws -> UUID {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.validName(name) else { throw ColorPaletteError.invalidName }
        guard !palettes.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { throw ColorPaletteError.duplicateName }
        var next = palettes
        if let id {
            guard let index = next.firstIndex(where: { $0.id == id }) else { throw ColorPaletteError.missingPalette }
            next[index].name = name
        } else { next.append(.init(name: name)) }
        try commit(next)
        return id ?? next.last!.id
    }
    func deletePalette(id: UUID) throws {
        guard id != Self.defaultID else { return }
        try commit(palettes.filter { $0.id != id })
    }
    @discardableResult
    func saveColor(name: String, hex: String, paletteID: UUID, colorID: UUID? = nil) throws -> SavedAccentColor {
        guard AppPalette.isValid(hex: hex) else { throw ColorPaletteError.invalidColor }
        var next = palettes
        guard let index = next.firstIndex(where: { $0.id == paletteID }) else { throw ColorPaletteError.missingPalette }
        let hex = hex.uppercased()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var number = next[index].colors.count + 1
        while next[index].colors.contains(where: { $0.name.caseInsensitiveCompare("Color \(number)") == .orderedSame }) { number += 1 }
        let name = trimmed.isEmpty ? "Color \(number)" : trimmed
        guard Self.validName(name) else { throw ColorPaletteError.invalidName }
        if let duplicate = next[index].colors.first(where: { $0.hex == hex && $0.id != colorID }) {
            if colorID != nil { throw ColorPaletteError.duplicateColor }
            return duplicate
        }
        let color = SavedAccentColor(id: colorID ?? UUID(), name: name, hex: hex)
        if let colorID {
            guard let position = next[index].colors.firstIndex(where: { $0.id == colorID }) else { throw ColorPaletteError.invalidColor }
            next[index].colors[position] = color
        } else { next[index].colors.append(color) }
        try commit(next)
        return color
    }
    func deleteColor(id: UUID, paletteID: UUID) throws {
        var next = palettes
        guard let index = next.firstIndex(where: { $0.id == paletteID }) else { throw ColorPaletteError.missingPalette }
        next[index].colors.removeAll { $0.id == id }
        try commit(next)
    }
}
