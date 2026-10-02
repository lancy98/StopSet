import MapKit
import Observation
import Combine

@MainActor
@Observable
final class AddressSearchViewModel {
    var query = "" { didSet { useCase.updateQuery(query) } }
    private var state: AddressSearchState
    private let useCase: SearchAddressesUseCase
    private var subscription: AnyCancellable?
    init(useCase: SearchAddressesUseCase) {
        self.useCase = useCase
        state = useCase.state
        subscription = useCase.statePublisher.sink { [weak self] in self?.state = $0 }
    }
    var completions: [AddressSearchResult] { state.completions }
    var stopResults: [BusStop] { state.stopResults }
    var stopError: String? { state.stopError }
    var findingStops: Bool { state.findingStops }
    var error: String? { state.error }
    var resolving: Bool { state.resolving }
    var completing: Bool { state.completing }
    var stopNumber: String? {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.allSatisfy({ $0 >= "0" && $0 <= "9" }) ? value : nil
    }
    func findStops(debounce: Bool = true) { useCase.findStops(debounce: debounce) }
    func resolve(_ result: AddressSearchResult? = nil) async -> MKMapItem? { await useCase.resolve(result) }
    func cancel() { useCase.cancel() }
}
