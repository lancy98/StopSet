import SwiftUI
import MapKit

struct DeparturesView: View {
    let groupID: UUID
    @EnvironmentObject private var store: StopGroupStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var departures: [Departure] = []
    @State private var loading = false
    @State private var error: String?
    @State private var lastUpdated: Date?
    @State private var selectedDeparture: Departure?
    @State private var stopFilter: String?
    @State private var selectedRoutes: Set<String> = []
    @State private var showingRouteFilter = false
    @State private var showingSettings = false
    @State private var showingEditor = false
    @State private var showingStops = false
    @State private var hasKey = APIKeyStore.key != nil
    @State private var connectionRevision = 0
    @State private var requestID = UUID()
    @AppStorage(RefreshSettings.departureIntervalKey) private var refreshInterval = RefreshSettings.defaultDepartureInterval
    private let service = TransitService()

    private var group: StopGroup? { store.groups.first { $0.id == groupID } }
    private var visibleDepartures: [Departure] {
        departures.filter {
            (stopFilter == nil || $0.stop.id == stopFilter) &&
            (selectedRoutes.isEmpty || selectedRoutes.contains($0.route))
        }
    }
    private var availableRoutes: [String] {
        Set(departures.map(\.route)).union(selectedRoutes).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }
    private var routeFilterLabel: String {
        if selectedRoutes.isEmpty { return "All buses" }
        if selectedRoutes.count == 1, let route = selectedRoutes.first { return "Bus \(route)" }
        return "\(selectedRoutes.count) bus numbers"
    }
    private var refreshContext: String {
        "\(group?.stops.map(\.id).joined() ?? "")-\(connectionRevision)-\(hasKey)-\(scenePhase == .active)-\(refreshInterval)"
    }

    var body: some View {
        Group {
            if let group {
                VStack(spacing: 0) {
                    groupSummary(group)
                    if !hasKey && !AppPreview.isEnabled {
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
                .sheet(isPresented: $showingStops) { GroupStopsView(group: group) }
                .fullScreenCover(isPresented: $showingEditor) {
                    StopPickerView(group: group, onSave: store.save)
                }
            } else {
                ContentUnavailableView("Group Removed", systemImage: "mappin.slash")
            }
        }
        .sheet(item: $selectedDeparture) { VehicleMapView(departure: $0) }
        .sheet(isPresented: $showingRouteFilter) {
            routeFilterSheet
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            hasKey = APIKeyStore.key != nil
            connectionRevision += 1
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

    private func groupSummary(_ group: StopGroup) -> some View {
        let allStopsLabel = group.stops.count == 1 ? "Stop \(group.stops[0].code)" : "All \(group.stops.count) Stops"
        let layout = typeSize.isAccessibilitySize ?
            AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
            AnyLayout(HStackLayout(spacing: 10))
        return layout {
            GroupSymbol(symbol: group.displaySymbol, color: group.displayColor, size: 34)
            Menu {
                Picker("Stops", selection: $stopFilter) {
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

    private func refresh() async {
        guard let group, (hasKey || AppPreview.isEnabled), !Task.isCancelled else { return }
        let id = UUID()
        requestID = id
        loading = true
        defer { if requestID == id { loading = false } }
        do {
            let result: [Departure]
            if AppPreview.isEnabled { result = AppPreview.departures(for: group.stops) }
            else {
                guard let key = APIKeyStore.key else { return }
                result = try await service.departures(for: group.stops, key: key)
            }
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

struct DepartureRow: View {
    let departure: Departure
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let layout = typeSize.isAccessibilitySize ?
                AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
                AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                RouteBadge(route: departure.route)
                VStack(alignment: .leading, spacing: 6) {
                    Text(departure.destination.isEmpty ? departure.stop.name : departure.destination)
                        .font(.body.weight(.semibold)).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Stop \(departure.stop.code)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(departure.stop.name)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                if !typeSize.isAccessibilitySize { DepartureTime(departure: departure) }
            }
            if typeSize.isAccessibilitySize { DepartureTime(departure: departure) }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Route \(departure.route), \(departure.destination), stop \(departure.stop.code), \(departure.stop.name)")
        .accessibilityValue(departure.isLive ? "Live, \(departure.minutesAway) minutes" :
                            "Scheduled \(departure.scheduledDate.formatted(date: .omitted, time: .shortened))")
        .accessibilityHint("Shows bus location")
    }
}

struct DepartureTime: View {
    let departure: Departure

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            if departure.isLive {
                Text(departure.minutesAway == 0 ? "Due" : "\(departure.minutesAway) min")
                    .font(.title3.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.green)
                    Text("Live")
                }
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                .fixedSize()
            } else {
                Text(departure.scheduledDate, style: .time)
                    .font(.body.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.primary)
                Text("Scheduled").font(.caption).foregroundStyle(.secondary)
            }
        }
        .fixedSize()
    }
}

private struct GroupStopsView: View {
    let group: StopGroup
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StopMapView(stops: group.stops)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(group.stops) { stop in
                                HStack(spacing: 12) {
                                    Image(systemName: "bus.fill").foregroundStyle(.blue)
                                    StopLabel(stop: stop)
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                    }
                    .frame(maxHeight: 220)
                    .background(.regularMaterial)
                }
                .navigationTitle(group.stops.count == 1 ? "\(group.name) Stop" : "\(group.name) Stops")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }
    }
}
