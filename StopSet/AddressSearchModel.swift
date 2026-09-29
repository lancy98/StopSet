import MapKit
import SwiftUI

struct AddressSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    var completion: MKLocalSearchCompletion?
    var previewCoordinate: CLLocationCoordinate2D?
}

@MainActor
final class AddressSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            requestID = UUID()
            search?.cancel()
            resolving = false
            stopRequestID = UUID()
            stopSearchTask?.cancel()
            findingStops = false
            error = nil
            stopError = nil
            stopResults = []
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                completer.cancel()
                completions = []
                completing = false
                return
            }
            if AppPreview.isEnabled {
                completions = AppPreview.addresses.filter {
                    "\($0.title) \($0.subtitle)".localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } else {
                completing = true
                completer.queryFragment = query
            }
            if stopNumber != nil { findStops() }
        }
    }
    @Published private(set) var completions: [AddressSearchResult] = []
    @Published private(set) var stopResults: [BusStop] = []
    @Published private(set) var stopError: String?
    @Published private(set) var findingStops = false
    @Published private(set) var error: String?
    @Published private(set) var resolving = false
    @Published private(set) var completing = false
    private let completer = MKLocalSearchCompleter()
    private var search: MKLocalSearch?
    private var stopSearchTask: Task<Void, Never>?
    private var requestID = UUID()
    private var stopRequestID = UUID()

    var stopNumber: String? {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.allSatisfy({ $0 >= "0" && $0 <= "9" }) ? value : nil
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(center: TransitStyle.auckland.center,
                                              span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6))
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            completing = false
            error = nil
            completions = completer.results.prefix(8).map {
                AddressSearchResult(title: $0.title, subtitle: $0.subtitle, completion: $0)
            }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            completing = false
            self.error = "Address search is unavailable. Try again shortly."
        }
    }

    func findStops(debounce: Bool = true) {
        guard let number = stopNumber else { return }
        stopSearchTask?.cancel()
        let id = UUID()
        stopRequestID = id
        findingStops = true
        stopError = nil
        stopResults = []
        stopSearchTask = Task {
            defer { if stopRequestID == id { findingStops = false } }
            do {
                if debounce { try await Task.sleep(for: .milliseconds(300)) }
                let results = AppPreview.isEnabled ? AppPreview.searchableStops.filter { $0.code.hasPrefix(number) }
                    .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending } :
                    try await TransitService().stops(numberPrefix: number)
                guard stopRequestID == id, !Task.isCancelled else { return }
                stopResults = results
            } catch {
                guard stopRequestID == id, !Task.isCancelled else { return }
                stopError = "Couldn't search stops. Check your connection and try again."
            }
        }
    }

    func resolve(_ result: AddressSearchResult? = nil) async -> MKMapItem? {
        search?.cancel()
        if AppPreview.isEnabled,
           let preview = result ?? completions.first,
           let coordinate = preview.previewCoordinate {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = preview.title
            return item
        }
        let id = UUID()
        requestID = id
        let completion = result?.completion
        let request = completion.map { MKLocalSearch.Request(completion: $0) } ?? MKLocalSearch.Request()
        if completion == nil { request.naturalLanguageQuery = query }
        request.region = completer.region
        let search = MKLocalSearch(request: request)
        self.search = search
        resolving = true
        defer { if requestID == id { resolving = false } }
        do {
            let response = try await search.start()
            guard requestID == id, !Task.isCancelled else { return nil }
            guard let item = response.mapItems.first else {
                error = "No matching address found."
                return nil
            }
            return item
        } catch {
            if requestID == id, !Task.isCancelled {
                self.error = "Could not find this address. Try again."
            }
            return nil
        }
    }

    func cancel() {
        requestID = UUID()
        stopRequestID = UUID()
        search?.cancel()
        completer.cancel()
        stopSearchTask?.cancel()
        resolving = false
        completing = false
        findingStops = false
    }
}
