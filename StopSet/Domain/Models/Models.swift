import Foundation
import CoreLocation

struct BusStop: Codable, Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct StopGroup: Codable, Identifiable {
    var id = UUID()
    var name: String
    var stops: [BusStop]
    var symbol: String?
    var colorName: String?

    var displaySymbol: String { symbol ?? "mappin.and.ellipse" }
    var displayColor: String { colorName ?? "blue" }
}

struct Departure: Identifiable {
    let id: String
    let route: String
    let destination: String
    let stop: BusStop
    let scheduledDate: Date
    let predictedDate: Date?
    let tripID: String
    let vehicleID: String?

    var date: Date { predictedDate ?? scheduledDate }
    var isLive: Bool { predictedDate != nil }

    var minutesAway: Int {
        max(0, Int(ceil(date.timeIntervalSinceNow / 60)))
    }
}

struct VehicleLocation {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date?
}
