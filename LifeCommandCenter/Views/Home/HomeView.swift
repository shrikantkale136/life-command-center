import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var context
    let maintenance: [HomeMaintenance]; let projects: [HomeProject]; let add: () -> Void
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 5) { Text("HOME MANAGEMENT").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(forest); Text("Care for your place.").font(.largeTitle.weight(.bold)).fontDesign(.rounded) }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
        HStack(spacing: 12) { MetricCard(icon: "wrench.and.screwdriver.fill", color: .orange, value: "\(maintenance.filter { $0.nextDue < Calendar.current.startOfDay(for: .now) }.count)", caption: "Overdue"); MetricCard(icon: "hammer.fill", color: forest, value: "\(projects.filter { $0.status == "In Progress" }.count)", caption: "In progress") }
        HStack { SectionHeading(title: "Maintenance", subtitle: "A little upkeep goes a long way"); Spacer(); Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) } }
        if maintenance.isEmpty { EmptyCard(symbol: "wrench.adjustable", title: "No maintenance tracked", subtitle: "Keep service dates and home care together.", button: "Add maintenance", action: add) }
        else { VStack(spacing: 0) { ForEach(maintenance) { item in HStack(spacing: 13) { Image(systemName: "wrench.and.screwdriver.fill").foregroundStyle(.orange).frame(width: 34, height: 34).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 11)); VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.subheadline.weight(.semibold)); Text("\(item.area) · \(item.frequencyRaw)").font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing, spacing: 4) { Text(item.nextDue.formatted(.dateTime.month(.abbreviated).day())).font(.caption.weight(.semibold)); Text(item.nextDue < .now ? "Overdue" : "Due").font(.caption2).foregroundStyle(item.nextDue < .now ? .red : .secondary) } }.padding(14).contentShape(Rectangle()).contextMenu { Button("Mark complete", systemImage: "checkmark") { item.lastCompleted = .now; if let rule = RepeatRule(rawValue: item.frequencyRaw), let next = rule.next(after: item.nextDue) { item.nextDue = next } } }; if item.id != maintenance.last?.id { Divider().padding(.leading, 58) } } }.cardStyle() }
        HStack { SectionHeading(title: "Projects", subtitle: "Make progress, one step at a time"); Spacer(); Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(forest) } }
        if projects.isEmpty { EmptyCard(symbol: "hammer", title: "No active projects", subtitle: "Start planning your next home improvement.", button: "Add project", action: add) }
        else { ForEach(projects) { project in ProjectCard(project: project) } }
    }.padding(20).padding(.bottom, 70) }.background(canvas).navigationTitle("Home").navigationBarTitleDisplayMode(.inline) } }
}

struct MaintenanceCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var name = ""; @State private var area = "HVAC"; @State private var due = Date.now; @State private var repeatRule: RepeatRule = .quarterly
    let done: () -> Void
    var body: some View { TextField("Maintenance item", text: $name); Picker("Area", selection: $area) { ForEach(["Kitchen", "Living Room", "Bedroom", "Bathroom", "Garage", "Yard", "HVAC", "Plumbing", "Electrical", "Exterior", "Appliances", "Other"], id: \.self) { Text($0) } }; DatePicker("Next due", selection: $due, displayedComponents: .date); Picker("Frequency", selection: $repeatRule) { ForEach(RepeatRule.allCases.filter { $0 != .none }) { Text($0.rawValue).tag($0) } }; Button("Save maintenance") { guard !name.isEmpty else { return }; context.insert(HomeMaintenance(name: name, area: area, nextDue: due, frequency: repeatRule)); done() }.disabled(name.isEmpty) }
}

struct ProjectCreateFields: View {
    @Environment(\.modelContext) private var context; @State private var name = ""; @State private var area = "Home"; @State private var target = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now; @State private var cost = ""; @State private var tasksText = ""
    let done: () -> Void
    var body: some View { TextField("Project name", text: $name); TextField("Area", text: $area); DatePicker("Target date", selection: $target, displayedComponents: .date); TextField("Estimated cost", text: $cost).keyboardType(.decimalPad); TextField("Tasks (one per line)", text: $tasksText, axis: .vertical).lineLimit(3...7); Button("Save project") { guard !name.isEmpty else { return }; let p = HomeProject(name: name, area: area, targetDate: target, estimatedCost: Double(cost) ?? 0); context.insert(p); for line in tasksText.split(whereSeparator: \.isNewline) { let t = ProjectTask(title: String(line), project: p); p.tasks.append(t); context.insert(t) }; done() }.disabled(name.isEmpty) }
}
