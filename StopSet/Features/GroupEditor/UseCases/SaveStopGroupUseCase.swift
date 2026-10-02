import Foundation

@MainActor
struct SaveStopGroupUseCase {
    private let repository: any StopGroupRepository
    init(repository: any StopGroupRepository) { self.repository = repository }
    func execute(group: StopGroup?, stops: [BusStop], name: String, symbol: String, color: String) -> StopGroup? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !stops.isEmpty else { return nil }
        var saved = group ?? StopGroup(name: "", stops: [])
        saved.name = name
        saved.stops = stops
        saved.symbol = symbol
        saved.colorName = color
        repository.save(saved)
        return saved
    }
}
