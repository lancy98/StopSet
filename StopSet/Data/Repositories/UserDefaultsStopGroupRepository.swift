import Foundation
import Combine
import SwiftUI

final class UserDefaultsStopGroupRepository: ObservableObject, StopGroupRepository {
    @Published private(set) var groups: [StopGroup] = []

    var groupsPublisher: AnyPublisher<[StopGroup], Never> { $groups.eraseToAnyPublisher() }

    private let storageKey = "savedStopGroups"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = AppPreview.isEnabled ? UserDefaults(suiteName: "StopSet.UITests")! : defaults
        if AppPreview.isEnabled {
            groups = AppPreview.groups
            return
        }
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode([StopGroup].self, from: data) else { return }
        groups = stored
    }

    func save(_ group: StopGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        persist()
    }

    func delete(_ group: StopGroup) {
        groups.removeAll { $0.id == group.id }
        persist()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        groups.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    func delete(at offsets: IndexSet) {
        groups.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
