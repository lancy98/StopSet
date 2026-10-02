import CoreLocation

protocol TransitRepository {
    func nearbyStops(at coordinate: CLLocationCoordinate2D) async throws -> [BusStop]

    func stops(numberPrefix: String) async throws -> [BusStop]

    func nearbyRoutes(at coordinate: CLLocationCoordinate2D) async throws -> [String]

    func departures(for stops: [BusStop], key: String) async throws -> [Departure]

    func vehicleLocation(tripID: String, vehicleID: String?, key: String) async throws -> VehicleLocation?
}
