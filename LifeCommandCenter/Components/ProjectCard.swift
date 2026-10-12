import SwiftData
import SwiftUI

struct ProjectCard: View {
    let project: HomeProject

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(project.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                ProgressView(value: project.progress).tint(forest)
            }
            Spacer(minLength: 8)
            Text("\(Int((project.progress * 100).rounded()))%")
                .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(
                .secondary)
        }.padding(.vertical, 14).contentShape(Rectangle())
    }
}

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var context
    @State private var saveError = false
    @State private var showingTasks = true
    @State private var showingShopping = true
    @State private var showingAllTasks = false
    @State private var showingAllShopping = false
    let project: HomeProject
    let edit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(project.name).font(.title2.bold())
                            Text(project.area).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Menu {
                            ForEach(["In Progress", "On Hold", "Planned", "Completed"], id: \.self)
                            { status in
                                Button {
                                    changeStatus(to: status)
                                } label: {
                                    Label(
                                        status,
                                        systemImage: project.status == status
                                            ? "checkmark.circle.fill" : "circle.fill"
                                    )
                                }.accessibilityIdentifier("project-status-option-\(status)")
                            }
                        } label: {
                            ProjectStatusBadge(status: project.displayStatus)
                        }.tint(ProjectStatusStyle.color(for: project.status))
                            .accessibilityLabel("Change project status")
                            .accessibilityIdentifier("project-status-menu")
                    }
                    if !project.detail.isEmpty {
                        Text(project.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: project.progress).tint(forest)
                HStack {
                    Text(
                        "\(project.tasks.filter(\.isComplete).count) / \(project.tasks.count) tasks complete"
                    )
                    Spacer()
                    Text("\(Int((project.progress * 100).rounded()))%")
                }.font(.caption).foregroundStyle(.secondary)
                if !project.isComplete {
                    Label(
                        project.targetDate.formatted(.dateTime.month(.abbreviated).day().year()),
                        systemImage: "calendar"
                    )
                    .font(.caption).foregroundStyle(project.isDue() ? .orange : .secondary)
                }
                if project.estimatedCost > 0 || project.actualCost > 0 {
                    LabeledContent(
                        "Actual / estimate",
                        value: "\(project.actualCost.currency) / \(project.estimatedCost.currency)"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                if project.isComplete {
                    Label(
                        "Lists are locked. Change status from Completed to edit them.",
                        systemImage: "lock.fill"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup(isExpanded: $showingTasks) {
                    if project.tasks.isEmpty {
                        Text("No tasks yet. Use Edit to add a task.").font(.subheadline)
                            .foregroundStyle(.secondary).padding(.vertical, 8)
                    }
                    ForEach(
                        Array(
                            project.orderedTasks.prefix(showingAllTasks ? project.tasks.count : 6))
                    ) { task in
                        Button {
                            toggle(task)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(
                                    systemName: task.isComplete ? "checkmark.circle.fill" : "circle"
                                )
                                .font(.title3).foregroundStyle(
                                    task.isComplete ? forest : .secondary)
                                Text(task.title).strikethrough(task.isComplete)
                                    .foregroundStyle(task.isComplete ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }.font(.subheadline).frame(
                                maxWidth: .infinity, minHeight: 36, alignment: .leading
                            )
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(project.isComplete)
                            .accessibilityLabel(
                                "\(task.isComplete ? "Reopen" : "Complete") \(task.title)")
                    }
                    if project.tasks.count > 6 {
                        Button(showingAllTasks ? "Show less" : "Show all \(project.tasks.count)") {
                            withAnimation(.snappy) { showingAllTasks.toggle() }
                        }
                        .font(.subheadline.weight(.semibold)).padding(.vertical, 8)
                        .frame(maxWidth: .infinity).accessibilityIdentifier(
                            "project-tasks-show-all")
                    }
                } label: {
                    HStack {
                        Text("Task list").font(.headline)
                        Spacer()
                        Text("\(project.tasks.filter(\.isComplete).count)/\(project.tasks.count)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.accessibilityIdentifier("project-task-list")
                }.padding(16).cardStyle()
                DisclosureGroup(isExpanded: $showingShopping) {
                    if project.shoppingItems.isEmpty {
                        Text("No shopping items yet. Use Edit to add supplies.").font(.subheadline)
                            .foregroundStyle(.secondary).padding(.vertical, 8)
                    }
                    ForEach(
                        Array(
                            project.orderedShoppingItems.prefix(
                                showingAllShopping ? project.shoppingItems.count : 6))
                    ) { item in
                        Button {
                            toggle(item)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(
                                    systemName: item.isPurchased
                                        ? "checkmark.circle.fill" : "circle"
                                )
                                .font(.title3).foregroundStyle(
                                    item.isPurchased ? forest : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).strikethrough(item.isPurchased)
                                        .foregroundStyle(item.isPurchased ? .secondary : .primary)
                                    Text("\(item.quantity) × \(item.estimatedUnitCost.currency)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }.multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Text(item.estimatedTotal.currency).font(.caption.weight(.semibold))
                                    .foregroundStyle(
                                        .secondary)
                            }.font(.subheadline).frame(
                                maxWidth: .infinity, minHeight: 44, alignment: .leading
                            )
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(project.isComplete)
                            .accessibilityLabel(
                                "Mark \(item.name) \(item.isPurchased ? "unpurchased" : "purchased")"
                            )
                    }
                    if project.shoppingItems.count > 6 {
                        Button(
                            showingAllShopping
                                ? "Show less" : "Show all \(project.shoppingItems.count)"
                        ) {
                            withAnimation(.snappy) { showingAllShopping.toggle() }
                        }
                        .font(.subheadline.weight(.semibold)).padding(.vertical, 8)
                        .frame(maxWidth: .infinity).accessibilityIdentifier(
                            "project-shopping-show-all")
                    }
                } label: {
                    HStack {
                        Text("Shopping list").font(.headline)
                        Spacer()
                        Text(project.shoppingEstimate.currency).font(.subheadline).foregroundStyle(
                            .secondary)
                    }.accessibilityIdentifier("project-shopping-list")
                }.padding(16).cardStyle()
            }.padding(20)
        }.background(canvas)
            .navigationTitle("Project details").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit", action: edit) } }
            .alert("Couldn’t save project", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
    }

    private func toggle(_ task: ProjectTask) {
        guard !project.isComplete else { return }
        task.isComplete.toggle()
        do { try context.save() } catch {
            task.isComplete.toggle()
            saveError = true
        }
    }

    private func toggle(_ item: ProjectShoppingItem) {
        guard !project.isComplete else { return }
        item.isPurchased.toggle()
        do { try context.save() } catch {
            item.isPurchased.toggle()
            saveError = true
        }
    }

    private func changeStatus(to status: String) {
        let previousStatus = project.status
        project.status = status
        do { try context.save() } catch {
            project.status = previousStatus
            saveError = true
        }
    }
}

enum ProjectStatusStyle {
    static func color(for status: String) -> Color {
        switch status {
        case "Completed": .blue
        case "On Hold": .orange
        case "Planned": .purple
        default: .green
        }
    }
}

private struct ProjectStatusBadge: View {
    let status: String
    private var color: Color { ProjectStatusStyle.color(for: status) }

    var body: some View {
        HStack(spacing: 5) {
            Text(status)
            Image(systemName: "chevron.down").font(.caption2)
        }.font(.caption.weight(.semibold))
            .foregroundStyle(color).padding(.horizontal, 12).padding(.vertical, 7)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Project status: \(status)")
            .accessibilityIdentifier("project-status-badge")
    }
}
