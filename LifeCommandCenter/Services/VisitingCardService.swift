import Foundation
import SwiftData
import UIKit
import Vision

struct CardExtractedFields: Equatable, Sendable {
    var name = ""
    var company = ""
    var jobTitle = ""
    var phones: [String] = []
    var emails: [String] = []
    var website = ""
    var address = ""
}

enum CardFieldExtractor {
    static func normalizedPhone(_ value: String) -> String {
        value.filter(\.isNumber)
    }
    static func extract(_ text: String) -> CardExtractedFields {
        var fields = CardExtractedFields()
        let ns = text as NSString
        func matches(_ pattern: String) -> [String] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
            return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
                .map { ns.substring(with: $0.range) }
        }
        fields.emails = VisitingCardDraft.clean(matches("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"))
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
            | NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.address.rawValue) {
            let detected = detector.matches(in: text, range: NSRange(location: 0, length: ns.length))
            fields.phones = VisitingCardDraft.clean(detected.compactMap(\.phoneNumber))
            fields.website = detected.compactMap(\.url).first {
                ["https", "http"].contains($0.scheme?.lowercased() ?? "")
            }?.absoluteString ?? ""
            fields.address = detected.first { $0.resultType == .address }.map { ns.substring(with: $0.range) } ?? ""
        }
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let roles = ["manager", "director", "engineer", "founder", "president", "consultant", "designer", "plumber", "contractor", "sales", "owner", "ceo", "officer", "specialist"]
        let companyWords = [" inc", " llc", " ltd", "limited", "company", "corporation", "services", "solutions", "studio", "group"]
        let candidates = lines.filter { line in
            !line.contains("@") && !line.contains("://") && !line.lowercased().contains("www.")
                && line.filter(\.isNumber).count < 3 && line.count < 80
        }
        fields.jobTitle = candidates.first { line in roles.contains { line.lowercased().contains($0) } } ?? ""
        fields.company = candidates.first { line in companyWords.contains { line.lowercased().contains($0) } } ?? ""
        fields.name = candidates.first { line in
            line != fields.jobTitle && line != fields.company && line.split(separator: " ").count <= 5
        } ?? ""
        if fields.company.isEmpty {
            fields.company = candidates.first { $0 != fields.name && $0 != fields.jobTitle } ?? ""
        }
        return fields
    }
}

enum VisitingCardOCR {
    static func recognize(_ images: [Data]) async throws -> [String] {
        let task = Task.detached(priority: .userInitiated) {
            try images.map { data in
                try Task.checkCancellation()
                guard let image = UIImage(data: data)?.cgImage else { throw CardStorageError.invalidImage }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["en-US"]
                request.usesLanguageCorrection = true
                try VNImageRequestHandler(cgImage: image).perform([request])
                return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            }
        }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }
}

enum CardStorageError: LocalizedError {
    case invalidImage, emptyCard
    var errorDescription: String? {
        switch self {
        case .invalidImage: "This image couldn’t be read. Try a different photo or scan."
        case .emptyCard: "Add a card image or contact details before saving."
        }
    }
}

struct VisitingCardImageStore {
    let directory: URL
    init(directory: URL? = nil) {
        if let directory { self.directory = directory }
        else if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            self.directory = FileManager.default.temporaryDirectory.appendingPathComponent("VisitingCards-\(ProcessInfo.processInfo.processIdentifier)")
        } else {
            self.directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("VisitingCards", isDirectory: true)
        }
    }
    private func url(_ reference: String) -> URL? {
        guard !reference.hasPrefix("/"), !reference.components(separatedBy: "/").contains("..") else { return nil }
        return directory.appendingPathComponent(reference)
    }
    func data(for reference: String?) -> Data? {
        guard let reference, let url = url(reference) else { return nil }
        return try? Data(contentsOf: url)
    }
    static func compressed(_ image: UIImage, maxDimension: CGFloat = 2000) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else { throw CardStorageError.invalidImage }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.88) else { throw CardStorageError.invalidImage }
        return data
    }
    func write(_ data: Data) throws -> (image: String, thumbnail: String) {
        guard let image = UIImage(data: data) else { throw CardStorageError.invalidImage }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let original = "\(id).jpg", thumbnail = "\(id)-thumb.jpg"
        do {
            try Self.compressed(image).write(to: directory.appendingPathComponent(original), options: [.atomic, .completeFileProtection])
            try Self.compressed(image, maxDimension: 240).write(to: directory.appendingPathComponent(thumbnail), options: [.atomic, .completeFileProtection])
            return (original, thumbnail)
        } catch {
            remove([original, thumbnail]); throw error
        }
    }
    func remove(_ references: [String]) {
        for reference in references { if let url = url(reference) { try? FileManager.default.removeItem(at: url) } }
    }
}

@MainActor
struct VisitingCardRepository {
    let context: ModelContext
    var images = VisitingCardImageStore()
    func save(_ draft: VisitingCardDraft, card existing: VisitingCard? = nil) throws -> VisitingCard {
        guard draft.canSave else { throw CardStorageError.emptyCard }
        let card = existing ?? VisitingCard()
        let previous = VisitingCardDraft(card: card, images: images)
        let oldFiles = card.imageFiles
        let oldFront = card.frontImage, oldBack = card.backImage
        let oldFrontThumb = card.frontThumbnail, oldBackThumb = card.backThumbnail
        let oldUpdatedAt = card.updatedAt
        var createdFiles: [String] = []
        do {
            let front = try draft.frontData.map { try images.write($0) }
            if let front { createdFiles += [front.image, front.thumbnail] }
            let back = try draft.backData.map { try images.write($0) }
            if let back { createdFiles += [back.image, back.thumbnail] }
            draft.apply(to: card)
            card.frontImage = front?.image ?? draft.frontReference
            card.backImage = back?.image ?? draft.backReference
            card.frontThumbnail = front?.thumbnail ?? (draft.frontReference == oldFront ? oldFrontThumb : nil)
            card.backThumbnail = back?.thumbnail ?? (draft.backReference == oldBack ? oldBackThumb : nil)
            if existing == nil { context.insert(card) }
            try context.save()
            images.remove(oldFiles.filter { !card.imageFiles.contains($0) })
            return card
        } catch {
            if existing == nil { if card.modelContext != nil { context.delete(card) } }
            else {
                previous.apply(to: card); card.frontImage = oldFront; card.backImage = oldBack
                card.frontThumbnail = oldFrontThumb; card.backThumbnail = oldBackThumb; card.updatedAt = oldUpdatedAt
            }
            images.remove(createdFiles)
            throw error
        }
    }
    func removeOrphanedImages() throws {
        let references = Set(try context.fetch(FetchDescriptor<VisitingCard>()).flatMap(\.imageFiles))
        guard FileManager.default.fileExists(atPath: images.directory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: images.directory, includingPropertiesForKeys: nil)
        images.remove(files.filter { $0.pathExtension == "jpg" && !references.contains($0.lastPathComponent) }.map(\.lastPathComponent))
    }
    func delete(_ card: VisitingCard) throws {
        let files = card.imageFiles
        context.delete(card)
        do { try context.save() }
        catch { context.rollback(); throw error }
        images.remove(files)
    }
}
