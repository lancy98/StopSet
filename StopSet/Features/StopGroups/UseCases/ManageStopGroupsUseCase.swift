import Foundation
import Combine

@MainActor
struct ManageStopGroupsUseCase {
    private let repository: any StopGroupRepository
    init(repository: any StopGroupRepository) { self.repository = repository }
    var groups: [StopGroup] { repository.groups }
    var groupsPublisher: AnyPublisher<[StopGroup], Never> { repository.groupsPublisher }
    func save(_ group: StopGroup) { repository.save(group) }
    func delete(_ group: StopGroup) { repository.delete(group) }
    func delete(at offsets: IndexSet) { repository.delete(at: offsets) }
    func move(from offsets: IndexSet, to destination: Int) { repository.move(from: offsets, to: destination) }
}
