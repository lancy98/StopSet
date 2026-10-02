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

