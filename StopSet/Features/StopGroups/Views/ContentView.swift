import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppDependencies.shared.makeContentViewModel()

    private var showingEditor: Bool {
        get { viewModel.showingEditor }
        nonmutating set { viewModel.showingEditor = newValue }
    }
    private var editingGroup: StopGroup? {
        get { viewModel.editingGroup }
        nonmutating set { viewModel.editingGroup = newValue }
    }
    private var showingSettings: Bool {
        get { viewModel.showingSettings }
        nonmutating set { viewModel.showingSettings = newValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.groups.isEmpty {
                    ContentUnavailableView {
                        Label("No Stop Groups", systemImage: "mappin.and.ellipse")
                    } actions: {
                        Button("New Stop Group", systemImage: "plus") { newGroup() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(viewModel.groups) { group in
                                NavigationLink {
                                    DeparturesView(groupID: group.id)
                                } label: {
                                    HStack(spacing: 14) {
                                        GroupSymbol(symbol: group.displaySymbol, color: group.displayColor)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(group.name).font(.headline)
                                            Text(group.stops.count == 1 ? "1 stop" : "\(group.stops.count) stops")
                                                .font(.subheadline).foregroundStyle(.secondary)
                                            Text(group.stops.map(\.code).joined(separator: " · "))
                                                .font(.caption).foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .accessibilityIdentifier("group-\(group.name)")
                                .contextMenu {
                                    Button("Edit Group", systemImage: "pencil") { edit(group) }
                                    Button("Delete Group", systemImage: "trash", role: .destructive) {
                                        viewModel.delete(group)
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button("Edit", systemImage: "pencil") { edit(group) }.tint(.blue)
                                }
                            }
                            .onDelete(perform: viewModel.delete)
                            .onMove(perform: viewModel.move)
                        } header: {
                            Text("Saved Groups")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Stops")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.groups.isEmpty { EditButton() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    Button("New Stop Group", systemImage: "plus") { newGroup() }
                        .accessibilityIdentifier("new-group")
                }
            }
            .fullScreenCover(isPresented: $viewModel.showingEditor) {
                StopPickerView(group: editingGroup, onSave: { _ in })
            }
            .sheet(isPresented: $viewModel.showingSettings) { SettingsView() }
        }
        .tint(.blue)
    }

    private func newGroup() { viewModel.newGroup() }
    private func edit(_ group: StopGroup) { viewModel.edit(group) }
}
