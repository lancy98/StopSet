import CoreLocation

struct DiscoverStopsUseCase {
    private let repository: any TransitRepository

    init(repository: any TransitRepository) { self.repository = repository }

    func nearbyStops(at coordinate: CLLocationCoordinate2D) async throws -> [BusStop] {
        try await repository.nearbyStops(at: coordinate)
    }

    func nearbyRoutes(at coordinate: CLLocationCoordinate2D) async throws -> [String] {
        try await repository.nearbyRoutes(at: coordinate)
    }
}
