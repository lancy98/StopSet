import CoreLocation

struct ATTransitRepository: TransitRepository {
    private let service = TransitService()

    func nearbyStops(at coordinate: CLLocationCoordinate2D) async throws -> [BusStop] {
        try await service.nearbyStops(at: coordinate)
    }

    func stops(numberPrefix: String) async throws -> [BusStop] {
        try await service.stops(numberPrefix: numberPrefix)
    }

    func nearbyRoutes(at coordinate: CLLocationCoordinate2D) async throws -> [String] {
        try await service.nearbyRoutes(at: coordinate)
    }

    func departures(for stops: [BusStop], key: String) async throws -> [Departure] {
        try await service.departures(for: stops, key: key)
    }

    func vehicleLocation(tripID: String, vehicleID: String?, key: String) async throws -> VehicleLocation? {
        try await service.vehicleLocation(tripID: tripID, vehicleID: vehicleID, key: key)
    }
}
