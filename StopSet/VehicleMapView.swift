import SwiftUI
import MapKit

struct VehicleMapView: View {
    let departure: Departure
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var location: VehicleLocation?
    @State private var loading = false
    @State private var message: String?
    @State private var camera: MapCameraPosition = .automatic
    private let service = TransitService()

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
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

    private func refresh() async {
        guard !loading, !Task.isCancelled else { return }
        loading = true
        defer { loading = false }
        do {
            let result: VehicleLocation?
            if AppPreview.isEnabled {
                result = VehicleLocation(coordinate: CLLocationCoordinate2D(
                    latitude: -36.84734,
                    longitude: 174.74995), timestamp: .now)
            } else {
                guard let key = APIKeyStore.key else {
                    message = "Add an AT API key in Settings to see bus locations."
                    return
                }
                result = try await service.vehicleLocation(tripID: departure.tripID,
                                                           vehicleID: departure.vehicleID, key: key)
            }
            guard !Task.isCancelled else { return }
            let firstLocation = location == nil
            location = result
            message = result == nil ? "No location has been reported for this bus yet." : nil
            if firstLocation { recenter() }
        } catch {
            guard !Task.isCancelled else { return }
            message = error.localizedDescription
        }
    }

    private func recenter() {
        let points = ([departure.stop.coordinate] + [location?.coordinate].compactMap { $0 }).map(MKMapPoint.init)
        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!
        let padding = max(max(maxX - minX, maxY - minY) * 0.5, 1_500)
        camera = .rect(MKMapRect(x: minX - padding, y: minY - padding,
                                width: maxX - minX + padding * 2, height: maxY - minY + padding * 2))
    }
}
