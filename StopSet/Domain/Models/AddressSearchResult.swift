import MapKit

struct AddressSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    var completion: MKLocalSearchCompletion?
    var previewCoordinate: CLLocationCoordinate2D?
}

