
import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var player: PlayerModel

    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            Group {
                if player.playlists.isEmpty {
                    ContentUnavailableView {
                        Label("No Playlists Yet", systemImage: "music.note.list")
                    } description: {
                        Text("Create a playlist and collect your favorite tracks.")
                    } actions: {
                        Button("Create Playlist") {
                            showingCreatePlaylist = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(player.playlists) { playlist in
                            NavigationLink {
                                PlaylistDetailView(playlistID: playlist.id)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "music.note.list")
                                        .font(.title2)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            Color.secondary.opacity(0.15)
                                        )
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 10)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .font(.headline)

                                        Text("\(playlist.trackCount) tracks")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    player.deletePlaylist(id: playlist.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newPlaylistName = ""
                        showingCreatePlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Playlist")
                }
            }
            .alert("New Playlist", isPresented: $showingCreatePlaylist) {
                TextField("Playlist name", text: $newPlaylistName)

                Button("Create") {
                    player.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }

                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
            } message: {
                Text("Give your playlist a name.")
            }
        }
    }
}

private struct PlaylistDetailView: View {
    @EnvironmentObject var player: PlayerModel

    let playlistID: UUID

    @State private var showingAddTracks = false

    private var playlist: MishPlaylist? {
        player.playlists.first { $0.id == playlistID }
    }

    var body: some View {
        Group {
            if let playlist {
                List {
                    if playlist.trackPaths.isEmpty {
                        ContentUnavailableView(
                            "No Tracks Yet",
                            systemImage: "music.note",
                            description: Text(
                                "Tap + to add music from your library."
                            )
                        )
                    } else {
                        ForEach(
                            Array(playlist.trackPaths.enumerated()),
                            id: \.offset
                        ) { index, path in
                            trackRow(path: path, index: index)
                        }
                        .onMove { source, destination in
                            player.reorderPlaylist(
                                id: playlistID,
                                from: source,
                                to: destination
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle(playlist.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingAddTracks = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Tracks")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
                .sheet(isPresented: $showingAddTracks) {
                    AddTracksView(playlistID: playlistID)
                        .environmentObject(player)
                }
            } else {
                ContentUnavailableView(
                    "Playlist Not Found",
                    systemImage: "music.note.list"
                )
            }
        }
    }

    @ViewBuilder
    private func trackRow(path: String, index: Int) -> some View {
        let track = player.tracks.first {
            $0.url.standardizedFileURL.absoluteString == path
        }

        HStack(spacing: 12) {
            if let track, let artwork = track.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "music.note")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(track?.title ?? URL(string: path)?.lastPathComponent ?? path)
                    .lineLimit(1)

                Text(track?.artist ?? "File unavailable in library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button(role: .destructive) {
                player.removeFromPlaylist(id: playlistID, at: index)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove from Playlist")
        }
        .padding(.vertical, 3)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                player.removeFromPlaylist(id: playlistID, at: index)
            } label: {
                Label("Remove", systemImage: "minus.circle")
            }
        }
    }
}

private struct AddTracksView: View {
    @EnvironmentObject var player: PlayerModel
    @Environment(\.dismiss) private var dismiss

    let playlistID: UUID

    private var playlist: MishPlaylist? {
        player.playlists.first { $0.id == playlistID }
    }

    var body: some View {
        NavigationStack {
            List {
                if player.tracks.isEmpty {
                    ContentUnavailableView(
                        "Library Is Empty",
                        systemImage: "music.note",
                        description: Text(
                            "Import music into Mish before adding tracks."
                        )
                    )
                } else {
                    ForEach(player.tracks) { track in
                        let path = track.url.standardizedFileURL.absoluteString
                        let alreadyAdded =
                            playlist?.trackPaths.contains(path) ?? false

                        Button {
                            player.addToPlaylist(
                                id: playlistID,
                                track: track
                            )
                        } label: {
                            HStack(spacing: 12) {
                                if let artwork = track.artwork {
                                    Image(uiImage: artwork)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 6)
                                        )
                                } else {
                                    Image(systemName: "music.note")
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Color.secondary.opacity(0.15)
                                        )
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 6)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text(track.artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(
                                    systemName: alreadyAdded
                                        ? "checkmark.circle.fill"
                                        : "plus.circle"
                                )
                                .foregroundStyle(
                                    alreadyAdded ? .green : .secondary
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(alreadyAdded)
                    }
                }
            }
            .navigationTitle("Add Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}