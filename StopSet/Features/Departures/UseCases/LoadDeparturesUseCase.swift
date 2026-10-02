import Foundation

@MainActor
struct LoadDeparturesUseCase {
    private let repository: any TransitRepository
    private let settings: any SettingsRepository
    init(repository: any TransitRepository, settings: any SettingsRepository) {
        self.repository = repository
        self.settings = settings
    }
    func execute(stops: [BusStop]) async throws -> [Departure] {
        try await repository.departures(for: stops, key: settings.apiKey ?? "")
    }
}
