import SwiftUI
import MapKit

struct StopMapViewModel {
    let stops: [BusStop]
    let interactive: Bool
    var region: MKCoordinateRegion { TransitStyle.region(for: stops) }
    var interactionModes: MapInteractionModes { interactive ? .all : [] }
    var accessibilityLabel: String { stops.count == 1 ? "Map of 1 saved stop" : "Map of \(stops.count) saved stops" }
}
