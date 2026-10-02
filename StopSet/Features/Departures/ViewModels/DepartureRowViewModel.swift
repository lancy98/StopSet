import Foundation

struct DepartureRowViewModel {
    let departure: Departure

    var destination: String { departure.destination.isEmpty ? departure.stop.name : departure.destination }
    var minutesLabel: String { departure.minutesAway == 0 ? "Due" : "\(departure.minutesAway) min" }
}
