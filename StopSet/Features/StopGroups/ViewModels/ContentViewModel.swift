import SwiftUI
import Observation
import Combine

@Observable
final class ContentViewModel {
    private(set) var groups: [StopGroup]

    var showingEditor = false
    var editingGroup: StopGroup?
    var showingSettings = false

    private let useCase: ManageStopGroupsUseCase
    private var subscription: AnyCancellable?

    init(useCase: ManageStopGroupsUseCase) {
        self.useCase = useCase
        groups = useCase.groups
        subscription = useCase.groupsPublisher.sink { [weak self] in self?.groups = $0 }
    }

    func save(_ group: StopGroup) { useCase.save(group) }

    func delete(_ group: StopGroup) { useCase.delete(group) }

    func delete(at offsets: IndexSet) { useCase.delete(at: offsets) }

    func move(from offsets: IndexSet, to destination: Int) { useCase.move(from: offsets, to: destination) }

    func newGroup() { editingGroup = nil; showingEditor = true }

    func edit(_ group: StopGroup) { editingGroup = group; showingEditor = true }
}
