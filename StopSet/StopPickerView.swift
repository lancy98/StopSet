import SwiftUI
import MapKit

struct StopPickerView: View {
    let group: StopGroup?
    let onSave: (StopGroup) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var search = AddressSearchModel()
    @State private var camera: MapCameraPosition
    @State private var visibleCenter: CLLocationCoordinate2D
    @State private var loadedCenter: CLLocationCoordinate2D?
    @State private var stops: [BusStop] = []
    @State private var selected: [BusStop]
    @State private var focusedStop: BusStop?
    @State private var routes: [String] = []
    @State private var loadingRoutes = false
    @State private var loading = false
    @State private var message: String?
    @State private var locationName = "Nearby Stops"
    @State private var searchedLocation: CLLocationCoordinate2D?
    @State private var sheetPresented = true
    @State private var detent: PresentationDetent = .medium
    @State private var showingDetails = false
    @State private var searchPresented = false
    @State private var loadTask: Task<Void, Never>?
    @State private var routeTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?
    private let service = TransitService()

    init(group: StopGroup? = nil, onSave: @escaping (StopGroup) -> Void) {
        self.group = group
        self.onSave = onSave
        let region = TransitStyle.region(for: group?.stops ?? [])
        _selected = State(initialValue: group?.stops ?? [])
        _camera = State(initialValue: .region(region))
        _visibleCenter = State(initialValue: region.center)
    }

    private var mapStops: [BusStop] {
        stops + selected.filter { chosen in !stops.contains { $0.id == chosen.id } }
    }

    private var usesSidebar: Bool { sizeClass == .regular || verticalSizeClass == .compact }

    private var areaChanged: Bool {
        guard camera.positionedByUser, let loadedCenter else { return false }
        return CLLocation(latitude: visibleCenter.latitude, longitude: visibleCenter.longitude)
            .distance(from: CLLocation(latitude: loadedCenter.latitude, longitude: loadedCenter.longitude)) > 250
    }

    var body: some View {
        Group {
            if usesSidebar {
                HStack(spacing: 0) {
                    pickerPanel.frame(width: 380)
                    Divider()
                    map
                }
            } else {
                map
                    .sheet(isPresented: $sheetPresented) {
                        pickerPanel
                            .presentationDetents([.height(260), .medium, .large], selection: $detent)
                            .presentationDragIndicator(.visible)
                            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                            .interactiveDismissDisabled()
                    }
            }
        }
        .tint(.blue)
        .task { loadStops(at: visibleCenter) }
        .onDisappear {
            loadTask?.cancel()
            routeTask?.cancel()
            searchTask?.cancel()
            search.cancel()
        }
        .sensoryFeedback(.selection, trigger: selected.count)
    }

    private var map: some View {
        GeometryReader { geometry in
            Map(position: $camera) {
                if let searchedLocation {
                    Marker(locationName, systemImage: "mappin", coordinate: searchedLocation).tint(.orange)
                }
                ForEach(mapStops) { stop in
                    Annotation(stop.code, coordinate: stop.coordinate, anchor: .bottom) {
                        Button { focus(stop) } label: {
                            Image(systemName: isSelected(stop) ? "checkmark" : "bus.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(isSelected(stop) ? Color.green : Color.blue, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: focusedStop?.id == stop.id ? 4 : 2))
                                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stop \(stop.code), \(stop.name)")
                        .accessibilityValue(isSelected(stop) ? "Selected" : "Not selected")
                        .accessibilityIdentifier("map-stop-\(stop.code)")
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            .onMapCameraChange(frequency: .onEnd) { visibleCenter = $0.region.center }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !usesSidebar {
                    Color.clear.frame(height: detent == .height(260) ? 300 : geometry.size.height * 0.5 + 60)
                        .allowsHitTesting(false)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if areaChanged && !showingDetails {
                    Button {
                        loadStops(at: visibleCenter)
                        locationName = "Nearby Stops"
                    } label: {
                        Label("Search This Area", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .padding(.top, 12)
                    .disabled(loading)
                }
            }
        }
    }

    private var pickerPanel: some View {
        NavigationStack {
            List {
                if searchPresented && !search.query.isEmpty {
                    searchResults
                } else {
                    if let focusedStop {
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    StopLabel(stop: focusedStop)
                                    Spacer(minLength: 12)
                                    selectionButton(focusedStop)
                                }
                                if loadingRoutes {
                                    ProgressView().controlSize(.small)
                                } else if !routes.isEmpty {
                                    Text("Nearby routes: \(routes.joined(separator: ", "))")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    if !selected.isEmpty {
                        Section("Selected · \(selected.count)") {
                            ForEach(selected) { stop in stopRow(stop) }
                        }
                    }
                    Section {
                        if loading {
                            HStack {
                                ProgressView()
                                Text("Finding stops").foregroundStyle(.secondary)
                            }
                        } else if let message {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(message).foregroundStyle(.secondary)
                                Button("Try Again", systemImage: "arrow.clockwise") { loadStops(at: visibleCenter) }
                            }
                        } else if stops.isEmpty {
                            ContentUnavailableView("No Nearby Stops", systemImage: "mappin.slash",
                                                   description: Text("Try another address or area."))
                        } else {
                            ForEach(stops.filter { !isSelected($0) }) { stop in stopRow(stop) }
                        }
                    } header: {
                        Text(locationName)
                    } footer: {
                        if selected.isEmpty { Text("Choose at least 1 stop.") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(group == nil ? "Choose Stops" : "Edit Stops")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search.query, isPresented: $searchPresented,
                        placement: .navigationBarDrawer(displayMode: .always), prompt: "Search address or stop number")
            .onSubmit(of: .search) {
                if search.stopNumber != nil { search.findStops(debounce: false) }
                else { findAddress() }
            }
            .onChange(of: searchPresented) { _, active in if active { detent = .large } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { close() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") {
                        detent = .large
                        searchPresented = false
                        showingDetails = true
                    }
                    .fontWeight(.semibold)
                    .disabled(selected.isEmpty)
                    .accessibilityIdentifier("picker-next")
                }
            }
            .navigationDestination(isPresented: $showingDetails) {
                GroupDetailsView(group: group, stops: selected) { saved in
                    onSave(saved)
                    close()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { close() } }
                }
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if search.stopNumber != nil && (search.findingStops || search.stopError != nil || !search.stopResults.isEmpty) {
            Section {
                if search.findingStops {
                    HStack { ProgressView(); Text("Finding stops").foregroundStyle(.secondary) }
                } else if let error = search.stopError {
                    Text(error).foregroundStyle(.secondary)
                    Button("Try Again", systemImage: "arrow.clockwise") { search.findStops(debounce: false) }
                } else {
                    ForEach(search.stopResults) { stop in
                        Button { showSearchStop(stop) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bus.fill").foregroundStyle(.blue)
                                StopLabel(stop: stop)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("search-stop-\(stop.code)")
                    }
                }
            } header: {
                Text("Stops").accessibilityIdentifier("search-stops-heading")
            }
        }
        Section("Addresses") {
            if search.resolving || (search.completing && search.completions.isEmpty) {
                HStack { ProgressView(); Text("Finding address").foregroundStyle(.secondary) }
            }
            if let error = search.error {
                Text(error).foregroundStyle(.secondary)
            } else if !search.completing && !search.resolving && search.completions.isEmpty {
                Text("No matching addresses. Try a street name or suburb.").foregroundStyle(.secondary)
            }
            ForEach(search.completions) { completion in
                Button { findAddress(completion) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(completion.title).foregroundStyle(.primary)
                            Text(completion.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("search-address-\(completion.title)")
            }
        }
    }

    private func stopRow(_ stop: BusStop) -> some View {
        HStack(spacing: 12) {
            Button { focus(stop) } label: {
                StopLabel(stop: stop).frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            selectionButton(stop)
        }
        .padding(.vertical, 4)
    }

    private func selectionButton(_ stop: BusStop) -> some View {
        Button {
            if isSelected(stop) { selected.removeAll { $0.id == stop.id } }
            else { selected.append(stop) }
        } label: {
            Image(systemName: isSelected(stop) ? "checkmark.circle.fill" : "plus.circle")
                .font(.title2)
                .foregroundStyle(isSelected(stop) ? Color.green : Color.blue)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(isSelected(stop) ? "Remove" : "Add") stop \(stop.code)")
        .accessibilityIdentifier("select-\(stop.code)")
    }

    private func isSelected(_ stop: BusStop) -> Bool {
        selected.contains { $0.id == stop.id }
    }

    private func focus(_ stop: BusStop) {
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
            let nearby = AppPreview.isEnabled ? ["CTY", "NX2", "923"] :
                ((try? await service.nearbyRoutes(at: stop.coordinate)) ?? [])
            guard !Task.isCancelled, focusedStop?.id == stop.id else { return }
            routes = nearby
            loadingRoutes = false
        }
    }

    private func findAddress(_ completion: AddressSearchResult? = nil) {
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

    private func showSearchStop(_ stop: BusStop) {
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

    private func loadStops(at coordinate: CLLocationCoordinate2D) {
        loadTask?.cancel()
        focusedStop = nil
        stops = []
        loading = true
        message = nil
        loadTask = Task {
            do {
                let result = AppPreview.isEnabled ? AppPreview.stops : try await service.nearbyStops(at: coordinate)
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

    private func close() {
        sheetPresented = false
        dismiss()
    }
}
