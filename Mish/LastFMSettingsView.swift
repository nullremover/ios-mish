import SwiftUI

struct LastFMSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = LastFMClient.savedAPIKey
    @State private var apiSecret = ""
    @State private var connectedUsername = LastFMClient.connectedUsername
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    private var canAuthorize: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!apiSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || LastFMClient.hasSavedSecret)
            && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)

                    SecureField("API shared secret", text: $apiSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                } header: {
                    Text("Last.fm API credentials")
                } footer: {
                    Text(LastFMClient.hasSavedSecret
                         ? "Your shared secret is already stored in iOS Keychain. Leave the field blank to keep it, or enter a replacement."
                         : "Create an API account on Last.fm and enter its API key and shared secret. Mish stores the shared secret in iOS Keychain.")
                }

                Section {
                    if let connectedUsername {
                        Label("Connected as \(connectedUsername)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not connected", systemImage: "circle.dashed")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await authorize() }
                    } label: {
                        HStack {
                            Text("Save credentials and authorize")
                            Spacer()
                            if isWorking { ProgressView() }
                        }
                    }
                    .disabled(!canAuthorize)

                    Button("I've approved Mish, finish connection") {
                        Task { await finishConnection() }
                    }
                    .disabled(isWorking || !LastFMClient.hasSavedSecret || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if connectedUsername != nil {
                        Button("Disconnect Last.fm", role: .destructive) {
                            LastFMClient.disconnect()
                            connectedUsername = nil
                            statusIsError = false
                            statusMessage = "Disconnected. Your API key and shared secret remain saved on this device."
                        }
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Mish opens Last.fm in your browser for approval. After approving it, return here and tap the finish button. Track changes are sent as Now Playing updates; this does not submit scrobbles.")
                }

                if let statusMessage {
                    Section("Status") {
                        Text(statusMessage)
                            .foregroundStyle(statusIsError ? .red : .secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Last.fm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func authorize() async {
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            try LastFMClient.configure(apiKey: apiKey, secret: apiSecret)
            apiSecret = ""
            let url = try await LastFMClient.beginAuthorization()
            openURL(url)
            statusIsError = false
            statusMessage = "Approve Mish on Last.fm in the browser. Then return to this screen and tap ‘I've approved Mish, finish connection’."
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func finishConnection() async {
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            // Also save a changed API key/secret if the user entered one here.
            try LastFMClient.configure(apiKey: apiKey, secret: apiSecret)
            apiSecret = ""
            let username = try await LastFMClient.finishAuthorization()
            connectedUsername = username
            statusIsError = false
            statusMessage = "Mish is connected to Last.fm. Start a track to publish Now Playing information."
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }
}
