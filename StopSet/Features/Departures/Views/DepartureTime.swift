import SwiftUI

struct DepartureTime: View {
    private let viewModel: DepartureTimeViewModel
    private var departure: Departure { viewModel.departure }
    init(departure: Departure) { viewModel = DepartureTimeViewModel(departure: departure) }

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            if departure.isLive {
                Text(viewModel.minutesLabel)
                    .font(.title3.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.green)
                    Text("Live")
                }
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                .fixedSize()
            } else {
                Text(departure.scheduledDate, style: .time)
                    .font(.body.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.primary)
                Text("Scheduled").font(.caption).foregroundStyle(.secondary)
            }
        }
        .fixedSize()
    }
}

