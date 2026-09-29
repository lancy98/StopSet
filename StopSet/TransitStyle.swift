import SwiftUI
import MapKit

enum TransitStyle {
    static let groupColors = ["blue", "teal", "green", "orange", "pink", "purple"]
    static let groupSymbols = ["mappin.and.ellipse", "building.2.fill", "house.fill", "star.fill", "briefcase.fill", "heart.fill"]

    static func color(_ name: String) -> Color {
        switch name {
        case "teal": .teal
        case "green": .green
        case "orange": .orange
        case "pink": .pink
        case "purple": .purple
        default: .blue
        }
    }

    static func symbolLabel(_ name: String) -> String {
        switch name {
        case "building.2.fill": "Office"
        case "house.fill": "Home"
        case "star.fill": "Favourite"
        case "briefcase.fill": "Work"
        case "heart.fill": "Personal"
        default: "Place"
        }
    }

    static func region(for stops: [BusStop]) -> MKCoordinateRegion {
        guard let first = stops.first else { return auckland }
        let latitudes = stops.map(\.latitude)
        let longitudes = stops.map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                                                  longitude: (minLon + maxLon) / 2),
                                  span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 2, 0.009),
                                                         longitudeDelta: max((maxLon - minLon) * 2, 0.009)))
    }

    static let auckland = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -36.8485, longitude: 174.7633),
                                             span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014))
}

struct GroupSymbol: View {
    let symbol: String
    let color: String
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .semibold))
            .foregroundStyle(TransitStyle.color(color))
            .frame(width: size, height: size)
            .background(TransitStyle.color(color).opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}

struct RouteBadge: View {
    let route: String
    @ScaledMetric(relativeTo: .subheadline) private var width = 56
    @ScaledMetric(relativeTo: .subheadline) private var height = 32

    var body: some View {
        Text(route)
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .frame(width: width, height: height)
            .background(route == "CTY" ? Color.red : Color.blue, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel("Route \(route)")
    }
}

struct StopLabel: View {
    let stop: BusStop

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stop.name).font(.body).foregroundStyle(.primary)
            Text("Stop \(stop.code)").font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct StopMapView: View {
    let stops: [BusStop]
    var interactive = true

    var body: some View {
        Map(initialPosition: .region(TransitStyle.region(for: stops)),
            interactionModes: interactive ? .all : []) {
            ForEach(stops) { stop in
                Marker(stop.code, systemImage: "bus.fill", coordinate: stop.coordinate).tint(.blue)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .accessibilityLabel(stops.count == 1 ? "Map of 1 saved stop" : "Map of \(stops.count) saved stops")
    }
}
