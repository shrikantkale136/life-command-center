import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

struct SectionHeading: View { let title: String; let subtitle: String; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.title3.bold()); Text(subtitle).font(.caption).foregroundStyle(.secondary) } } }

struct MetricCard: View { let icon: String; let color: Color; let value: String; let caption: String; var body: some View { VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).font(.subheadline).foregroundStyle(color); Text(value).font(.title2.bold()); Text(caption).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(15).cardStyle() } }

struct EmptyCard: View { let symbol: String; let title: String; let subtitle: String; let button: String; let action: () -> Void; var body: some View { VStack(spacing: 9) { Image(systemName: symbol).font(.title2).foregroundStyle(forest); Text(title).font(.subheadline.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center); Button(button, action: action).font(.subheadline.weight(.semibold)).padding(.top, 3) }.frame(maxWidth: .infinity).padding(22).cardStyle() } }

extension View { func cardStyle() -> some View { self.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous)) } }

extension Double { var currency: String { formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) } }
