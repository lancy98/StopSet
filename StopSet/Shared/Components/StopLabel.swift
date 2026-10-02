import SwiftUI
import MapKit

struct StopLabel: View {
    private let viewModel: StopLabelViewModel
    init(stop: BusStop) { viewModel = StopLabelViewModel(stop: stop) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.name).font(.body).foregroundStyle(.primary)
            Text(viewModel.codeLabel).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

