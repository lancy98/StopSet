import Foundation

@MainActor
final class DeviceSettingsRepository: SettingsRepository {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = AppPreview.isEnabled ? UserDefaults(suiteName: "StopSet.UITests")! : defaults
        if AppPreview.isEnabled {
            self.defaults.set(RefreshSettings.defaultDepartureInterval, forKey: RefreshSettings.departureIntervalKey)
        }
    }
    var apiKey: String? { APIKeyStore.key }
    func saveAPIKey(_ value: String) -> Bool { APIKeyStore.save(value) }
    var departureRefreshInterval: Int {
        get {
            let value = defaults.integer(forKey: RefreshSettings.departureIntervalKey)
            return RefreshSettings.departureIntervals.contains(value) ? value : RefreshSettings.defaultDepartureInterval
        }
        set { defaults.set(newValue, forKey: RefreshSettings.departureIntervalKey) }
    }
}
