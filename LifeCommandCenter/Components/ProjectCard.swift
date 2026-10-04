import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct ProjectCard: View {
    let project: HomeProject
    var body: some View { VStack(alignment: .leading, spacing: 12) { HStack { Image(systemName: "hammer.fill").foregroundStyle(forest); Text(project.area.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary); Spacer(); Text(project.status).font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 5).background(forest.opacity(0.1), in: Capsule()) }; Text(project.name).font(.headline); ProgressView(value: project.progress).tint(forest); HStack { Text("\(project.tasks.filter(\.isComplete).count) / \(project.tasks.count) tasks complete"); Spacer(); if project.estimatedCost > 0 { Text("\(project.actualCost.currency) / \(project.estimatedCost.currency)") } }.font(.caption).foregroundStyle(.secondary); if !project.tasks.isEmpty { ForEach(project.tasks.prefix(3)) { task in Button { task.isComplete.toggle() } label: { Label(task.title, systemImage: task.isComplete ? "checkmark.circle.fill" : "circle").font(.caption).foregroundStyle(task.isComplete ? forest : .secondary) } } } }.padding(16).cardStyle() }
}
