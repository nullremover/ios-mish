
import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var settings: MishSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Base theme", selection: $settings.baseTheme) {
                        ForEach(MishBaseTheme.allCases) { theme in
                            Text(theme.title)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Choose the overall look of Mish. Your selection is saved automatically.")
                }

                Section {
                    Picker("Player layout", selection: $settings.layout) {
                        ForEach(MishLayoutStyle.allCases) { layout in
                            Text(layout.title)
                                .tag(layout)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Layout")
                } footer: {
                    Text("Switch between Classic, Vinyl, Minimal, and Immersive whenever you like.")
                }

                Section {
                    Toggle(
                        "Album artwork accent",
                        isOn: $settings.albumArtAccent
                    )
                } footer: {
                    Text("Allow album artwork to influence the player's accent styling.")
                }

                Section {
                    NavigationLink {
                        LastFMSettingsView()
                    } label: {
                        Label("Last.fm / Roblox Now Playing", systemImage: "waveform")
                    }
                } footer: {
                    Text("Connect Last.fm so experiences that read your Last.fm Now Playing status can see tracks from Mish.")
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
