import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var key = ""
    var hasKey = false
    var status: String?
    var confirmingRemoval = false
    var departureRefreshInterval: Int {
        didSet { useCase.setDepartureRefreshInterval(departureRefreshInterval) }
    }
    private let useCase: ManageSettingsUseCase
    init(useCase: ManageSettingsUseCase) {
        self.useCase = useCase
        key = useCase.apiKey ?? ""
        hasKey = useCase.apiKey != nil
        departureRefreshInterval = useCase.departureRefreshInterval
    }
    func saveKey() {
        if useCase.saveAPIKey(key) {
            hasKey = true
            status = "Key saved securely."
        } else { status = "Could not save the key. Please try again." }
    }
    func removeKey() {
        if useCase.saveAPIKey("") { key = ""; hasKey = false }
        else { status = "Could not remove the key. Please try again." }
    }
}
