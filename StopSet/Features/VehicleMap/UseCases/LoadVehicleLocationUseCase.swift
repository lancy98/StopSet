import Foundation

struct LoadVehicleLocationUseCase {
    private let repository: any TransitRepository
    private let settings: any SettingsRepository

    init(repository: any TransitRepository, settings: any SettingsRepository) {
        self.repository = repository
        self.settings = settings
    }

    func execute(departure: Departure) async throws -> VehicleLocation? {
        try await repository.vehicleLocation(tripID: departure.tripID, vehicleID: departure.vehicleID, key: settings.apiKey ?? "")
    }
}
