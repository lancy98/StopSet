import SwiftUI

struct ContentView: View {
    @StateObject private var store = StopGroupStore()
    @State private var showingEditor = false
    @State private var editingGroup: StopGroup?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.groups.isEmpty {
                    ContentUnavailableView {
                        Label("No Stop Groups", systemImage: "mappin.and.ellipse")
                    } actions: {
                        Button("New Stop Group", systemImage: "plus") { newGroup() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.groups) { group in
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
                                        store.delete(group)
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button("Edit", systemImage: "pencil") { edit(group) }.tint(.blue)
                                }
                            }
                            .onDelete(perform: store.delete)
                            .onMove(perform: store.move)
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
                    if !store.groups.isEmpty { EditButton() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    Button("New Stop Group", systemImage: "plus") { newGroup() }
                        .accessibilityIdentifier("new-group")
                }
            }
            .fullScreenCover(isPresented: $showingEditor) {
                StopPickerView(group: editingGroup, onSave: store.save)
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
        .environmentObject(store)
        .tint(.blue)
    }

    private func newGroup() {
        editingGroup = nil
        showingEditor = true
    }

    private func edit(_ group: StopGroup) {
        editingGroup = group
        showingEditor = true
    }
}
