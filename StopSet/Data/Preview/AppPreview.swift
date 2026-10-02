import Foundation
import CoreLocation

enum AppPreview {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }

    static let stops = [
        BusStop(id: "1063-e1383615", code: "1063", name: "Daldy Street/Gaunt Street", latitude: -36.84513, longitude: 174.7542),
        BusStop(id: "7037-03bd4aae", code: "7037", name: "Daldy Street", latitude: -36.84516, longitude: 174.75364),
        BusStop(id: "7081-ac9d80eb", code: "7081", name: "Te Waihorotiu Station", latitude: -36.84879, longitude: 174.76326)
    ]

    static let groups = [
        StopGroup(name: "Office", stops: Array(stops.prefix(2)), symbol: "building.2.fill", colorName: "blue"),
        StopGroup(name: "City Centre", stops: Array(stops.suffix(2)), symbol: "star.fill", colorName: "orange")
    ]

    static let searchableStops = stops + [
        BusStop(id: "4400-4e8cd0f3", code: "4400", name: "East Coast Bays Library", latitude: -36.71451, longitude: 174.74669),
        BusStop(id: "7500-f170b65f", code: "7500", name: "St Mary's Catholic School", latitude: -36.89584, longitude: 174.80355),
        BusStop(id: "2100-303a8542", code: "2100", name: "Bucklands Beach Road", latitude: -36.88771, longitude: 174.90994),
        BusStop(id: "2101-d62c3095", code: "2101", name: "Wycherley Drive", latitude: -36.88705, longitude: 174.91277)
    ]

    static let addresses = [
        AddressSearchResult(title: "1063 Great North Road", subtitle: "Point Chevalier, Auckland",
                            previewCoordinate: CLLocationCoordinate2D(latitude: -36.869, longitude: 174.711)),
        AddressSearchResult(title: "Queen Street", subtitle: "Auckland Central, Auckland",
                            previewCoordinate: CLLocationCoordinate2D(latitude: -36.8485, longitude: 174.7633)),
        AddressSearchResult(title: "10 Queen Street", subtitle: "Auckland Central, Auckland",
                            previewCoordinate: CLLocationCoordinate2D(latitude: -36.8445, longitude: 174.7665)),
        AddressSearchResult(title: "21 Queen Street", subtitle: "Auckland Central, Auckland",
                            previewCoordinate: CLLocationCoordinate2D(latitude: -36.845, longitude: 174.766)),
        AddressSearchResult(title: "42 Queen Street", subtitle: "Auckland Central, Auckland",
                            previewCoordinate: CLLocationCoordinate2D(latitude: -36.8455, longitude: 174.766))
    ]

    static func departures(for stops: [BusStop]) -> [Departure] {
        guard !stops.isEmpty else { return [] }
        return [("NX2", "Auckland Universities", 3), ("CTY", "K Road", 7),
                ("923", "City Centre", 12), ("82", "City Centre", 18),
                ("NX2", "Auckland Universities", 24), ("CTY", "K Road", 29)].enumerated().map { index, item in
            let date = Date().addingTimeInterval(Double(item.2 * 60))
            return Departure(id: "preview-\(index)", route: item.0, destination: item.1,
                             stop: stops[index % stops.count], scheduledDate: date,
                             predictedDate: index < 3 ? date : nil, tripID: "preview-\(index)", vehicleID: nil)
        }
    }
}
