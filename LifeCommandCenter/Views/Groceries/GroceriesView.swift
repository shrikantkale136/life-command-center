import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

enum GroceryCategoryCatalog {
    static let builtIn = ["Produce", "Dairy & Eggs", "Bakery", "Meat & Seafood", "Pantry", "Frozen", "Household", "Other"]

    static func custom(from stored: String) -> [String] {
        guard let data = stored.data(using: .utf8), let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        var seen = Set(builtIn.map { $0.lowercased() })
        return values.compactMap { value in
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, seen.insert(cleaned.lowercased()).inserted else { return nil }
            return cleaned
        }
    }

    static func encode(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values), let value = String(data: data, encoding: .utf8) else { return "[]" }
        return value
    }

    static func ordered(_ available: [String], by stored: String) -> [String] {
        guard let data = stored.data(using: .utf8), let saved = try? JSONDecoder().decode([String].self, from: data) else { return available }
        let availableSet = Set(available)
        let savedAvailable = saved.filter { availableSet.contains($0) }
        return savedAvailable + available.filter { !savedAvailable.contains($0) }
    }

    static func decoded(_ stored: String) -> [String] {
        guard let data = stored.data(using: .utf8), let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values
    }
}

struct GroceriesView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("groceryCustomCategoriesJSON") private var customCategoriesJSON = "[]"
    @AppStorage("groceryHiddenBuiltInCategoriesJSON") private var hiddenBuiltInCategoriesJSON = "[]"
    @AppStorage("groceryCategoryOrderJSON") private var categoryOrderJSON = "[]"
    let items: [GroceryItem]
    let add: () -> Void
    @State private var showingCatalog = false
    @State private var showingNewGrocery = false
    @State private var search = ""
    @State private var category = "All"
    @State private var shoppingCategory = "All"
    @State private var shoppingSort = "Name"
    @State private var managingCategories = false
    @State private var showUncheckedValidation = false
    @State private var itemToRemove: GroceryItem?
    @State private var showingRemoveConfirmation = false
    @State private var showShoppingCelebration = false
    @State private var itemBeingEdited: GroceryItem?

    private var availableCategories: [String] {
        let hidden = Set(GroceryCategoryCatalog.decoded(hiddenBuiltInCategoriesJSON))
        let categories = GroceryCategoryCatalog.builtIn.filter { $0 == "Other" || !hidden.contains($0) } + GroceryCategoryCatalog.custom(from: customCategoriesJSON)
        return categories.filter { $0 != "Other" } + ["Other"]
    }
    private var orderedCategories: [String] {
        let categories = availableCategories.filter { $0 != "Other" }
        return GroceryCategoryCatalog.ordered(categories, by: categoryOrderJSON) + ["Other"]
    }
    private var categories: [String] { ["All"] + orderedCategories }
    private var allTripItems: [GroceryItem] { items.filter(\.isStaged) }
    private var tripItems: [GroceryItem] {
        let filtered = allTripItems.filter { shoppingCategory == "All" || $0.category == shoppingCategory }
        return filtered.sorted { lhs, rhs in
            if shoppingSort == "Category" {
                let order = Dictionary(uniqueKeysWithValues: orderedCategories.enumerated().map { ($1, $0) })
                let leftOrder = order[lhs.category] ?? Int.max
                let rightOrder = order[rhs.category] ?? Int.max
                if leftOrder != rightOrder { return leftOrder < rightOrder }
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    private var catalogItems: [GroceryItem] {
        items.filter { item in
            (category == "All" || item.category == category) &&
            (search.isEmpty || item.name.localizedCaseInsensitiveContains(search) || item.category.localizedCaseInsensitiveContains(search))
        }.sorted { lhs, rhs in
            if category == "All" {
                let order = Dictionary(uniqueKeysWithValues: orderedCategories.enumerated().map { ($1, $0) })
                let leftOrder = order[lhs.category] ?? Int.max
                let rightOrder = order[rhs.category] ?? Int.max
                if leftOrder != rightOrder { return leftOrder < rightOrder }
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR REUSABLE LIST").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(forest)
                        Text("Groceries").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                        Text("Keep your staples here. Tap to add them to today's shopping.").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 10)

                    VStack(alignment: .leading, spacing: 13) {
                        HStack(alignment: .center, spacing: 8) {
                            SectionHeading(title: "Shopping list", subtitle: allTripItems.isEmpty ? "Ready when you are" : "\(allTripItems.count) \(allTripItems.count == 1 ? "item" : "items")")
                            Spacer(minLength: 4)
                            if !allTripItems.isEmpty {
                                Menu {
                                    Button("All categories") { shoppingCategory = "All" }
                                    ForEach(orderedCategories, id: \.self) { option in Button(option) { shoppingCategory = option } }
                                } label: {
                                    Image(systemName: shoppingCategory == "All" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                        .font(.title3).foregroundStyle(forest).frame(width: 40, height: 40)
                                        .background(forest.opacity(0.08), in: Circle())
                                }.accessibilityLabel(shoppingCategory == "All" ? "Filter shopping items by category" : "Filter shopping items by \(shoppingCategory)")
                                Menu {
                                    Button("Name") { shoppingSort = "Name" }
                                    Button("Category") { shoppingSort = "Category" }
                                } label: {
                                    Image(systemName: "arrow.up.arrow.down.circle")
                                        .font(.title3).foregroundStyle(shoppingSort == "Category" ? forest : .secondary)
                                        .frame(width: 40, height: 40)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                                }.accessibilityLabel("Sort shopping items by \(shoppingSort.lowercased())")
                            }
                        }
                        if allTripItems.isEmpty {
                            EmptyCard(symbol: "basket", title: "Your shopping list is clear", subtitle: "Add items from your catalog below. They'll stay saved for next time.", button: "Add grocery", action: { showingCatalog = true })
                        } else {
                            if tripItems.isEmpty {
                                Text("No items in this category yet.").font(.subheadline).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading).cardStyle()
                            } else { VStack(spacing: 0) {
                                ForEach(tripItems) { item in
                                    HStack(spacing: 12) {
                                        Button { item.isPurchased.toggle() } label: {
                                            Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle").font(.title2)
                                                .foregroundStyle(item.isPurchased ? forest : forest.opacity(0.65))
                                        }.buttonStyle(.plain).accessibilityLabel(item.isPurchased ? "Mark \(item.name) not purchased" : "Mark \(item.name) purchased")
                                        Button { item.isPurchased.toggle() } label: {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.name).font(.subheadline.weight(.semibold)).strikethrough(item.isPurchased)
                                                    .foregroundStyle(item.isPurchased ? Color.secondary : showUncheckedValidation ? Color.red : Color.primary)
                                                Text(item.category).font(.caption)
                                                    .foregroundStyle(showUncheckedValidation && !item.isPurchased ? Color.red.opacity(0.8) : Color.secondary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(item.isPurchased ? "Mark \(item.name) not purchased" : "Mark \(item.name) purchased")
                                        Spacer()
                                        HStack(spacing: 12) {
                                            Button {
                                                if item.quantity <= 1 {
                                                    itemToRemove = item
                                                    showingRemoveConfirmation = true
                                                } else {
                                                    item.quantity -= 1
                                                }
                                            } label: { Image(systemName: "minus.circle").foregroundStyle(.secondary) }
                                                .buttonStyle(.plain).accessibilityLabel(item.quantity <= 1 ? "Remove \(item.name) from today's shopping" : "Decrease \(item.name) quantity")
                                            Text("\(item.quantity)").font(.subheadline.monospacedDigit().weight(.semibold)).frame(minWidth: 18)
                                            Button { item.quantity += 1 } label: { Image(systemName: "plus.circle").foregroundStyle(forest) }
                                                .buttonStyle(.plain).accessibilityLabel("Increase \(item.name) quantity")
                                        }.disabled(item.isPurchased)
                                    }
                                    .padding(14)
                                    .padding(.horizontal, 6)
                                    if item.id != tripItems.last?.id { Divider().padding(.leading, 50) }
                                }
                            }.cardStyle() }
                            if showUncheckedValidation && allTripItems.contains(where: { !$0.isPurchased }) {
                                Label("Check off every item before finishing shopping.", systemImage: "exclamationmark.circle.fill")
                                    .font(.caption.weight(.medium)).foregroundStyle(.red)
                            }
                            Text("Tap the circle to mark an item purchased. It stays here until you finish the trip.")
                                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 3)
                            HStack {
                                Spacer()
                                Button(action: completeShopping) {
                                    Label("Done Shopping", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 11)
                                }.buttonStyle(.borderedProminent).tint(forest)
                            }
                        }
                    }

                }.padding(.horizontal, 20).padding(.bottom, 40)
            }.background(canvas)
                .navigationTitle("Groceries")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingCatalog = true } label: { Image(systemName: "plus") }.accessibilityLabel("Open Master Catalog") } }
                .sheet(isPresented: $showingCatalog) {
                    NavigationStack {
                        ScrollView { catalogContent.padding(20) }
                            .background(canvas)
                            .navigationTitle("Master Catalog")
                            .navigationBarTitleDisplayMode(.inline)
                            .searchable(text: $search, prompt: "Search your catalog")
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) { Button("Done") { showingCatalog = false } }
                                ToolbarItem(placement: .topBarTrailing) { Button { showingNewGrocery = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add grocery item") }
                            }
                            .sheet(isPresented: $managingCategories) {
                                ManageGroceryCategoriesView(categories: orderedCategories, existingCategories: GroceryCategoryCatalog.builtIn + availableCategories, orderJSON: $categoryOrderJSON, createCategory: createCategory, deleteCategory: deleteCategory, editCategory: renameCategory)
                            }
                            .sheet(item: $itemBeingEdited) { item in GroceryCatalogItemEditor(item: item, categories: orderedCategories) }
                            .sheet(isPresented: $showingNewGrocery) {
                                NavigationStack { Form { GroceryCreateFields(done: { showingNewGrocery = false }) }.navigationTitle("Add Grocery").navigationBarTitleDisplayMode(.inline) }
                            }
                    }
                }
                .alert("Remove grocery?", isPresented: $showingRemoveConfirmation) {
                    Button("Remove", role: .destructive) {
                        if let item = itemToRemove {
                            item.isStaged = false
                            item.isPurchased = false
                            item.quantity = 1
                        }
                        itemToRemove = nil
                    }
                    Button("Cancel", role: .cancel) { itemToRemove = nil }
                } message: {
                    Text("This removes the item from Today’s Shopping. It will stay in your Master catalog.")
                }
                .overlay {
                    if showShoppingCelebration {
                        ShoppingCompletionCelebration()
                            .transition(.opacity)
                            .zIndex(2)
                    }
                }
                .sensoryFeedback(.success, trigger: showShoppingCelebration)
        }
    }

    private var catalogContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                SectionHeading(title: "Master catalog", subtitle: "Reusable favorites, ready to stage")
                Spacer(minLength: 4)
                Button { managingCategories = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(forest).frame(width: 40, height: 40).background(forest.opacity(0.08), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("Manage grocery categories")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { option in
                        Button { category = option } label: {
                            Text(option).font(.caption.weight(.semibold)).padding(.horizontal, 13).padding(.vertical, 8)
                                .foregroundStyle(category == option ? Color.white : Color.primary)
                                .background(category == option ? forest : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
            if catalogItems.isEmpty {
                EmptyCard(symbol: "list.bullet.rectangle", title: search.isEmpty ? "No catalog items here" : "No matches", subtitle: "Add an item once and keep it for future shopping trips.", button: "Add grocery", action: { showingNewGrocery = true })
            } else {
                VStack(spacing: 0) {
                    ForEach(catalogItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: categorySymbol(item.category)).font(.subheadline).foregroundStyle(forest).frame(width: 36, height: 36).background(forest.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 3) { Text(item.name).font(.subheadline.weight(.semibold)); Text(item.category).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            if item.isStaged { Label("On trip", systemImage: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(forest) }
                            else {
                                Button { stage(item) } label: { Label("Add", systemImage: "plus").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8).foregroundStyle(forest).background(forest.opacity(0.1), in: Capsule()) }.buttonStyle(.plain)
                            }
                        }.padding(13).contentShape(Rectangle())
                            .onTapGesture { if !item.isStaged { stage(item) } }
                            .contextMenu {
                                Button("Edit item", systemImage: "pencil") { itemBeingEdited = item }
                                if !item.isStaged { Button("Add to today's shopping", systemImage: "plus") { stage(item) } }
                                Button("Delete from catalog", systemImage: "trash", role: .destructive) { context.delete(item) }
                            }
                        if item.id != catalogItems.last?.id { Divider().padding(.leading, 62) }
                    }
                }.cardStyle()
            }
        }
    }

    private func stage(_ item: GroceryItem) { item.quantity = 1; item.isPurchased = false; item.isStaged = true }
    private func createCategory(_ name: String) {
        var custom = GroceryCategoryCatalog.custom(from: customCategoriesJSON)
        custom.append(name)
        customCategoriesJSON = GroceryCategoryCatalog.encode(custom)
        categoryOrderJSON = GroceryCategoryCatalog.encode(orderedCategories)
        category = name
    }
    private func deleteCategory(_ name: String) {
        guard name != "Other" else { return }
        items.filter { $0.category == name }.forEach { $0.category = "Other" }
        if GroceryCategoryCatalog.builtIn.contains(name) {
            var hidden = GroceryCategoryCatalog.decoded(hiddenBuiltInCategoriesJSON)
            if !hidden.contains(name) { hidden.append(name) }
            hiddenBuiltInCategoriesJSON = GroceryCategoryCatalog.encode(hidden)
        } else {
            let custom = GroceryCategoryCatalog.custom(from: customCategoriesJSON).filter { $0 != name }
            customCategoriesJSON = GroceryCategoryCatalog.encode(custom)
        }
        categoryOrderJSON = GroceryCategoryCatalog.encode(orderedCategories.filter { $0 != name })
        if category == name { category = "All" }
        if shoppingCategory == name { shoppingCategory = "All" }
    }
    private func renameCategory(_ oldName: String, to newName: String) {
        guard oldName != "Other", oldName.localizedCaseInsensitiveCompare(newName) != .orderedSame else { return }
        let savedOrder = orderedCategories
        items.filter { $0.category == oldName }.forEach { $0.category = newName }
        if GroceryCategoryCatalog.builtIn.contains(oldName) {
            var hidden = GroceryCategoryCatalog.decoded(hiddenBuiltInCategoriesJSON)
            if !hidden.contains(oldName) { hidden.append(oldName) }
            hiddenBuiltInCategoriesJSON = GroceryCategoryCatalog.encode(hidden)
            var custom = GroceryCategoryCatalog.custom(from: customCategoriesJSON)
            custom.append(newName)
            customCategoriesJSON = GroceryCategoryCatalog.encode(custom)
        } else {
            let custom = GroceryCategoryCatalog.custom(from: customCategoriesJSON).map { $0 == oldName ? newName : $0 }
            customCategoriesJSON = GroceryCategoryCatalog.encode(custom)
        }
        categoryOrderJSON = GroceryCategoryCatalog.encode(savedOrder.map { $0 == oldName ? newName : $0 })
        if category == oldName { category = newName }
        if shoppingCategory == oldName { shoppingCategory = newName }
    }
    private func finishTrip() {
        allTripItems.forEach { item in
            if item.isPurchased { item.lastPurchasedAt = .now }
            item.isStaged = false
            item.isPurchased = false
            item.quantity = 1
        }
    }
    private func completeShopping() {
        guard allTripItems.allSatisfy(\.isPurchased) else {
            shoppingCategory = "All"
            showUncheckedValidation = true
            return
        }
        showUncheckedValidation = false
        finishTrip()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { showShoppingCelebration = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            withAnimation(.easeOut(duration: 0.35)) { showShoppingCelebration = false }
        }
    }
    private func categorySymbol(_ category: String) -> String {
        switch category { case "Produce": "leaf.fill"; case "Dairy & Eggs": "drop.fill"; case "Bakery": "basket.fill"; case "Meat & Seafood": "fish.fill"; case "Frozen": "snowflake"; case "Household": "house.fill"; default: "takeoutbag.and.cup.and.straw.fill" }
    }
}

private struct ShoppingCompletionCelebration: View {
    @AppStorage("preferredName") private var preferredName = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VStack {
                    HStack(spacing: 13) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle).foregroundStyle(forest)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting).font(.headline.weight(.bold))
                            Text("Shopping list is all checked off.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(17)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(forest.opacity(0.18), lineWidth: 1))
                    .shadow(color: forest.opacity(0.12), radius: 14, y: 6)
                    .padding(.horizontal, 20)
                    .padding(.top, geometry.safeAreaInsets.top + 12)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting). Shopping list is all checked off.")
    }

    private var greeting: String {
        let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Great job!" : "Great job, \(name)!"
    }
}

struct GroceryCreateFields: View {
    @Environment(\.modelContext) private var context
    @Query private var existingItems: [GroceryItem]
    @AppStorage("groceryCustomCategoriesJSON") private var customCategoriesJSON = "[]"
    @AppStorage("groceryHiddenBuiltInCategoriesJSON") private var hiddenBuiltInCategoriesJSON = "[]"
    @AppStorage("groceryCategoryOrderJSON") private var categoryOrderJSON = "[]"
    @State private var name = ""
    @State private var category = "Other"
    @State private var addToTrip = true
    let done: () -> Void
    private var categories: [String] {
        let hidden = Set(GroceryCategoryCatalog.decoded(hiddenBuiltInCategoriesJSON))
        let available = GroceryCategoryCatalog.builtIn.filter { $0 == "Other" || !hidden.contains($0) } + GroceryCategoryCatalog.custom(from: customCategoriesJSON)
        return GroceryCategoryCatalog.ordered(available.filter { $0 != "Other" }, by: categoryOrderJSON) + ["Other"]
    }

    var body: some View {
        TextField("Item name", text: $name)
        Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0) } }
        Toggle("Add to today's shopping", isOn: $addToTrip)
        Button("Save grocery") {
            let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            if let existing = existingItems.first(where: { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) {
                if addToTrip { existing.quantity = 1; existing.isPurchased = false; existing.isStaged = true }
            } else {
                context.insert(GroceryItem(name: cleaned, category: category, isStaged: addToTrip))
            }
            done()
        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

private struct GroceryCatalogItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var existingItems: [GroceryItem]
    @State private var name: String
    @State private var category: String

    let item: GroceryItem
    let categories: [String]

    init(item: GroceryItem, categories: [String]) {
        self.item = item
        self.categories = categories
        self._name = State(initialValue: item.name)
        self._category = State(initialValue: item.category)
    }

    private var cleanedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var duplicateName: Bool {
        existingItems.contains {
            $0.persistentModelID != item.persistentModelID &&
            $0.name.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Grocery item") {
                    TextField("Item name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    if duplicateName {
                        Text("An item with this name is already in your catalog.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.name = cleanedName
                        item.category = category
                        dismiss()
                    }
                    .disabled(cleanedName.isEmpty || duplicateName)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct AddGroceryCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let title: String
    let existingCategories: [String]
    let excludingCategory: String?
    let onSave: (String) -> Void

    init(title: String = "New Category", initialName: String = "", existingCategories: [String], excludingCategory: String? = nil, onSave: @escaping (String) -> Void) {
        self.title = title
        self._name = State(initialValue: initialName)
        self.existingCategories = existingCategories
        self.excludingCategory = excludingCategory
        self.onSave = onSave
    }

    private var cleanedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var alreadyExists: Bool { existingCategories.contains { $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame && $0.localizedCaseInsensitiveCompare(excludingCategory ?? "") != .orderedSame } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category name") {
                    TextField("e.g. Snacks", text: $name).textInputAutocapitalization(.words)
                    if !cleanedName.isEmpty && alreadyExists {
                        Text("This category already exists.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section { Text("Your custom category is saved on this device and will be available when adding or filtering groceries.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(title == "New Category" ? "Save" : "Save Changes") { onSave(cleanedName); dismiss() }
                        .disabled(cleanedName.isEmpty || alreadyExists)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private enum GroceryCategoryEditorMode: Identifiable {
    case create
    case edit(String)

    var id: String {
        switch self { case .create: "create"; case .edit(let name): "edit-\(name)" }
    }
    var title: String { if case .create = self { "New Category" } else { "Edit Category" } }
    var initialName: String { if case .edit(let name) = self { name } else { "" } }
    var excludedCategory: String? { if case .edit(let name) = self { name } else { nil } }
}

private struct ManageGroceryCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var orderJSON: String
    @State private var orderedCategories: [String]
    @State private var categoryToDelete = ""
    @State private var showingDeleteConfirmation = false
    @State private var editorMode: GroceryCategoryEditorMode?
    let existingCategories: [String]
    let createCategory: (String) -> Void
    let deleteCategory: (String) -> Void
    let editCategory: (String, String) -> Void

    init(categories: [String], existingCategories: [String], orderJSON: Binding<String>, createCategory: @escaping (String) -> Void, deleteCategory: @escaping (String) -> Void, editCategory: @escaping (String, String) -> Void) {
        self._orderJSON = orderJSON
        self._orderedCategories = State(initialValue: categories.filter { $0 != "Other" } + ["Other"])
        self.existingCategories = existingCategories
        self.createCategory = createCategory
        self.deleteCategory = deleteCategory
        self.editCategory = editCategory
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { editorMode = .create } label: {
                        Label("Create New Category", systemImage: "plus.circle.fill").foregroundStyle(forest)
                    }
                }
                Section("Categories") {
                    ForEach(orderedCategories, id: \.self) { category in
                        HStack {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                                .accessibilityLabel("Drag to reorder \(category)")
                            Text(category).font(.body)
                            Spacer()
                            if category == "Other" { Text("Always last").font(.caption).foregroundStyle(.secondary) }
                            Button {
                                editorMode = .edit(category)
                            } label: {
                                Image(systemName: category == "Other" ? "pencil.slash" : "pencil")
                                    .foregroundStyle(category == "Other" ? Color.secondary : forest)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(category == "Other")
                            .accessibilityLabel(category == "Other" ? "Other category cannot be edited" : "Edit \(category) category")
                            Button {
                                categoryToDelete = category
                                showingDeleteConfirmation = true
                            } label: {
                                Image(systemName: category == "Other" ? "trash.slash" : "trash")
                                    .foregroundStyle(category == "Other" ? Color.secondary : Color.red)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(category == "Other")
                            .accessibilityLabel(category == "Other" ? "Other category cannot be deleted" : "Delete \(category) category")
                        }
                    }
                    .onMove(perform: move)
                }
                Section { Text("Drag rows to reorder. Rename with the pencil or delete with the trash button; deleted category items move into Other. Other stays last and cannot be edited or deleted.").font(.footnote).foregroundStyle(.secondary) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Delete category?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) { remove(categoryToDelete) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Items in \(categoryToDelete) will be moved to Other.")
            }
            .sheet(item: $editorMode) { mode in
                AddGroceryCategoryView(title: mode.title, initialName: mode.initialName, existingCategories: existingCategories + orderedCategories, excludingCategory: mode.excludedCategory) { name in
                    switch mode {
                    case .create:
                        createCategory(name)
                        orderedCategories.removeAll { $0 == "Other" }
                        orderedCategories.append(name)
                        orderedCategories.append("Other")
                    case .edit(let oldName):
                        guard oldName.localizedCaseInsensitiveCompare(name) != .orderedSame else { return }
                        editCategory(oldName, name)
                        if let index = orderedCategories.firstIndex(of: oldName) { orderedCategories[index] = name }
                    }
                    orderJSON = GroceryCategoryCatalog.encode(orderedCategories)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard !source.contains(where: { orderedCategories[$0] == "Other" }) else { return }
        orderedCategories.move(fromOffsets: source, toOffset: destination)
        orderedCategories.removeAll { $0 == "Other" }
        orderedCategories.append("Other")
        orderJSON = GroceryCategoryCatalog.encode(orderedCategories)
    }

    private func remove(_ name: String) {
        guard name != "Other" else { return }
        orderedCategories.removeAll { $0 == name }
        deleteCategory(name)
        orderJSON = GroceryCategoryCatalog.encode(orderedCategories)
    }
}
