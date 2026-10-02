import Foundation
import Observation

@Observable
final class GroupDetailsViewModel {
    var name: String
    var symbol: String
    var color: String

    private let group: StopGroup?
    private let stops: [BusStop]
    private let useCase: SaveStopGroupUseCase

    var isSaveDisabled: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stops.isEmpty }

    init(group: StopGroup?, stops: [BusStop], useCase: SaveStopGroupUseCase) {
        self.group = group
        self.stops = stops
        self.useCase = useCase
        name = group?.name ?? ""
        symbol = group?.displaySymbol ?? "mappin.and.ellipse"
        color = group?.displayColor ?? "blue"
    }

    func save() -> StopGroup? { useCase.execute(group: group, stops: stops, name: name, symbol: symbol, color: color) }
}
