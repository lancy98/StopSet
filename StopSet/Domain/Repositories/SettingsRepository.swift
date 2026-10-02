import Foundation

protocol SettingsRepository: AnyObject {
    var apiKey: String? { get }
    var departureRefreshInterval: Int { get set }

    func saveAPIKey(_ value: String) -> Bool
}
