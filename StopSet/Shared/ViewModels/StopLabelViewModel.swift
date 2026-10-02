import SwiftUI
import MapKit

struct StopLabelViewModel {
    let stop: BusStop

    var name: String { stop.name }
    var codeLabel: String { "Stop \(stop.code)" }
}
