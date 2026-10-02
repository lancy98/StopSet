import Foundation

/// Composition root: concrete data implementations are selected only here.
@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let saveGroup: SaveStopGroupUseCase
    let groups: ManageStopGroupsUseCase
    let settings: ManageSettingsUseCase
    let departures: LoadDeparturesUseCase
    let vehicleLocation: LoadVehicleLocationUseCase
    let discoverStops: DiscoverStopsUseCase
    private let transitRepository: any TransitRepository

    init() {
        let groupRepository = UserDefaultsStopGroupRepository()
        let settingsRepository = DeviceSettingsRepository()
        let transitRepository: any TransitRepository = AppPreview.isEnabled ? PreviewTransitRepository() : ATTransitRepository()
        self.transitRepository = transitRepository
        saveGroup = SaveStopGroupUseCase(repository: groupRepository)
        groups = ManageStopGroupsUseCase(repository: groupRepository)
        settings = ManageSettingsUseCase(repository: settingsRepository, allowsSampleData: AppPreview.isEnabled)
        departures = LoadDeparturesUseCase(repository: transitRepository, settings: settingsRepository)
        vehicleLocation = LoadVehicleLocationUseCase(repository: transitRepository, settings: settingsRepository)
        discoverStops = DiscoverStopsUseCase(repository: transitRepository)
    }

    func makeContentViewModel() -> ContentViewModel {
        ContentViewModel(useCase: groups)
    }
    func makeDeparturesViewModel(groupID: UUID) -> DeparturesViewModel {
        DeparturesViewModel(groupID: groupID, groupUseCase: groups, settingsUseCase: settings, loadUseCase: departures)
    }
    func makeVehicleMapViewModel(departure: Departure) -> VehicleMapViewModel {
        VehicleMapViewModel(departure: departure, loadUseCase: vehicleLocation, settingsUseCase: settings)
    }
    func makeSettingsViewModel() -> SettingsViewModel { SettingsViewModel(useCase: settings) }
    func makeGroupDetailsViewModel(group: StopGroup?, stops: [BusStop]) -> GroupDetailsViewModel {
        GroupDetailsViewModel(group: group, stops: stops, useCase: saveGroup)
    }
    func makeStopPickerViewModel(group: StopGroup?) -> StopPickerViewModel {
        StopPickerViewModel(group: group, useCase: discoverStops, addressUseCase: makeAddressSearchUseCase())
    }

    func makeAddressSearchUseCase() -> SearchAddressesUseCase {
        SearchAddressesUseCase(repository: AppleMapsAddressSearchRepository(transitRepository: transitRepository))
    }
}
