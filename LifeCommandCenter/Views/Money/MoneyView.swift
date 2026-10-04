import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct SubscriptionsView: View {
    let items: [SubscriptionItem]; let bills: [BillItem]; let add: () -> Void
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 5) { Text("MONEY OVERVIEW").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(forest); Text("Stay ahead of renewals.").font(.largeTitle.weight(.bold)).fontDesign(.rounded) }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
        HStack(spacing: 12) { VStack(alignment: .leading, spacing: 8) { Image(systemName: "arrow.clockwise").foregroundStyle(.purple); Text(items.reduce(0) { $0 + $1.monthlyCost }.currency).font(.title2.bold()); Text("per month").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).cardStyle(); VStack(alignment: .leading, spacing: 8) { Image(systemName: "calendar").foregroundStyle(forest); Text((items.reduce(0) { $0 + $1.monthlyCost } * 12).currency).font(.title2.bold()); Text("per year").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).cardStyle() }
        if !items.isEmpty { VStack(alignment: .leading, spacing: 10) { SectionHeading(title: "By category", subtitle: "Monthly equivalent"); Chart(categoryTotals, id: \.key) { item in BarMark(x: .value("Monthly", item.value), y: .value("Category", item.key)).foregroundStyle(forest.gradient).cornerRadius(6) }.frame(height: CGFloat(max(90, categoryTotals.count * 30))).chartXAxis { AxisMarks(position: .bottom) }; }.padding(16).cardStyle() }
        HStack { SectionHeading(title: "Subscriptions", subtitle: "\(items.count) active"); Spacer(); Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) } }
        if items.isEmpty { EmptyCard(symbol: "creditcard", title: "No subscriptions added", subtitle: "See what renews and what it costs.", button: "Add subscription", action: add) }
        else { VStack(spacing: 0) { ForEach(items) { item in HStack(spacing: 12) { Image(systemName: "arrow.clockwise").foregroundStyle(.purple).frame(width: 34, height: 34).background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 11)); VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.subheadline.weight(.semibold)); Text("\(item.category) · \(item.frequencyRaw)").font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing, spacing: 4) { Text(item.cost.currency).font(.subheadline.weight(.semibold)); Text(item.nextDate.formatted(.dateTime.month(.abbreviated).day())).font(.caption).foregroundStyle(.secondary) } }.padding(14); if item.id != items.last?.id { Divider().padding(.leading, 58) } } }.cardStyle() }
        HStack { SectionHeading(title: "Bills", subtitle: "Upcoming payments"); Spacer(); Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) } }
        if bills.isEmpty { EmptyCard(symbol: "doc.text", title: "No upcoming bills", subtitle: "Track bills alongside your other plans.", button: "Add bill", action: add) }
        else { VStack(spacing: 0) { ForEach(bills) { bill in HStack { Image(systemName: "doc.text.fill").foregroundStyle(.orange).frame(width: 34, height: 34).background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 11)); VStack(alignment: .leading, spacing: 4) { Text(bill.name).font(.subheadline.weight(.semibold)); Text("Due \(bill.dueDate.formatted(.dateTime.month(.abbreviated).day()))").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(bill.amount.currency).font(.subheadline.weight(.semibold)) }.padding(14) } }.cardStyle() }
    }.padding(20).padding(.bottom, 70) }.background(canvas).navigationTitle("Money").navigationBarTitleDisplayMode(.inline) } }
    private var categoryTotals: [(key: String, value: Double)] { Dictionary(grouping: items, by: \.category).map { ($0.key, $0.value.reduce(0) { $0 + $1.monthlyCost }) }.sorted { $0.value > $1.value } }
}

struct SubscriptionCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var name = ""; @State private var category = "Streaming"; @State private var cost = ""; @State private var frequency = "Monthly"; @State private var next = Date.now
    let done: () -> Void
    var body: some View { TextField("Subscription name", text: $name); TextField("Category", text: $category); TextField("Cost", text: $cost).keyboardType(.decimalPad); Picker("Billing frequency", selection: $frequency) { ForEach(["Weekly", "Monthly", "Quarterly", "Semi-Annual", "Annual"], id: \.self) { Text($0) } }; DatePicker("Next renewal", selection: $next, displayedComponents: .date); Button("Save subscription") { guard !name.isEmpty else { return }; context.insert(SubscriptionItem(name: name, category: category, cost: Double(cost) ?? 0, frequency: frequency, nextDate: next)); done() }.disabled(name.isEmpty) }
}

struct BillCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var name = ""; @State private var amount = ""; @State private var due = Date.now; @State private var frequency = "Monthly"; @State private var reminder = false
    let done: () -> Void
    var body: some View { TextField("Bill name", text: $name); TextField("Amount", text: $amount).keyboardType(.decimalPad); DatePicker("Due date", selection: $due, displayedComponents: .date); Picker("Frequency", selection: $frequency) { ForEach(["Weekly", "Monthly", "Quarterly", "Annual"], id: \.self) { Text($0) } }; Toggle("Remind me", isOn: $reminder); Button("Save bill") { guard !name.isEmpty else { return }; let bill = BillItem(name: name, amount: Double(amount) ?? 0, dueDate: due, frequency: frequency); context.insert(bill); if reminder { NotificationService.schedule(id: bill.persistentModelID.hashValue.description, title: "\(name) is due", date: due) }; done() }.disabled(name.isEmpty) }
}
