import SwiftUI
import MapKit

struct StopMapView: View {
    private let viewModel: StopMapViewModel

    private var stops: [BusStop] { viewModel.stops }

    var body: some View {
        Map(initialPosition: .region(viewModel.region),
            interactionModes: viewModel.interactionModes) {
            ForEach(stops) { stop in
                Marker(stop.code, systemImage: "bus.fill", coordinate: stop.coordinate).tint(.blue)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .accessibilityLabel(viewModel.accessibilityLabel)
    }

    init(stops: [BusStop], interactive: Bool = true) {
        viewModel = StopMapViewModel(stops: stops, interactive: interactive)
    }
}
