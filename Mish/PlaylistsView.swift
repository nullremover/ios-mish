
import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var player: PlayerModel

    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            Group {
                if player.playlists.isEmpty {
                    PlaylistEmptyState(
                        title: "No Playlists Yet",
                        systemImage: "music.note.list",
                        message: "Create a playlist and collect your favorite tracks.",
                        buttonTitle: "Create Playlist"
                    ) {
                        newPlaylistName = ""
                        showingCreatePlaylist = true
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
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    let name = newPlaylistName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                    guard !name.isEmpty else {
                        newPlaylistName = ""
                        return
                    }

                    player.createPlaylist(name: name)
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
                        PlaylistEmptyState(
                            title: "No Tracks Yet",
                            systemImage: "music.note",
                            message: "Tap + to add music from your library."
                        )
                    } else {
                        Section {
                            Button {
                                player.playPlaylist(id: playlistID)
                            } label: {
                                Label("Play All", systemImage: "play.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                    
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
                }
                .listStyle(.plain)
                .navigationTitle(playlist.name)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddTracks = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Tracks")
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
                .sheet(isPresented: $showingAddTracks) {
                    AddTracksView(playlistID: playlistID)
                        .environmentObject(player)
                }
            } else {
                PlaylistEmptyState(
                    title: "Playlist Not Found",
                    systemImage: "music.note.list",
                    message: "This playlist may have been deleted."
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
                Text(
                    track?.title
                        ?? URL(string: path)?.lastPathComponent
                        ?? path
                )
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
                    PlaylistEmptyState(
                        title: "Library Is Empty",
                        systemImage: "music.note",
                        message: "Import music into Mish before adding tracks."
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PlaylistEmptyState: View {
    let title: String
    let systemImage: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
