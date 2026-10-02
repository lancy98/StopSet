import SwiftUI
import MapKit

struct RouteBadge: View {
    private let viewModel: RouteBadgeViewModel
    private var route: String { viewModel.route }
    init(route: String) { viewModel = RouteBadgeViewModel(route: route) }
    @ScaledMetric(relativeTo: .subheadline) private var width = 56
    @ScaledMetric(relativeTo: .subheadline) private var height = 32

    var body: some View {
        Text(route)
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .frame(width: width, height: height)
            .background(viewModel.background, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel(viewModel.accessibilityLabel)
    }
}

