import SwiftUI
import MapKit
import Observation

@Observable
final class VehicleMapViewModel {
    let departure: Departure
    var location: VehicleLocation?
    var loading = false
    var message: String?
    var camera: MapCameraPosition = .automatic

    private let loadUseCase: LoadVehicleLocationUseCase
    private let settingsUseCase: ManageSettingsUseCase

    init(departure: Departure, loadUseCase: LoadVehicleLocationUseCase,
         settingsUseCase: ManageSettingsUseCase) {
        self.departure = departure
        self.loadUseCase = loadUseCase
        self.settingsUseCase = settingsUseCase
    }

    func refresh() async {
        guard !loading, !Task.isCancelled else { return }
        loading = true
        defer { loading = false }
        do {
            guard settingsUseCase.canLoadTransit else {
                message = "Add an AT API key in Settings to see bus locations."
                return
            }
            let result = try await loadUseCase.execute(departure: departure)
            guard !Task.isCancelled else { return }
            let firstLocation = location == nil
            location = result
            message = result == nil ? "No location has been reported for this bus yet." : nil
            if firstLocation { recenter() }
        } catch {
            guard !Task.isCancelled else { return }
            message = error.localizedDescription
        }
    }

    func recenter() {
        let points = ([departure.stop.coordinate] + [location?.coordinate].compactMap { $0 }).map(MKMapPoint.init)
        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!
        let padding = max(max(maxX - minX, maxY - minY) * 0.5, 1_500)
        camera = .rect(MKMapRect(x: minX - padding, y: minY - padding,
                                width: maxX - minX + padding * 2, height: maxY - minY + padding * 2))
    }
}
