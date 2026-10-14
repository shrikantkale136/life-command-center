import Foundation
import SwiftData

@Model final class VisitingCard {
    var id: UUID = UUID()
    var name = ""
    var company = ""
    var jobTitle = ""
    var phones: [String] = []
    var emails: [String] = []
    var website = ""
    var address = ""
    var tags: [String] = []
    var notes = ""
    var frontText = ""
    var backText = ""
    var frontImage: String?
    var backImage: String?
    var frontThumbnail: String?
    var backThumbnail: String?
    var createdAt = Date.now
    var updatedAt = Date.now

    init(name: String = "") { self.name = name }

    var displayName: String {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        if !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return company }
        return "Untitled card"
    }
    var supportingDetail: String {
        [company == displayName ? "" : company, jobTitle, emails.first ?? "", phones.first ?? ""]
            .first { !$0.isEmpty } ?? "Visiting card"
    }
    var searchableText: String {
        ([name, company, jobTitle, website, address, notes, frontText, backText] + phones + emails + tags)
            .joined(separator: " ")
    }
    var imageFiles: [String] {
        [frontImage, backImage, frontThumbnail, backThumbnail].compactMap { $0 }
    }
}

struct CardContactValue: Identifiable, Equatable {
    var id = UUID()
    var value = ""
    init(_ value: String = "") { self.value = value }
}

struct VisitingCardDraft: Equatable {
    var name = ""
    var company = ""
    var jobTitle = ""
    var phones: [CardContactValue] = []
    var emails: [CardContactValue] = []
    var website = ""
    var address = ""
    var tags = ""
    var notes = ""
    var frontText = ""
    var backText = ""
    var frontData: Data?
    var backData: Data?
    var frontReference: String?
    var backReference: String?

    init(card: VisitingCard? = nil, images: VisitingCardImageStore = .init()) {
        guard let card else { return }
        name = card.name; company = card.company; jobTitle = card.jobTitle
        phones = card.phones.map(CardContactValue.init)
        emails = card.emails.map(CardContactValue.init)
        website = card.website; address = card.address
        tags = card.tags.joined(separator: ", "); notes = card.notes
        frontText = card.frontText; backText = card.backText
        frontReference = card.frontImage; backReference = card.backImage
        frontData = images.data(for: card.frontImage)
        backData = images.data(for: card.backImage)
    }
    var hasFront: Bool { frontData != nil || frontReference != nil }
    var hasBack: Bool { backData != nil || backReference != nil }
    var canSave: Bool {
        hasFront || hasBack || !([name, company, jobTitle, website, address, tags, notes]
            + phones.map(\.value) + emails.map(\.value))
            .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    var phoneValues: [String] { Self.clean(phones.map(\.value)) }
    var emailValues: [String] { Self.clean(emails.map(\.value)) }
    var tagValues: [String] { Self.clean(tags.components(separatedBy: ",")) }
    static func clean(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
    func apply(to card: VisitingCard) {
        card.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        card.company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        card.jobTitle = jobTitle; card.phones = phoneValues; card.emails = emailValues
        card.website = website; card.address = address; card.tags = tagValues; card.notes = notes
        card.frontText = frontText; card.backText = backText
        card.updatedAt = .now
    }
    mutating func apply(_ fields: CardExtractedFields, preservingEditsSince snapshot: VisitingCardDraft) {
        if name == snapshot.name { name = fields.name }
        if company == snapshot.company { company = fields.company }
        if jobTitle == snapshot.jobTitle { jobTitle = fields.jobTitle }
        if phones == snapshot.phones { phones = fields.phones.map(CardContactValue.init) }
        if emails == snapshot.emails { emails = fields.emails.map(CardContactValue.init) }
        if website == snapshot.website { website = fields.website }
        if address == snapshot.address { address = fields.address }
    }
    func duplicates(in cards: [VisitingCard], excluding id: UUID?) -> [VisitingCard] {
        let phones = Set(phoneValues.map(CardFieldExtractor.normalizedPhone).filter { !$0.isEmpty })
        let emails = Set(emailValues.map { $0.lowercased() })
        return cards.filter { card in
            card.id != id && (!phones.isDisjoint(with: card.phones.map(CardFieldExtractor.normalizedPhone))
                || !emails.isDisjoint(with: card.emails.map { $0.lowercased() }))
        }
    }
}
