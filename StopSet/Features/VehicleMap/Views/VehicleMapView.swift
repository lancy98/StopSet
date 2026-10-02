import SwiftUI
import MapKit

struct VehicleMapView: View {
    @State private var viewModel: VehicleMapViewModel

    let departure: Departure

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private var location: VehicleLocation? {
        get { viewModel.location }
        nonmutating set { viewModel.location = newValue }
    }

    private var loading: Bool {
        get { viewModel.loading }
        nonmutating set { viewModel.loading = newValue }
    }

    private var message: String? {
        get { viewModel.message }
        nonmutating set { viewModel.message = newValue }
    }

    private var camera: MapCameraPosition {
        get { viewModel.camera }
        nonmutating set { viewModel.camera = newValue }
    }

    var body: some View {
        NavigationStack {
            Map(position: $viewModel.camera) {
                Marker("Stop \(departure.stop.code)", systemImage: "mappin",
                       coordinate: departure.stop.coordinate).tint(.red)
                if let location {
                    Annotation(departure.route, coordinate: location.coordinate) {
                        Image(systemName: "bus.fill")
                            .font(.title3.weight(.semibold)).foregroundStyle(.white)
                            .frame(width: 48, height: 48).background(.blue, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            .accessibilityLabel("Bus \(departure.route)")
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            .safeAreaInset(edge: .bottom, spacing: 0) { tripDetails }
            .navigationTitle("Bus Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Recenter", systemImage: "scope") { withAnimation { recenter() } }
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await refresh() } }
                        .disabled(loading)
                }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await refresh()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(15)) } catch { break }
                    await refresh()
                }
            }
        }
        .tint(.blue)
    }

    private var tripDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    routeTitle
                    Spacer(minLength: 12)
                    TimelineView(.periodic(from: .now, by: 15)) { _ in DepartureTime(departure: departure) }
                }
                VStack(alignment: .leading, spacing: 12) {
                    routeTitle
                    DepartureTime(departure: departure)
                }
            }
            Divider()
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(.red)
                StopLabel(stop: departure.stop)
            }
            if loading && location == nil {
                HStack { ProgressView(); Text("Finding bus").font(.subheadline).foregroundStyle(.secondary) }
            } else if let message {
                Label(message, systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let timestamp = location?.timestamp {
                Label("Location updated \(timestamp.formatted(date: .omitted, time: .shortened))",
                      systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.regularMaterial)
    }

    private var routeTitle: some View {
        HStack(alignment: .top, spacing: 12) {
            RouteBadge(route: departure.route)
            Text(departure.destination.isEmpty ? departure.stop.name : departure.destination)
                .font(.headline).fixedSize(horizontal: false, vertical: true)
        }
    }

    init(departure: Departure) {
        self.departure = departure
        _viewModel = State(initialValue: AppDependencies.shared.makeVehicleMapViewModel(departure: departure))
    }

    private func refresh() async { await viewModel.refresh() }

    private func recenter() { viewModel.recenter() }
}
