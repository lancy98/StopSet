import MapKit
import Combine

struct AddressSearchState {
    var completions: [AddressSearchResult] = []
    var stopResults: [BusStop] = []
    var stopError: String?
    var findingStops = false
    var error: String?
    var resolving = false
    var completing = false
}

@MainActor
protocol AddressSearchRepository: AnyObject {
    var query: String { get set }
    var state: AddressSearchState { get }
    var statePublisher: AnyPublisher<AddressSearchState, Never> { get }
    func findStops(debounce: Bool)
    func resolve(_ result: AddressSearchResult?) async -> MKMapItem?
    func cancel()
}
