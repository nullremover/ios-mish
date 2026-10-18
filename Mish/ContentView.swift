import SwiftUI
import UniformTypeIdentifiers

// MARK: - Colors from the CSS
extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    static let mishGreen = Color(hex: 0xa6e3a1)
    static let mishDim = Color(hex: 0x9294a1)
}

func formatTime(_ t: TimeInterval) -> String {
    let s = Int(t.isFinite ? max(0, t) : 0)
    return String(format: "%d:%02d", s / 60, s % 60)
}

enum MishTab { case library, playing, queue }

// MARK: - Root
struct ContentView: View {
    @EnvironmentObject var player: PlayerModel
    @State private var tab: MishTab = .playing
    @State private var showImporter = false
    @State private var importFolder = true
    @State private var chaos = false

    // Folders for "Add folder", audio files for "Add files"
    private var importTypes: [UTType] {
        importFolder ? [.folder] : [.audio, UTType(filenameExtension: "flac")].compactMap { $0 }
    }

    var body: some View {
        ZStack {
            MishVisualizerView(
                spectrum: player.spectrum,
                chaos: chaos
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Group {
                    if player.tracks.isEmpty {
                        emptyState
                    } else {
                        switch tab {
                        case .playing: NowPlayingView()
                        case .library: libraryList
                        case .queue:   queueList
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomNav
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: importTypes,
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { player.addRoots(urls) }
        }
    }

    // MARK: Top bar  (menu / MISH. / search)
    private var topBar: some View {
        HStack {
            Menu {
                Button("Add music folder…") { importFolder = true; showImporter = true }
                Button("Add music files…") { importFolder = false; showImporter = true }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            Spacer()
            HStack(spacing: 0) {
                Text("mish")
                    .font(.custom("DelaGothicOne-Regular", size: 20))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                chaos.toggle()
            } label: {
                Text(chaos ? "CHAOS" : "CALM")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(chaos ? .pink : .cyan)
                    .frame(width: 64, height: 44)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
    }

    // MARK: Bottom nav  (Library / Playing / Queue)
    private var bottomNav: some View {
        HStack {
            navItem("Library", icon: "music.note.list", for: .library)
            navItem("Playing", icon: "music.note", for: .playing)
            navItem("Queue", icon: "list.bullet", for: .queue)
        }
        .padding(.top, 8)
        .overlay(Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1), alignment: .top)
    }

    private func navItem(_ title: String, icon: String, for target: MishTab) -> some View {
        Button { tab = target } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 19))
                Text(title).font(.system(size: 10))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundColor(tab == target ? .white : Color(hex: 0x828491))
        }
    }

    // MARK: Library / Queue lists
    private var libraryList: some View {
        TrackList(tracks: player.tracks) { track in
            if let i = player.tracks.firstIndex(of: track) { player.play(index: i) }
        }
    }

    private var queueList: some View {
        TrackList(tracks: player.queue) { track in
            if let i = player.tracks.firstIndex(of: track) { player.play(index: i) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.house").font(.system(size: 44)).foregroundColor(.mishDim)
            Text("No music yet").font(.system(size: 18, weight: .semibold))
            Text("Add a folder from the menu, or copy files into the mish folder in the Files app.")
                .font(.system(size: 12))
                .foregroundColor(.mishDim)
                .multilineTextAlignment(.center)
            Button {
                importFolder = true
                showImporter = true
            } label: {
                Text("Add music folder")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(Color.mishGreen))
                    .foregroundColor(Color(hex: 0x121812))
            }
        }
        .padding(30)
    }
}

// MARK: - Now playing screen
struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerModel
    @State private var liked = false
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    private var displayTime: Double { scrubbing ? scrubValue : player.currentTime }
    private var progress: Double {
        player.duration > 0 ? min(max(displayTime / player.duration, 0), 1) : 0
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                artwork
                trackInfo
                seekBar
                controls
                upNext
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
    }

    // Square artwork card (gradient + "MISH" when the track has no cover)
    private var artwork: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxHeight: 330)
            .overlay(
                Group {
                    if let image = player.currentTrack?.artwork {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            LinearGradient(colors: [Color(hex: 0xef8e62), Color(hex: 0x7a436d), Color(hex: 0x242b55)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                            Circle().stroke(Color.white.opacity(0.33), lineWidth: 1).padding(40)
                            Text("MISH").font(.system(size: 27, weight: .black)).tracking(4)
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .shadow(color: Color.black.opacity(0.4), radius: 20, y: 18)
    }

    private var trackInfo: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(player.currentTrack?.title ?? "Nothing playing")
                    .font(.system(size: 22, weight: .semibold))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0xa7a8b3))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button { liked.toggle() } label: {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(liked ? .mishGreen : Color.white.opacity(0.85))
                    .frame(width: 44, height: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        guard let t = player.currentTrack else { return "Pick a song from Library" }
        let album = t.album == "Unknown Album" ? "" : " · " + t.album
        return t.artist + album
    }

    // Seek bar: tap or drag anywhere on it
    private var seekBar: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0x454650)).frame(height: 4)
                    Capsule().fill(Color(hex: 0xf5f5f7)).frame(width: geo.size.width * progress, height: 4)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            scrubbing = true
                            scrubValue = clamp01(value.location.x / max(geo.size.width, 1)) * player.duration
                        }
                        .onEnded { value in
                            player.seek(to: clamp01(value.location.x / max(geo.size.width, 1)) * player.duration)
                            scrubbing = false
                        }
                )
            }
            .frame(height: 24)

            HStack {
                Text(formatTime(displayTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 10))
            .foregroundColor(Color(hex: 0x9698a5))
        }
    }

    private func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }

    // shuffle / previous / play-pause / next / repeat
    private var controls: some View {
        HStack {
            controlButton(icon: "shuffle", size: 20,
                          color: player.shuffleOn ? .mishGreen : .white) { player.shuffleOn.toggle() }
            Spacer()
            controlButton(icon: "backward.fill", size: 22) { player.previous() }
            Spacer()
            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(Color(hex: 0x121812))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.white))
            }
            Spacer()
            controlButton(icon: "forward.fill", size: 22) { player.next() }
            Spacer()
            controlButton(icon: player.repeatMode == .one ? "repeat.1" : "repeat", size: 20,
                          color: player.repeatMode == .off ? .white : .mishGreen) { player.cycleRepeat() }
        }
    }

    private func controlButton(icon: String, size: CGFloat, color: Color = .white,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
        }
    }

    // UP NEXT: the next three tracks
    private var upNext: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("UP NEXT").font(.system(size: 10, weight: .heavy)).tracking(2)
                Spacer()
                Text("•••").font(.system(size: 10, weight: .heavy))
            }
            ForEach(Array(player.upNext.enumerated()), id: \.element.id) { offset, track in
                Button {
                    if let i = player.tracks.firstIndex(of: track) { player.play(index: i) }
                } label: {
                    TrackRow(track: track, badge: String(format: "%02d", offset + 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 1)
    }
}

// MARK: - Shared pieces
struct TrackRow: View {
    let track: Track
    let badge: String
    var highlighted = false

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                if let image = track.artwork {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Color(hex: 0xc98b7c), Color(hex: 0x31345c)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(badge).font(.system(size: 10, weight: .heavy))
                }
            }
            .frame(width: 39, height: 39)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(highlighted ? .mishGreen : .white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.mishDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(track.duration > 0 ? formatTime(track.duration) : "")
                .font(.system(size: 10))
                .foregroundColor(.mishDim)
        }
        .contentShape(Rectangle())
    }
}

struct TrackList: View {
    @EnvironmentObject var player: PlayerModel
    let tracks: [Track]
    let onSelect: (Track) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { offset, track in
                    Button { onSelect(track) } label: {
                        TrackRow(track: track,
                                 badge: String(format: "%02d", offset + 1),
                                 highlighted: track == player.currentTrack)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
