import Observation
import SwiftUI

@Observable
@MainActor
final class RootViewModel {
    var selectedTab: Int

    init(startPage: StartPage = .today) { selectedTab = startPage.tab }

    func selectTab(_ index: Int) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            selectedTab = min(max(index, 0), 4)
        }
    }
}
