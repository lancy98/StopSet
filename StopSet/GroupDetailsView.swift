import SwiftUI

struct GroupDetailsView: View {
    let group: StopGroup?
    let stops: [BusStop]
    let onSave: (StopGroup) -> Void
    @State private var name: String
    @State private var symbol: String
    @State private var color: String

    init(group: StopGroup?, stops: [BusStop], onSave: @escaping (StopGroup) -> Void) {
        self.group = group
        self.stops = stops
        self.onSave = onSave
        _name = State(initialValue: group?.name ?? "")
        _symbol = State(initialValue: group?.displaySymbol ?? "mappin.and.ellipse")
        _color = State(initialValue: group?.displayColor ?? "blue")
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    GroupSymbol(symbol: symbol, color: color, size: 80)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 12)
                TextField("Group name", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .accessibilityIdentifier("group-name")
            }
            Section("Appearance") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                    ForEach(TransitStyle.groupColors, id: \.self) { item in
                        Button { color = item } label: {
                            Circle().fill(TransitStyle.color(item))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if color == item {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.capitalized)
                        .accessibilityAddTraits(color == item ? .isSelected : [])
                    }
                    ForEach(TransitStyle.groupSymbols, id: \.self) { item in
                        Button { symbol = item } label: {
                            Image(systemName: item).font(.system(size: 20))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(symbol == item ? TransitStyle.color(color) : .secondary)
                                .background(symbol == item ? TransitStyle.color(color).opacity(0.12) : .clear, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(TransitStyle.symbolLabel(item))
                        .accessibilityAddTraits(symbol == item ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            Section(stops.count == 1 ? "1 Stop" : "\(stops.count) Stops") {
                ForEach(stops) { stop in StopLabel(stop: stop).padding(.vertical, 2) }
            }
        }
        .navigationTitle(group == nil ? "New Group" : "Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var saved = group ?? StopGroup(name: "", stops: [])
                    saved.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    saved.stops = stops
                    saved.symbol = symbol
                    saved.colorName = color
                    onSave(saved)
                }
                .fontWeight(.semibold)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stops.isEmpty)
                .accessibilityIdentifier("save-group")
            }
        }
    }
}
