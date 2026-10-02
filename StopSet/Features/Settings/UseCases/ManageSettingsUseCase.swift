import Foundation

struct ManageSettingsUseCase {
    private let repository: any SettingsRepository

    let allowsSampleData: Bool

    var apiKey: String? { repository.apiKey }
    var canLoadTransit: Bool { apiKey != nil || allowsSampleData }
    var departureRefreshInterval: Int { repository.departureRefreshInterval }

    init(repository: any SettingsRepository, allowsSampleData: Bool = false) {
        self.repository = repository
        self.allowsSampleData = allowsSampleData
    }

    func setDepartureRefreshInterval(_ value: Int) {
        guard RefreshSettings.departureIntervals.contains(value) else { return }
        repository.departureRefreshInterval = value
    }

    func saveAPIKey(_ value: String) -> Bool {
        repository.saveAPIKey(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
