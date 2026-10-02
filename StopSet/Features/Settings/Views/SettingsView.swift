import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AppDependencies.shared.makeSettingsViewModel()
    private var departureRefreshInterval: Int { viewModel.departureRefreshInterval }

    private var key: String {
        get { viewModel.key }
        nonmutating set { viewModel.key = newValue }
    }
    private var hasKey: Bool {
        get { viewModel.hasKey }
        nonmutating set { viewModel.hasKey = newValue }
    }
    private var status: String? {
        get { viewModel.status }
        nonmutating set { viewModel.status = newValue }
    }
    private var confirmingRemoval: Bool {
        get { viewModel.confirmingRemoval }
        nonmutating set { viewModel.confirmingRemoval = newValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "bus.fill")
                            .font(.title2).foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auckland Transport").font(.headline)
                            Label(hasKey ? "Key saved" : "Not connected",
                                  systemImage: hasKey ? "checkmark.circle.fill" : "circle")
                                .font(.subheadline)
                                .foregroundStyle(hasKey ? .green : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    SecureField("Subscription key", text: $viewModel.key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: key) { status = nil }
                    Button("Save Key") {
                        viewModel.saveKey()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let status { Text(status).font(.footnote).foregroundStyle(.secondary) }
                } header: {
                    Text("Data Connection")
                } footer: {
                    Text("Your AT subscription needs Realtime and GTFS access. The key is stored in this device's Keychain.")
                }
                Section {
                    Picker("Departures", selection: $viewModel.departureRefreshInterval) {
                        ForEach(RefreshSettings.departureIntervals, id: \.self) { interval in
                            Text("Every \(interval) seconds").tag(interval)
                        }
                    }
                    .accessibilityIdentifier("departure-refresh-interval")
                } header: {
                    Text("Auto Refresh")
                } footer: {
                    Text("Departure times refresh every \(departureRefreshInterval) seconds by default while the app is active.")
                }
                Section {
                    Link(destination: URL(string: "https://dev-portal.at.govt.nz/")!) {
                        Label("AT Developer Portal", systemImage: "arrow.up.right.square")
                    }
                    if hasKey {
                        Button("Remove Key", role: .destructive) { confirmingRemoval = true }
                    }
                }
                Section {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Transport data", value: "Auckland Transport")
                } header: { Text("About") }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Remove the saved key?", isPresented: $viewModel.confirmingRemoval, titleVisibility: .visible) {
                Button("Remove Key", role: .destructive) {
                    viewModel.removeKey()
                }
            }
        }
        .tint(.blue)
    }
}
