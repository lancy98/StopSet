import Foundation

struct GroupStopsViewModel {
    let group: StopGroup
    var title: String { group.stops.count == 1 ? "\(group.name) Stop" : "\(group.name) Stops" }
}
