import SwiftUI
import SwiftData
import UserNotifications
import Charts
import UIKit

let ink = Color.primary
var forest: Color { AppAccentColor.color(named: UserDefaults.standard.string(forKey: "appAccentColor") ?? "Forest") }
let canvas = Color(uiColor: .systemGroupedBackground)
