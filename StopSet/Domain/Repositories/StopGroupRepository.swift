import Foundation
import Combine

@MainActor
protocol StopGroupRepository {
    var groups: [StopGroup] { get }
    var groupsPublisher: AnyPublisher<[StopGroup], Never> { get }
    func save(_ group: StopGroup)
    func delete(_ group: StopGroup)
    func delete(at offsets: IndexSet)
    func move(from offsets: IndexSet, to destination: Int)
}
