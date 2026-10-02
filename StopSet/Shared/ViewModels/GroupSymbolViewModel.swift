import SwiftUI
import MapKit

struct GroupSymbolViewModel {
    let symbol: String
    let color: String
    let size: CGFloat
    var tint: Color { TransitStyle.color(color) }
}
