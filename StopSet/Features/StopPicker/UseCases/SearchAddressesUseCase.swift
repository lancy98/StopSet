import MapKit
import Combine

struct SearchAddressesUseCase {
    private let repository: any AddressSearchRepository

    var state: AddressSearchState { repository.state }
    var statePublisher: AnyPublisher<AddressSearchState, Never> { repository.statePublisher }

    init(repository: any AddressSearchRepository) { self.repository = repository }

    func updateQuery(_ value: String) { repository.query = value }

    func findStops(debounce: Bool) { repository.findStops(debounce: debounce) }

    func resolve(_ result: AddressSearchResult?) async -> MKMapItem? { await repository.resolve(result) }

    func cancel() { repository.cancel() }
}
