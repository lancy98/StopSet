import SwiftUI
import MapKit

struct DeparturesView: View {
    @State private var viewModel: DeparturesViewModel

    let groupID: UUID

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    private var group: StopGroup? { viewModel.group }
    private var visibleDepartures: [Departure] { viewModel.visibleDepartures }
    private var availableRoutes: [String] { viewModel.availableRoutes }
    private var routeFilterLabel: String { viewModel.routeFilterLabel }
    private var refreshInterval: Int { viewModel.refreshInterval }

    private var refreshContext: String {
        "\(group?.stops.map(\.id).joined() ?? "")-\(connectionRevision)-\(hasKey)-\(scenePhase == .active)-\(refreshInterval)"
    }

    private var departures: [Departure] {
        get { viewModel.departures }
        nonmutating set { viewModel.departures = newValue }
    }

    private var loading: Bool {
        get { viewModel.loading }
        nonmutating set { viewModel.loading = newValue }
    }

    private var error: String? {
        get { viewModel.error }
        nonmutating set { viewModel.error = newValue }
    }

    private var lastUpdated: Date? {
        get { viewModel.lastUpdated }
        nonmutating set { viewModel.lastUpdated = newValue }
    }

    private var selectedDeparture: Departure? {
        get { viewModel.selectedDeparture }
        nonmutating set { viewModel.selectedDeparture = newValue }
    }

    private var stopFilter: String? {
        get { viewModel.stopFilter }
        nonmutating set { viewModel.stopFilter = newValue }
    }

    private var selectedRoutes: Set<String> {
        get { viewModel.selectedRoutes }
        nonmutating set { viewModel.selectedRoutes = newValue }
    }

    private var showingRouteFilter: Bool {
        get { viewModel.showingRouteFilter }
        nonmutating set { viewModel.showingRouteFilter = newValue }
    }

    private var showingSettings: Bool {
        get { viewModel.showingSettings }
        nonmutating set { viewModel.showingSettings = newValue }
    }

    private var showingEditor: Bool {
        get { viewModel.showingEditor }
        nonmutating set { viewModel.showingEditor = newValue }
    }

    private var showingStops: Bool {
        get { viewModel.showingStops }
        nonmutating set { viewModel.showingStops = newValue }
    }

    private var hasKey: Bool {
        get { viewModel.hasKey }
        nonmutating set { viewModel.hasKey = newValue }
    }

    private var connectionRevision: Int {
        get { viewModel.connectionRevision }
        nonmutating set { viewModel.connectionRevision = newValue }
    }

    var body: some View {
        Group {
            if let group {
                VStack(spacing: 0) {
                    groupSummary(group)
                    if !hasKey {
                        ContentUnavailableView {
                            Label("Connect to AT", systemImage: "dot.radiowaves.left.and.right")
                        } description: {
                            Text("An Auckland Transport API key is needed for departure times and bus locations.")
                        } actions: {
                            Button("Open Settings") { showingSettings = true }.buttonStyle(.borderedProminent)
                        }
                    } else {
                        departureBoard
                    }
                }
                .navigationTitle(group.name)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Stops Map", systemImage: "map") { showingStops = true }
                            .accessibilityIdentifier("stops-map")
                        Menu {
                            Button("Edit Group", systemImage: "pencil") { showingEditor = true }
                            Button("Refresh", systemImage: "arrow.clockwise") { Task { await refresh() } }
                                .disabled(loading)
                            Button("Settings", systemImage: "gearshape") { showingSettings = true }
                        } label: { Label("More", systemImage: "ellipsis") }
                        .accessibilityIdentifier("group-menu")
                    }
                }
                .sheet(isPresented: $viewModel.showingStops) { GroupStopsView(group: group) }
                .fullScreenCover(isPresented: $viewModel.showingEditor) {
                    StopPickerView(group: group, onSave: { _ in })
                }
            } else {
                ContentUnavailableView("Group Removed", systemImage: "mappin.slash")
            }
        }
        .sheet(item: $viewModel.selectedDeparture) { VehicleMapView(departure: $0) }
        .sheet(isPresented: $viewModel.showingRouteFilter) {
            routeFilterSheet
        }
        .sheet(isPresented: $viewModel.showingSettings, onDismiss: {
            viewModel.reloadSettings()
        }) { SettingsView() }
        .task(id: refreshContext) {
            guard scenePhase == .active else { return }
            if let filter = stopFilter, group?.stops.contains(where: { $0.id == filter }) != true { stopFilter = nil }
            await refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(refreshInterval)) } catch { break }
                await refresh()
            }
        }
    }

    private var routeFilterSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button { selectedRoutes.removeAll() } label: {
                        HStack {
                            Text("All buses")
                            Spacer()
                            if selectedRoutes.isEmpty { Image(systemName: "checkmark") }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityValue(selectedRoutes.isEmpty ? "Selected" : "Not selected")
                    .accessibilityIdentifier("route-filter-all")
                }
                Section {
                    ForEach(availableRoutes, id: \.self) { route in
                        Button {
                            if selectedRoutes.contains(route) { selectedRoutes.remove(route) }
                            else { selectedRoutes.insert(route) }
                        } label: {
                            HStack {
                                RouteBadge(route: route)
                                Spacer()
                                Image(systemName: selectedRoutes.contains(route) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedRoutes.contains(route) ? Color.accentColor : Color.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Bus \(route)")
                        .accessibilityValue(selectedRoutes.contains(route) ? "Selected" : "Not selected")
                        .accessibilityIdentifier("route-filter-\(route)")
                    }
                } header: {
                    Text("Bus numbers")
                } footer: {
                    Text(availableRoutes.isEmpty ? "Bus numbers will appear when departures are available." :
                         "Select one or more bus numbers. With none selected, all buses are shown.")
                }
            }
            .navigationTitle("Bus Numbers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingRouteFilter = false }
                }
            }
        }
    }

    private var departureBoard: some View {
        List {
            if let error, !departures.isEmpty {
                Section {
                    Label(error, systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Try Again", systemImage: "arrow.clockwise") { Task { await refresh() } }
                }
            }
            Section {
                if loading && departures.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Loading departures").padding(.vertical, 60)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if let error, departures.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't Load Departures", systemImage: "wifi.exclamationmark")
                    } description: { Text(error) } actions: {
                        Button("Try Again", systemImage: "arrow.clockwise") { Task { await refresh() } }
                    }
                    .listRowSeparator(.hidden)
                } else if visibleDepartures.isEmpty {
                    ContentUnavailableView {
                        Label(selectedRoutes.isEmpty ? "No Upcoming Buses" : "No Matching Buses", systemImage: "clock")
                    } description: {
                        Text(selectedRoutes.isEmpty ? "No departures in the next two hours." :
                             "No departures for the selected bus numbers at these stops in the next two hours.")
                    } actions: {
                        if !selectedRoutes.isEmpty {
                            Button("Show All Buses") { selectedRoutes.removeAll() }
                        }
                    }
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(visibleDepartures) { departure in
                        Button { selectedDeparture = departure } label: {
                            TimelineView(.periodic(from: .now, by: 15)) { _ in
                                DepartureRow(departure: departure)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("departure-\(departure.id)")
                        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .alignmentGuide(.listRowSeparatorTrailing) { $0.width }
                    }
                }
            } header: {
                let layout = typeSize.isAccessibilitySize ?
                    AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) :
                    AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                layout {
                    Text("Departures").font(.headline).foregroundStyle(.primary)
                    if !typeSize.isAccessibilitySize { Spacer() }
                    if let lastUpdated {
                        Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .textCase(nil).padding(.bottom, 8)
            }
        }
        .listStyle(.plain)
        .contentMargins(.top, 0, for: .scrollContent)
        .refreshable { await refresh() }
    }

    init(groupID: UUID) {
        self.groupID = groupID
        _viewModel = State(initialValue: AppDependencies.shared.makeDeparturesViewModel(groupID: groupID))
    }

    private func groupSummary(_ group: StopGroup) -> some View {
        let allStopsLabel = group.stops.count == 1 ? "Stop \(group.stops[0].code)" : "All \(group.stops.count) Stops"
        let layout = typeSize.isAccessibilitySize ?
            AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
            AnyLayout(HStackLayout(spacing: 10))
        return layout {
            GroupSymbol(symbol: group.displaySymbol, color: group.displayColor, size: 34)
            Menu {
                Picker("Stops", selection: $viewModel.stopFilter) {
                    Text(allStopsLabel).tag(String?.none)
                    ForEach(group.stops) { stop in
                        Text("\(stop.code) · \(stop.name)").tag(Optional(stop.id))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(stopFilter.flatMap { id in group.stops.first { $0.id == id }.map { "Stop \($0.code)" } }
                         ?? allStopsLabel)
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                }
                .font(.subheadline.weight(.medium))
            }
            .accessibilityIdentifier("stop-filter")
            if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
            Button { showingRouteFilter = true } label: {
                Label(routeFilterLabel, systemImage: "line.3.horizontal.decrease")
                    .font(.subheadline.weight(.medium))
            }
            .accessibilityLabel("Bus numbers")
            .accessibilityValue(routeFilterLabel)
            .accessibilityIdentifier("route-filter")
            if loading && !departures.isEmpty { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 8)
    }

    private func refresh() async { await viewModel.refresh() }

}

