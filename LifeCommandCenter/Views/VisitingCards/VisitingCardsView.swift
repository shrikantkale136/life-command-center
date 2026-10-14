import AVFoundation
import Contacts
import ContactsUI
import PhotosUI
import SwiftData
import SwiftUI
import VisionKit

struct VisitingCardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VisitingCard.updatedAt, order: .reverse) private var cards: [VisitingCard]
    @State private var search = ""
    @State private var adding = false
    @State private var deleting: VisitingCard?
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    private var filtered: [VisitingCard] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return cards.filter { term.isEmpty || $0.searchableText.localizedStandardContains(term) }
    }
    var body: some View {
        List {
            if cards.isEmpty {
                ContentUnavailableView {
                    Label("Your cards, together", systemImage: "person.crop.rectangle.stack")
                } description: {
                    Text("Scan a visiting card, import a photo, or enter contact details.")
                } actions: { Button("Add a card") { adding = true } }
                .listRowBackground(Color.clear)
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search).listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { card in
                    NavigationLink {
                        VisitingCardDetailView(card: card)
                    } label: {
                        HStack(spacing: 12) {
                            CardImageView(reference: card.frontThumbnail ?? card.backThumbnail)
                                .frame(width: 96, height: 60).clipShape(RoundedRectangle(cornerRadius: 5))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(card.displayName).font(.subheadline.weight(.semibold))
                                Text(card.supportingDetail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }.padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("visiting-card-\(card.displayName)")
                    .swipeActions(edge: .trailing) {
                        Button { deleting = card; confirmDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                        }.tint(.red)
                    }
                }
            }
        }
        .navigationTitle("Visiting Cards")
        .searchable(text: $search, prompt: "Names, companies, tags, or card text")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add visiting card")
            }
        }
        .sheet(isPresented: $adding) { VisitingCardEditor() }
        .alert("Delete card?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                guard let deleting else { return }
                do { try VisitingCardRepository(context: context).delete(deleting) }
                catch { errorMessage = error.localizedDescription }
                self.deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text("The saved card images and contact details will be permanently deleted. Exported iPhone contacts are kept.") }
        .alert("Couldn’t delete card", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "Please try again.") }
    }
}

private struct CardImageView: View {
    var reference: String?
    var data: Data? = nil
    var body: some View {
        if let data = data ?? VisitingCardImageStore().data(for: reference), let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "person.crop.rectangle").resizable().scaledToFit()
                .padding(8).foregroundStyle(.secondary)
        }
    }
}

private struct CardImagePreview: Identifiable {
    let id = UUID()
    let front: Data?
    let back: Data?
    var selectedSide = 0

    var sides: [Int] {
        [front != nil ? 0 : nil, back != nil ? 1 : nil].compactMap { $0 }
    }
}

private struct CardImageViewer: View {
    let preview: CardImagePreview
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSide: Int
    @State private var zoom: CGFloat = 1

    init(preview: CardImagePreview) {
        self.preview = preview
        _selectedSide = State(initialValue: preview.sides.contains(preview.selectedSide)
            ? preview.selectedSide : preview.sides.first ?? 0)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedSide) {
                ForEach(preview.sides, id: \.self) { side in
                    if let data = side == 0 ? preview.front : preview.back,
                       let image = UIImage(data: data) {
                        ZoomableCardImage(image: image, zoom: $zoom)
                            .padding(.bottom, 40)
                            .accessibilityLabel("\(side == 0 ? "Front" : "Back") of visiting card")
                            .tag(side)
                    } else {
                        Text("Image unavailable").foregroundStyle(.secondary).tag(side)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: preview.sides.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: selectedSide) { _, _ in zoom = 1 }
            .navigationTitle(selectedSide == 0 ? "Front" : "Back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close image")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { zoom = zoom > 1 ? 1 : 2.5 } label: {
                        Image(systemName: zoom > 1 ? "minus.magnifyingglass" : "plus.magnifyingglass")
                    }.accessibilityLabel(zoom > 1 ? "Zoom out" : "Zoom in")
                }
            }
        }
    }
}

private struct ZoomableCardImage: UIViewRepresentable {
    let image: UIImage
    @Binding var zoom: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> CardZoomScrollView {
        let scroll = CardZoomScrollView()
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.bounces = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delegate = context.coordinator
        scroll.imageView.image = image
        return scroll
    }
    func updateUIView(_ scroll: CardZoomScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updating = true
        if abs(scroll.zoomScale - zoom) > 0.01 { scroll.setZoomScale(zoom, animated: false) }
        context.coordinator.updating = false
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableCardImage
        var updating = false
        init(_ parent: ZoomableCardImage) { self.parent = parent }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? CardZoomScrollView)?.imageView
        }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? CardZoomScrollView)?.centerImage()
            if !updating { parent.zoom = scrollView.zoomScale }
        }
    }
}

private final class CardZoomScrollView: UIScrollView {
    let imageView = UIImageView()
    private var viewport = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != viewport, bounds.width > 0, bounds.height > 0,
              let image = imageView.image else { return }
        viewport = bounds.size
        let currentZoom = zoomScale
        setZoomScale(1, animated: false)
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        imageView.frame = CGRect(origin: .zero, size: CGSize(width: image.size.width * scale, height: image.size.height * scale))
        contentSize = imageView.bounds.size
        setZoomScale(currentZoom, animated: false)
        centerImage()
    }
    func centerImage() {
        contentInset = UIEdgeInsets(
            top: max(0, (bounds.height - imageView.frame.height) / 2), left: max(0, (bounds.width - imageView.frame.width) / 2),
            bottom: 0, right: 0
        )
    }
}

struct VisitingCardDetailView: View {
    @Bindable var card: VisitingCard
    @Environment(\.openURL) private var openURL
    @State private var editing = false
    @State private var exporting = false
    @State private var preview: CardImagePreview?
    @State private var selectedSide = 0
    var body: some View {
        Form {
            if card.frontImage != nil || card.backImage != nil {
                Section {
                    VStack(spacing: 3) {
                        TabView(selection: $selectedSide) {
                            if let reference = card.frontImage { cardPage("Front", reference: reference, side: 0).tag(0) }
                            if let reference = card.backImage { cardPage("Back", reference: reference, side: 1).tag(1) }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .aspectRatio(1.6, contentMode: .fit)
                        if card.frontImage != nil && card.backImage != nil {
                            HStack(spacing: 0) {
                                ForEach(0..<2) { side in
                                    Button {
                                        withAnimation { selectedSide = side }
                                    } label: {
                                        Circle()
                                            .fill(selectedSide == side ? Color.primary : Color.secondary.opacity(0.35))
                                            .frame(width: 6, height: 6)
                                            .frame(width: 18, height: 6)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(side == 0 ? "Front image" : "Back image")
                                    .accessibilityAddTraits(selectedSide == side ? .isSelected : [])
                                }
                            }
                        }
                    }
                    .onAppear { if card.frontImage == nil { selectedSide = 1 } }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            Section("Contact") {
                if !card.name.isEmpty { LabeledContent("Name", value: card.name) }
                if !card.company.isEmpty { LabeledContent("Company", value: card.company) }
                if !card.jobTitle.isEmpty { LabeledContent("Job title", value: card.jobTitle) }
                ForEach(Array(card.phones.enumerated()), id: \.offset) { _, phone in
                    Button { launch("tel", value: phone.filter { $0.isNumber || $0 == "+" }) } label: {
                        Label(phone, systemImage: "phone")
                    }.accessibilityLabel("Call \(phone)")
                }
                ForEach(Array(card.emails.enumerated()), id: \.offset) { _, email in
                    Button { launch("mailto", value: email) } label: { Label(email, systemImage: "envelope") }
                        .accessibilityLabel("Email \(email)")
                }
                if !card.website.isEmpty {
                    Button {
                        let value = card.website.contains("://") ? card.website : "https://\(card.website)"
                        if let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? "") { openURL(url) }
                    } label: { Label(card.website, systemImage: "globe") }
                }
                if !card.address.isEmpty { LabeledContent("Address", value: card.address) }
                if card.name.isEmpty && card.company.isEmpty && card.phones.isEmpty && card.emails.isEmpty && card.website.isEmpty && card.address.isEmpty {
                    Text("No contact details yet. Edit this card to add them.").foregroundStyle(.secondary)
                }
            }
            if !card.tags.isEmpty { Section("Tags") { Text(card.tags.joined(separator: ", ")) } }
            if !card.notes.isEmpty { Section("Notes") { Text(card.notes) } }
            Section {
                Button { exporting = true } label: { Label("Add to Contacts", systemImage: "person.crop.circle.badge.plus") }
                    .disabled(([card.name, card.company, card.jobTitle, card.website, card.address] + card.phones + card.emails).allSatisfy { $0.isEmpty })
                Text("Contacts are saved separately. Later edits aren’t synchronized.").font(.caption).foregroundStyle(.secondary)
            }
            if !card.frontText.isEmpty || !card.backText.isEmpty {
                DisclosureGroup("Recognized card text") { Text([card.frontText, card.backText].filter { !$0.isEmpty }.joined(separator: "\n\n")).textSelection(.enabled) }
            }
        }
        .navigationTitle(card.displayName).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: { Image(systemName: "pencil") }.accessibilityLabel("Edit card")
            }
        }
        .sheet(isPresented: $editing) { VisitingCardEditor(card: card) }
        .sheet(isPresented: $exporting) { CardContactExporter(card: card) }
        .sheet(item: $preview) { CardImageViewer(preview: $0) }
    }
    private func cardPage(_ title: String, reference: String, side: Int) -> some View {
        Button {
            preview = CardImagePreview(
                front: VisitingCardImageStore().data(for: card.frontImage),
                back: VisitingCardImageStore().data(for: card.backImage),
                selectedSide: side
            )
        } label: {
            CardImageView(reference: reference)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(title.lowercased()) image")
    }
    private func launch(_ scheme: String, value: String) {
        var components = URLComponents(); components.scheme = scheme; components.path = value
        if let url = components.url { openURL(url) }
    }
}

struct VisitingCardEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [VisitingCard]
    @State private var draft: VisitingCardDraft
    @State private var reviewing: Bool
    @State private var showingScanner = false
    @State private var showingPhotos = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var captureSide: Int? = nil
    @State private var preview: CardImagePreview?
    @State private var processing = false
    @State private var message: String?
    @State private var confirmReextract = false
    @State private var confirmDuplicate = false
    @State private var recognitionTask: Task<Void, Never>?
    @State private var recognitionID = UUID()
    let card: VisitingCard?

    init(card: VisitingCard? = nil) {
        self.card = card
        _draft = State(initialValue: VisitingCardDraft(card: card))
        _reviewing = State(initialValue: card != nil)
    }
    private var duplicates: [VisitingCard] { draft.duplicates(in: cards, excluding: card?.id) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { captureSide = nil; scan() } label: { Label("Scan Card", systemImage: "doc.viewfinder") }
                        .disabled(processing)
                    Button { captureSide = draft.hasFront ? 1 : 0; showingPhotos = true } label: { Label("Import Photo", systemImage: "photo") }
                        .disabled(processing)
                    if !reviewing {
                        Button { reviewing = true } label: { Label("Enter Manually", systemImage: "square.and.pencil") }
                    }
                } footer: { Text("Scan the front and optional back. Text is extracted on this device; review the suggested details.") }
                if processing {
                    Section { ProgressView("Reading card…").accessibilityIdentifier("card-processing") }
                }
                if draft.hasFront || draft.hasBack {
                    Section("Card images") {
                        HStack(alignment: .top, spacing: 8) {
                            imageEditor(side: 0)
                            Divider()
                            imageEditor(side: 1)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        Button("Extract details again") { confirmReextract = true }
                            .disabled(processing || (draft.frontData == nil && draft.backData == nil))
                    }
                }
                if reviewing {
                    Section("Review contact details") {
                        TextField("Name", text: $draft.name).textContentType(.name).accessibilityIdentifier("card-name")
                        TextField("Company", text: $draft.company).textContentType(.organizationName)
                        TextField("Job title", text: $draft.jobTitle).textContentType(.jobTitle)
                    }
                    contactValues("Phone numbers", values: $draft.phones, email: false)
                    contactValues("Email addresses", values: $draft.emails, email: true)
                    Section("More details") {
                        TextField("Website", text: $draft.website).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Address", text: $draft.address, axis: .vertical).textContentType(.fullStreetAddress)
                        TextField("Tags, separated by commas", text: $draft.tags).accessibilityLabel("Tags")
                        TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(3...6)
                    }
                    if !duplicates.isEmpty {
                        Section("Possible duplicate") {
                            Text("A saved card has a matching phone number or email: \(duplicates.map(\.displayName).joined(separator: ", ")). You can still save this card.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(card == nil ? "New visiting card" : "Edit card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { CardCancelButton() }.cardIconBackground()
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if duplicates.isEmpty { save() } else { confirmDuplicate = true }
                    }.buttonStyle(CardSaveButtonStyle()).disabled(!draft.canSave || processing)
                }.cardIconBackground()
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .sheet(isPresented: $showingScanner) {
                CardDocumentScanner(maxPages: captureSide == nil ? 2 : 1) { result in
                    showingScanner = false
                    switch result {
                    case .success(let images): receive(images)
                    case .failure(let error): message = error.localizedDescription
                    }
                } onCancel: { showingScanner = false }
            }
            .photosPicker(isPresented: $showingPhotos, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                processing = true
                recognitionTask?.cancel()
                let id = UUID(); recognitionID = id
                recognitionTask = Task { @MainActor in
                    defer { if recognitionID == id { processing = false; selectedPhoto = nil } }
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw CardStorageError.invalidImage }
                        guard !Task.isCancelled, recognitionID == id else { return }
                        selectedPhoto = nil
                        receive([try VisitingCardImageStore.compressed(image)])
                    } catch { if !Task.isCancelled { message = error.localizedDescription } }
                }
            }
            .sheet(item: $preview) { CardImageViewer(preview: $0) }
            .alert("Replace extracted details?", isPresented: $confirmReextract) {
                Button("Extract Again", role: .destructive) { extract(replace: true) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Name, company, job title, phone numbers, emails, website, and address will be replaced. Tags and notes are kept.") }
            .alert("Possible duplicate", isPresented: $confirmDuplicate) {
                Button("Save Anyway") { save() }
                Button("Review", role: .cancel) {}
            } message: { Text("A saved card has the same phone number or email. No cards will be merged.") }
            .alert("Visiting card", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
        .cardDiscardProtection(tracking: draft)
        .onDisappear { recognitionID = UUID(); recognitionTask?.cancel() }
    }

    @ViewBuilder private func contactValues(_ title: String, values: Binding<[CardContactValue]>, email: Bool) -> some View {
        Section(title) {
            ForEach(values) { value in
                HStack {
                    TextField(email ? "Email address" : "Phone number", text: value.value)
                        .keyboardType(email ? .emailAddress : .phonePad)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel(email ? "Email address" : "Phone number")
                    Button(role: .destructive) { values.wrappedValue.removeAll { $0.id == value.wrappedValue.id } } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless).accessibilityLabel(email ? "Remove email" : "Remove phone")
                }
            }
            Button(email ? "Add email" : "Add phone") { values.wrappedValue.append(CardContactValue()) }
        }
    }
    private func imageEditor(side: Int) -> some View {
        let data = side == 0 ? draft.frontData : draft.backData
        let reference = side == 0 ? draft.frontReference : draft.backReference
        let title = side == 0 ? "Front" : "Back"
        let hasImage = data != nil || reference != nil
        let image = (data ?? VisitingCardImageStore().data(for: reference)).flatMap { UIImage(data: $0) }
        let aspectRatio = image.map { $0.size.width / max($0.size.height, 1) } ?? 1.6
        return VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button(hasImage ? "Scan replacement" : "Scan image", systemImage: "doc.viewfinder") {
                    captureSide = side; scan()
                }
                Button(hasImage ? "Import replacement" : "Import image", systemImage: "photo") {
                    captureSide = side; showingPhotos = true
                }
                if hasImage {
                    Button("Remove image", systemImage: "trash", role: .destructive) {
                        if side == 0 { draft.frontData = nil; draft.frontReference = nil; draft.frontText = "" }
                        else { draft.backData = nil; draft.backReference = nil; draft.backText = "" }
                    }
                }
            } label: {
                HStack {
                    Text(title).font(.caption.weight(.semibold))
                    Spacer(minLength: 4)
                    Image(systemName: "ellipsis.circle")
                }.frame(minHeight: 32)
            }
            .accessibilityLabel("\(title) image options")

            if hasImage {
                Button {
                    preview = CardImagePreview(front: draft.frontData, back: draft.backData, selectedSide: side)
                } label: {
                    CardImageView(reference: reference, data: data)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(title.lowercased()) image")
            } else {
                Button {
                    captureSide = side; showingPhotos = true
                } label: {
                    Label("Add image", systemImage: "plus")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.6, contentMode: .fit)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(title.lowercased()) image")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .disabled(processing)
    }
    private func scan() {
        guard VNDocumentCameraViewController.isSupported else {
            message = "Scanning isn’t available on this device. Import a photo or enter details manually."; return
        }
        Task { @MainActor in
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            let allowed: Bool
            if status == .authorized { allowed = true }
            else if status == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
            else { allowed = false }
            if allowed { showingScanner = true }
            else { message = "Camera access is unavailable. You can enable it in iPhone Settings, import a photo, or enter details manually." }
        }
    }
    private func receive(_ images: [Data]) {
        guard let first = images.first else { return }
        let hadContact = !draft.name.isEmpty || !draft.company.isEmpty || !draft.jobTitle.isEmpty || !draft.phones.isEmpty || !draft.emails.isEmpty || !draft.website.isEmpty || !draft.address.isEmpty
        if captureSide == 1 { draft.backData = first; draft.backReference = nil; draft.backText = "" }
        else {
            draft.frontData = first; draft.frontReference = nil; draft.frontText = ""
            if captureSide == nil, images.count > 1 { draft.backData = images[1]; draft.backReference = nil; draft.backText = "" }
        }
        reviewing = true
        // Existing user corrections are kept unless explicitly replaced.
        extract(replace: !hadContact)
    }
    private func extract(replace: Bool) {
        recognitionTask?.cancel()
        let id = UUID(); recognitionID = id
        let front = draft.frontData, back = draft.backData
        let snapshot = draft
        processing = true
        recognitionTask = Task { @MainActor in
            defer { if recognitionID == id { processing = false } }
            do {
                let texts = try await VisitingCardOCR.recognize([front, back].compactMap { $0 })
                guard !Task.isCancelled, recognitionID == id else { return }
                var index = 0
                if front != nil { draft.frontText = texts[index]; index += 1 }
                if back != nil { draft.backText = texts[index] }
                if replace {
                    let fields = CardFieldExtractor.extract(texts.joined(separator: "\n"))
                    // Don’t replace fields that were edited while recognition was running.
                    draft.apply(fields, preservingEditsSince: snapshot)
                }
                if texts.allSatisfy({ $0.isEmpty }) { message = "No readable text was found. Your image is kept; enter details manually or try another scan." }
                else if !replace { message = "The card text was updated. Your contact details were kept. Use Extract details again if you want to replace them." }
            } catch {
                guard !Task.isCancelled, recognitionID == id else { return }
                message = "Text couldn’t be extracted. Your image is kept, and you can enter details manually."
            }
        }
    }
    private func save() {
        do { _ = try VisitingCardRepository(context: context).save(draft, card: card); dismiss() }
        catch { message = "Couldn’t save this card. \(error.localizedDescription)" }
    }
}

private enum CardCaptureError: LocalizedError {
    case tooManyPages(Int)
    var errorDescription: String? {
        if case .tooManyPages(let limit) = self {
            return "Capture up to \(limit) image\(limit == 1 ? "" : "s") for this card. Please scan again."
        }
        return nil
    }
}

private struct CardDocumentScanner: UIViewControllerRepresentable {
    let maxPages: Int
    let completion: (Result<[Data], Error>) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController(); controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: CardDocumentScanner
        init(_ parent: CardDocumentScanner) { self.parent = parent }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            do {
                guard scan.pageCount > 0 else { parent.onCancel(); return }
                guard scan.pageCount <= parent.maxPages else { throw CardCaptureError.tooManyPages(parent.maxPages) }
                let images = try (0..<scan.pageCount).map { try VisitingCardImageStore.compressed(scan.imageOfPage(at: $0)) }
                parent.completion(.success(images))
            } catch { parent.completion(.failure(error)) }
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { parent.onCancel() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { parent.completion(.failure(error)) }
    }
}

private struct CardContactExporter: UIViewControllerRepresentable {
    let card: VisitingCard
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator { dismiss() } }
    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        contact.givenName = card.name
        contact.organizationName = card.company; contact.jobTitle = card.jobTitle
        contact.phoneNumbers = card.phones.map { CNLabeledValue(label: CNLabelOther, value: CNPhoneNumber(stringValue: $0)) }
        contact.emailAddresses = card.emails.map { CNLabeledValue(label: CNLabelOther, value: $0 as NSString) }
        if !card.website.isEmpty { contact.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: card.website as NSString)] }
        if !card.address.isEmpty {
            let address = CNMutablePostalAddress(); address.street = card.address
            contact.postalAddresses = [CNLabeledValue(label: CNLabelOther, value: address)]
        }
        let editor = CNContactViewController(forNewContact: contact)
        editor.delegate = context.coordinator
        return UINavigationController(rootViewController: editor)
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let done: () -> Void
        init(done: @escaping () -> Void) { self.done = done }
        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) { done() }
    }
}

private struct CardSaveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: "checkmark").font(.body.weight(.semibold))
            .foregroundStyle(.green).frame(width: 40, height: 40)
            .overlay(Circle().strokeBorder(.green, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
            .contentShape(Circle()).accessibilityLabel("Save")
    }
}
private struct CardDiscardActionKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
private extension EnvironmentValues {
    var discardCard: () -> Void {
        get { self[CardDiscardActionKey.self] }
        set { self[CardDiscardActionKey.self] = newValue }
    }
}
private struct CardCancelButton: View {
    @Environment(\.discardCard) private var discard
    var body: some View {
        Button(action: discard) {
            Image(systemName: "xmark").font(.body.weight(.semibold))
                .foregroundStyle(.secondary).frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1))
                .contentShape(Circle())
        }.buttonStyle(.plain).accessibilityLabel("Cancel")
    }
}
private extension ToolbarContent {
    @ToolbarContentBuilder func cardIconBackground() -> some ToolbarContent {
        if #available(iOS 26, *) { self.sharedBackgroundVisibility(.hidden) } else { self }
    }
}
private extension View {
    func cardDiscardProtection<Value: Equatable>(tracking value: Value) -> some View {
        modifier(CardDiscardProtection(value: value))
    }
}
private struct CardDiscardProtection<Value: Equatable>: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let value: Value
    @State private var initial: Value
    @State private var warning = false
    init(value: Value) { self.value = value; _initial = State(initialValue: value) }
    private func close() { if value != initial { warning = true } else { dismiss() } }
    func body(content: Content) -> some View {
        content.environment(\.discardCard, close)
            .background(CardDismissObserver(hasChanges: value != initial, onAttempt: close))
            .alert("Discard your changes?", isPresented: $warning) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: { Text("Your card hasn’t been saved.") }
    }
}
private struct CardDismissObserver: UIViewControllerRepresentable {
    var hasChanges: Bool
    var onAttempt: () -> Void
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.hasChanges = hasChanges; controller.onAttempt = onAttempt
        DispatchQueue.main.async { [weak controller] in controller?.install() }
    }
    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        var hasChanges = false
        var onAttempt: (() -> Void)?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); install() }
        func install() {
            // Find our containing sheet, rather than a photo/scanner sheet presented above it.
            var owner: UIViewController? = self
            while let current = owner, current.presentingViewController == nil { owner = current.parent }
            guard let owner, let presentation = owner.presentationController else { return }
            owner.isModalInPresentation = hasChanges
            presentation.delegate = self
        }
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool { !hasChanges }
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { onAttempt?() }
    }
}
