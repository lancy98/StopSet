import SwiftUI
import Observation
import Combine

@MainActor
@Observable
final class DeparturesViewModel {
    let groupID: UUID
    private var groups: [StopGroup]
    var departures: [Departure] = []
    var loading = false
    var error: String?
    var lastUpdated: Date?
    var selectedDeparture: Departure?
    var stopFilter: String?
    var selectedRoutes: Set<String> = []
    var showingRouteFilter = false
    var showingSettings = false
    var showingEditor = false
    var showingStops = false
    var hasKey = false
    var connectionRevision = 0
    var requestID = UUID()
    var refreshInterval: Int
    private let groupUseCase: ManageStopGroupsUseCase
    private let settingsUseCase: ManageSettingsUseCase
    private let loadUseCase: LoadDeparturesUseCase
    private var subscription: AnyCancellable?
    init(groupID: UUID, groupUseCase: ManageStopGroupsUseCase,
         settingsUseCase: ManageSettingsUseCase,
         loadUseCase: LoadDeparturesUseCase) {
        self.groupID = groupID
        self.groupUseCase = groupUseCase
        self.settingsUseCase = settingsUseCase
        self.loadUseCase = loadUseCase
        groups = groupUseCase.groups
        hasKey = settingsUseCase.canLoadTransit
        refreshInterval = settingsUseCase.departureRefreshInterval
        subscription = groupUseCase.groupsPublisher.sink { [weak self] in self?.groups = $0 }
    }
    func reloadSettings() {
        hasKey = settingsUseCase.canLoadTransit
        refreshInterval = settingsUseCase.departureRefreshInterval
        connectionRevision += 1
    }
    var group: StopGroup? { groups.first { $0.id == groupID } }
    var visibleDepartures: [Departure] {
        departures.filter {
            (stopFilter == nil || $0.stop.id == stopFilter) &&
            (selectedRoutes.isEmpty || selectedRoutes.contains($0.route))
        }
    }
    var availableRoutes: [String] {
        Set(departures.map(\.route)).union(selectedRoutes).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }
    var routeFilterLabel: String {
        if selectedRoutes.isEmpty { return "All buses" }
        if selectedRoutes.count == 1, let route = selectedRoutes.first { return "Bus \(route)" }
        return "\(selectedRoutes.count) bus numbers"
    }

    func refresh() async {
        guard let group, hasKey, !Task.isCancelled else { return }
        let id = UUID()
        requestID = id
        loading = true
        defer { if requestID == id { loading = false } }
        do {
            let result = try await loadUseCase.execute(stops: group.stops)
            guard !Task.isCancelled, requestID == id else { return }
            departures = result
            error = nil
            lastUpdated = .now
        } catch {
            guard !Task.isCancelled, requestID == id else { return }
            self.error = error.localizedDescription
        }
    }
}
