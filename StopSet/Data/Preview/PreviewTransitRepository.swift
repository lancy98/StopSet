import CoreLocation

struct PreviewTransitRepository: TransitRepository {
    func nearbyStops(at coordinate: CLLocationCoordinate2D) async throws -> [BusStop] { AppPreview.stops }

    func stops(numberPrefix: String) async throws -> [BusStop] {
        AppPreview.searchableStops.filter { $0.code.hasPrefix(numberPrefix) }
            .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
    }

    func nearbyRoutes(at coordinate: CLLocationCoordinate2D) async throws -> [String] { ["CTY", "NX2", "923"] }

    func departures(for stops: [BusStop], key: String) async throws -> [Departure] { AppPreview.departures(for: stops) }

    func vehicleLocation(tripID: String, vehicleID: String?, key: String) async throws -> VehicleLocation? {
        VehicleLocation(coordinate: CLLocationCoordinate2D(latitude: -36.84734, longitude: 174.74995), timestamp: .now)
    }
}
