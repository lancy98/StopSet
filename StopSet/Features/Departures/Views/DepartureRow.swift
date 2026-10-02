import SwiftUI

struct DepartureRow: View {
    private let viewModel: DepartureRowViewModel

    private var departure: Departure { viewModel.departure }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let layout = typeSize.isAccessibilitySize ?
                AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
                AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                RouteBadge(route: departure.route)
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.destination)
                        .font(.body.weight(.semibold)).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Stop \(departure.stop.code)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(departure.stop.name)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                if !typeSize.isAccessibilitySize { DepartureTime(departure: departure) }
            }
            if typeSize.isAccessibilitySize { DepartureTime(departure: departure) }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Route \(departure.route), \(departure.destination), stop \(departure.stop.code), \(departure.stop.name)")
        .accessibilityValue(departure.isLive ? "Live, \(departure.minutesAway) minutes" :
                            "Scheduled \(departure.scheduledDate.formatted(date: .omitted, time: .shortened))")
        .accessibilityHint("Shows bus location")
    }

    init(departure: Departure) { viewModel = DepartureRowViewModel(departure: departure) }
}

