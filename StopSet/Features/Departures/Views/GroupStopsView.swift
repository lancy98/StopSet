import SwiftUI

struct GroupStopsView: View {
    private let viewModel: GroupStopsViewModel
    private var group: StopGroup { viewModel.group }
    init(group: StopGroup) { viewModel = GroupStopsViewModel(group: group) }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StopMapView(stops: group.stops)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(group.stops) { stop in
                                HStack(spacing: 12) {
                                    Image(systemName: "bus.fill").foregroundStyle(.blue)
                                    StopLabel(stop: stop)
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                    }
                    .frame(maxHeight: 220)
                    .background(.regularMaterial)
                }
                .navigationTitle(viewModel.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }
    }
}
