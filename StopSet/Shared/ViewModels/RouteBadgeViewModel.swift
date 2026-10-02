import SwiftUI
import MapKit

struct RouteBadgeViewModel {
    let route: String

    var background: Color { route == "CTY" ? .red : .blue }
    var accessibilityLabel: String { "Route \(route)" }
}
