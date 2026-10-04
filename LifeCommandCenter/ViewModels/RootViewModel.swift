import Observation
import SwiftUI

@Observable
@MainActor
final class RootViewModel {
    var selectedTab = 0

    func selectTab(_ index: Int) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            selectedTab = min(max(index, 0), 4)
        }
    }
}
