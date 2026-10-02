import SwiftUI
import MapKit
import Observation

@Observable
final class StopPickerViewModel {
    var search: AddressSearchViewModel
    var camera: MapCameraPosition
    var visibleCenter: CLLocationCoordinate2D
    var loadedCenter: CLLocationCoordinate2D?
    var stops: [BusStop] = []
    var selected: [BusStop]
    var focusedStop: BusStop?
    var routes: [String] = []
    var loadingRoutes = false
    var loading = false
    var message: String?
    var locationName = "Nearby Stops"
    var searchedLocation: CLLocationCoordinate2D?
    var sheetPresented = true
    var detent: PresentationDetent = .medium
    var showingDetails = false
    var searchPresented = false
    var loadTask: Task<Void, Never>?
    var routeTask: Task<Void, Never>?
    var searchTask: Task<Void, Never>?

    private let useCase: DiscoverStopsUseCase

    var mapStops: [BusStop] {
        stops + selected.filter { chosen in !stops.contains { $0.id == chosen.id } }
    }

    var areaChanged: Bool {
        guard camera.positionedByUser, let loadedCenter else { return false }
        return CLLocation(latitude: visibleCenter.latitude, longitude: visibleCenter.longitude)
            .distance(from: CLLocation(latitude: loadedCenter.latitude, longitude: loadedCenter.longitude)) > 250
    }

    init(group: StopGroup?, useCase: DiscoverStopsUseCase,
         addressUseCase: SearchAddressesUseCase) {
        self.useCase = useCase
        search = AddressSearchViewModel(useCase: addressUseCase)
        let region = TransitStyle.region(for: group?.stops ?? [])
        selected = group?.stops ?? []
        camera = .region(region)
        visibleCenter = region.center
    }

    func cancel() {
        loadTask?.cancel()
        routeTask?.cancel()
        searchTask?.cancel()
        search.cancel()
    }

    func toggleSelection(_ stop: BusStop) {
        if isSelected(stop) { selected.removeAll { $0.id == stop.id } }
        else { selected.append(stop) }
    }

    func isSelected(_ stop: BusStop) -> Bool {
        selected.contains { $0.id == stop.id }
    }

    func focus(_ stop: BusStop) {
        focusedStop = stop
        routes = []
        searchPresented = false
        detent = .medium
        withAnimation {
            camera = .region(MKCoordinateRegion(center: stop.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)))
        }
        routeTask?.cancel()
        loadingRoutes = true
        routeTask = Task {
            let nearby = (try? await useCase.nearbyRoutes(at: stop.coordinate)) ?? []
            guard !Task.isCancelled, focusedStop?.id == stop.id else { return }
            routes = nearby
            loadingRoutes = false
        }
    }

    func findAddress(_ completion: AddressSearchResult? = nil) {
        searchTask?.cancel()
        searchTask = Task {
            guard let item = await search.resolve(completion), !Task.isCancelled else { return }
            searchPresented = false
            search.query = ""
            locationName = item.name ?? "Nearby Stops"
            let coordinate = item.placemark.coordinate
            searchedLocation = coordinate
            withAnimation {
                camera = .region(MKCoordinateRegion(center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)))
            }
            detent = .medium
            loadStops(at: coordinate)
        }
    }

    func showSearchStop(_ stop: BusStop) {
        loadTask?.cancel()
        loading = false
        message = nil
        stops = [stop]
        loadedCenter = stop.coordinate
        searchedLocation = nil
        locationName = "Search Results"
        search.query = ""
        focus(stop)
    }

    func loadStops(at coordinate: CLLocationCoordinate2D) {
        loadTask?.cancel()
        focusedStop = nil
        stops = []
        loading = true
        message = nil
        loadTask = Task {
            do {
                let result = try await useCase.nearbyStops(at: coordinate)
                guard !Task.isCancelled else { return }
                stops = result
                loadedCenter = coordinate
                if !result.isEmpty {
                    withAnimation { camera = .region(TransitStyle.region(for: result)) }
                }
            } catch {
                guard !Task.isCancelled else { return }
                message = "Couldn't load nearby stops. Check your connection."
            }
            loading = false
        }
    }

}
