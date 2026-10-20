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


enum MishTab { case library, playing, queue, lyrics }


private struct AlbumArtBackground: View {
    let artwork: UIImage?
    let blurRadius: Double
    let blurEnabled: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: 0x101014)

                if let artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .blur(radius: blurEnabled ? blurRadius : 0)
                        .overlay {
                            Color.black.opacity(0.48)
                        }
                        .transition(.opacity)
                }
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .clipped()
        }
        .ignoresSafeArea()
    }
}


// MARK: - Root
struct ContentView: View {
    @EnvironmentObject var player: PlayerModel
    @State private var tab: MishTab = .playing
    @State private var showImporter = false
    @State private var importFolder = true
    @State private var chaos = false
    @State private var showPlaylists = false
    @AppStorage("mishAlbumBlurEnabled")
    private var albumBlurEnabled = true
    @AppStorage("mishAlbumBlurRadius")
    private var albumBlurRadius = 55.0
    @StateObject private var lyricsModel = LyricsModel()
    

@State private var showBackgroundSettings = false

    private var specialMode: Bool { player.isUnderscoresMode }

    private static var underscoresBackground: UIImage? {
        guard let url = Bundle.main.url(
            forResource: "IMG_0451",
            withExtension: "jpg"
        ) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
    
    private static var janeRemoverBackground: UIImage? {
    guard let url = Bundle.main.url(
        forResource: "IMG_0465",
        withExtension: "jpg",
    ) else {
        return nil
    }

    return UIImage(contentsOfFile: url.path)
}

    private var importTypes: [UTType] {
        importFolder
            ? [.folder]
            : [.audio, UTType(filenameExtension: "flac")].compactMap { $0 }
    }

    var body: some View {
        ZStack {
            if specialMode {
                GeometryReader { geometry in
                    if let image = Self.underscoresBackground {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipped()
                    } else {
                        Color.white
                    }
                }
                .ignoresSafeArea()
            
                Color.white.opacity(0.16)
                    .ignoresSafeArea()
            
            } else if player.isJaneRemoverMode {
                GeometryReader { geometry in
                    if let image = Self.janeRemoverBackground {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipped()
                    } else {
                        Color(hex: 0x101014)
                    }
                }
                .ignoresSafeArea()
            
                Color.black.opacity(0.20)
                    .ignoresSafeArea()
            
            } else {
                AlbumArtBackground(
                    artwork: player.currentTrack?.artwork,
                    blurRadius: albumBlurRadius,
                    blurEnabled: albumBlurEnabled
                )
                .id(player.currentTrack?.url)
            }

                
                
            VStack(spacing: 0) {
                topBar

                Group {
                    if player.tracks.isEmpty {
                        emptyState
                    } else {
                        switch tab {
                        case .playing:
                            NowPlayingView(
                                onShowLyrics: { tab = .lyrics }
                            )
                            .environmentObject(lyricsModel)
                        case .library:
                            libraryList
                        case .queue:
                            queueList
                        case .lyrics:
                            LyricsView()
                            .environmentObject(lyricsModel)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomNav
            }
            .foregroundStyle(specialMode ? Color.black : Color.white)
        }
        .preferredColorScheme(specialMode ? .light : .dark)
        .animation(.easeInOut(duration: 0.22), value: specialMode)

        // Music file/folder importer
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                player.addRoots(urls)
            }
        }

        // Playlist screen
        .sheet(isPresented: $showPlaylists) {
            PlaylistsView()
                .environmentObject(player)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBackgroundSettings) {
            BackgroundSettingsView()
        }
        .task(id: player.currentTrack?.url) {
            guard let track = player.currentTrack else {
                lyricsModel.clear()
                return
            }
        
            await lyricsModel.load(
                artist: track.artist,
                title: track.title
            )
        }
    }

    // MARK: Top bar
    private var topBar: some View {
        HStack {
            Menu {
                Button("Add music folder…") {
                    importFolder = true
                    showImporter = true
                }

                Button("Add music files…") {
                    importFolder = false
                    showImporter = true
                }
                Button {
                    showBackgroundSettings = true
                } label: {
                    Label(
                        "Background Settings",
                        systemImage: "slider.horizontal.3"
                    )
                }
                Divider()

                Button {
                    showPlaylists = true
                } label: {
                    Label(
                        "Playlists",
                        systemImage: "music.note.list"
                    )
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .tint(specialMode ? .black : .white)

            Spacer()

            Text("mish")
                .font(.custom("delagothicone-regular", size: 20))
                .foregroundStyle(specialMode ? .black : .white)

            Spacer()

            Button {
                chaos.toggle()
            } label: {
                Text(chaos ? "Portal" : "CALM")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        specialMode
                            ? Color.black
                            : (chaos ? .purple : .cyan)
                    )
                    .frame(width: 64, height: 44)
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(specialMode ? .black : .white)
        .padding(.horizontal, 12)
    }

    // MARK: Bottom nav
    private var bottomNav: some View {
        HStack {
            navItem("Library", icon: "music.note.list", for: .library)
            navItem("Playing", icon: "music.note", for: .playing)
            navItem("Queue", icon: "list.bullet", for: .queue)
            navItem("Lyrics", icon: "text.quote", for: .lyrics)
        }
        .padding(.top, 8)
        .overlay(
            Rectangle()
                .fill(
                    (specialMode ? Color.black : Color.white)
                        .opacity(0.12)
                )
                .frame(height: 1),
            alignment: .top
        )
    }

    private func navItem(
        _ title: String,
        icon: String,
        for target: MishTab
    ) -> some View {
        Button {
            tab = target
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19))

                Text(title)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundColor(
                tab == target
                    ? (specialMode ? .black : .white)
                    : (specialMode
                        ? Color.black.opacity(0.55)
                        : Color(hex: 0x828491))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Library / Queue lists
    private var libraryList: some View {
        TrackList(
            tracks: player.tracks,
            onSelect: { track in
                if let i = player.tracks.firstIndex(of: track) {
                    player.play(index: i)
                }
            },
            onRemove: { track in
                player.removeFromLibrary(track)
            },
            removeLabel: "Remove from Library"
        )
    }

    private var queueList: some View {
        TrackList(
            tracks: player.queue,
            onSelect: { track in
                if let i = player.tracks.firstIndex(of: track) {
                    player.play(index: i)
                }
            },
            onRemove: { track in
                player.removeFromQueue(track)
            },
            removeLabel: "Remove from Queue"
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.house")
                .font(.system(size: 44))
                .foregroundColor(.mishDim)

            Text("No music yet")
                .font(.system(size: 18, weight: .semibold))

            Text(
                "Add a folder from the menu, or copy files into the mish folder in the Files app."
            )
            .font(.system(size: 12))
            .foregroundColor(
                specialMode
                    ? Color.black.opacity(0.62)
                    : .mishDim
            )
            .multilineTextAlignment(.center)

            Button {
                importFolder = true
                showImporter = true
            } label: {
                Text("Add music folder")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.mishGreen)
                    )
                    .foregroundColor(Color(hex: 0x121812))
            }
        }
        .padding(30)
    }
}

// MARK: - Now playing screen
struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var lyricsModel: LyricsModel
    var onShowLyrics: () -> Void = {}
    @State private var liked = false
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0
    @State private var frozenSpectrum: [Float]? = nil
    
    private let waveformBarCount = 72

    private var specialMode: Bool { player.isUnderscoresMode }
    private var mainText: Color { specialMode ? .black : .white }
    private var secondaryText: Color { specialMode ? Color.black.opacity(0.62) : Color(hex: 0xa7a8b3) }
    private var progressTrack: Color { specialMode ? Color.black.opacity(0.22) : Color(hex: 0x454650) }
    private var progressFill: Color { specialMode ? .black : Color(hex: 0xf5f5f7) }
    private var displayTime: Double { scrubbing ? scrubValue : player.currentTime }
    private var progress: Double {
        player.duration > 0 ? min(max(displayTime / player.duration, 0), 1) : 0
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                if !specialMode { artwork }
                trackInfo
                seekBar
                controls
                lyricsPreview
                upNext
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .foregroundStyle(mainText)
        .animation(.easeInOut(duration: 0.22), value: specialMode)
    }

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
                            LinearGradient(
                                colors: [Color(hex: 0x38393D), Color(hex: 0x242528), Color(hex: 0x303135)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            Circle().stroke(Color.white.opacity(0.07), lineWidth: 1).padding(40)
                            Text("mish")
                                .font(.custom("delagothicone-regular", size: 42))
                                .foregroundStyle(Color(hex: 0xD4D4D8))
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
                    .font(.system(size: 22, weight: .semibold)).lineLimit(2)
                Text(subtitle).font(.system(size: 12)).foregroundColor(secondaryText).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button { liked.toggle() } label: {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(liked ? .mishGreen : mainText.opacity(0.85))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        guard let t = player.currentTrack else { return "Pick a song from Library" }
        let album = t.album == "Unknown Album" ? "" : " · " + t.album
        return t.artist + album
    }
    
    
    private var lyricsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LYRICS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
    
                Spacer()
    
                Button(action: onShowLyrics) {
                    Label(
                        "View all",
                        systemImage: "arrow.up.right"
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
            }
    
            if let lyrics = lyricsModel.lyrics {
                Text(lyrics)
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(5)
                    .lineLimit(4)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            } else if lyricsModel.isLoading {
                ProgressView("Finding lyrics…")
                    .font(.system(size: 12))
            } else {
                Text(
                    lyricsModel.errorMessage
                        ?? "Lyrics will appear here."
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white.opacity(specialMode ? 0.12 : 0.07),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
    
    private var seekBar: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(0..<waveformBarCount, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(
                                height: waveformBarHeight(
                                    at: index,
                                    maxHeight: geo.size.height
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .leading) {
                    // The playhead is independent of the bar heights.
                    Capsule()
                        .fill(progressFill)
                        .frame(width: 2, height: geo.size.height)
                        .offset(
                            x: min(
                                max(geo.size.width * progress, 0),
                                max(geo.size.width - 2, 0)
                            )
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Freeze the displayed spectrum on the first drag event.
                            if !scrubbing {
                                frozenSpectrum = player.spectrum
                            }
    
                            scrubbing = true
    
                            let fraction = clamp01(
                                value.location.x / max(geo.size.width, 1)
                            )
    
                            scrubValue = fraction * player.duration
                        }
                        .onEnded { value in
                            let fraction = clamp01(
                                value.location.x / max(geo.size.width, 1)
                            )
    
                            player.seek(to: fraction * player.duration)
    
                            scrubbing = false
                            frozenSpectrum = nil
                        }
                )
            }
            .frame(height: 40)
    
            HStack {
                Text(formatTime(displayTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 10))
            .foregroundColor(secondaryText)
        }
    }
    
    private var displayedSpectrum: [Float] {
        if scrubbing, let frozenSpectrum {
            return frozenSpectrum
        }
    
        return player.spectrum
    }
    
    private func waveformBarHeight(
        at index: Int,
        maxHeight: CGFloat
    ) -> CGFloat {
        let spectrum = displayedSpectrum
    
        guard !spectrum.isEmpty else {
            return 3
        }
    
        let sourceIndex = min(
            spectrum.count - 1,
            index * spectrum.count / waveformBarCount
        )
    
        let magnitude = CGFloat(
            min(1, max(0, spectrum[sourceIndex]))
        )
    
        return 3 + magnitude * max(0, maxHeight - 3)
    }


    private func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }

    private var controls: some View {
        HStack {
            controlButton(icon: "shuffle", size: 20,
                          color: player.shuffleOn ? .mishGreen : mainText) { player.shuffleOn.toggle() }
            Spacer()
            controlButton(icon: "backward.fill", size: 22) { player.previous() }
            Spacer()
            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(specialMode ? .white : Color(hex: 0x121812))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(specialMode ? Color.black : Color.white))
            }
            .buttonStyle(.plain)
            Spacer()
            controlButton(icon: "forward.fill", size: 22) { player.next() }
            Spacer()
            controlButton(icon: player.repeatMode == .one ? "repeat.1" : "repeat", size: 20,
                          color: player.repeatMode == .off ? mainText : .mishGreen) { player.cycleRepeat() }
        }
    }

    private func controlButton(icon: String, size: CGFloat, color: Color? = nil,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size))
                .foregroundColor(color ?? mainText).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

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
    @EnvironmentObject var player: PlayerModel
    let track: Track
    let badge: String
    var highlighted = false

    private var specialMode: Bool { player.isUnderscoresMode }

    var body: some View {
        HStack(spacing: 11) {
            if !specialMode {
                ZStack {
                    if let image = track.artwork {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors: [Color(hex: 0x353639), Color(hex: 0x252629)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Text("m").font(.custom("delagothicone-regular", size: 19))
                            .foregroundStyle(Color(hex: 0xC9C9CD))
                    }
                }
                .frame(width: 39, height: 39)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title).font(.system(size: 12, weight: .semibold))
                    .foregroundColor(highlighted ? .mishGreen : (specialMode ? .black : .white))
                    .lineLimit(1)
                Text(track.artist).font(.system(size: 10))
                    .foregroundColor(specialMode ? Color.black.opacity(0.58) : .mishDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(track.duration > 0 ? formatTime(track.duration) : "")
                .font(.system(size: 10))
                .foregroundColor(specialMode ? Color.black.opacity(0.58) : .mishDim)
        }
        .contentShape(Rectangle())
    }
}



struct TrackList: View {
    @EnvironmentObject var player: PlayerModel
    let tracks: [Track]
    let onSelect: (Track) -> Void
    var onRemove: ((Track) -> Void)? = nil
    var removeLabel: String = "Remove"
    @State private var revealedTrackID: UUID? = nil

    private var specialMode: Bool { player.isUnderscoresMode }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { offset, track in
                    HStack(spacing: 8) {
                        Button { onSelect(track) } label: {
                            TrackRow(track: track,
                                     badge: String(format: "%02d", offset + 1),
                                     highlighted: track == player.currentTrack)
                        }
                        .buttonStyle(.plain)

                        if let onRemove {
                            if revealedTrackID == track.id {
                                Button(role: .destructive) {
                                    onRemove(track)
                                    revealedTrackID = nil
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .frame(width: 42, height: 42)
                                        .background(Color.red.opacity(0.12),
                                                    in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(removeLabel)
                            } else {
                                Menu {
                                    Button(role: .destructive) { onRemove(track) } label: {
                                        Label(removeLabel, systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(specialMode ? Color.black.opacity(0.7) : Color.mishDim)
                                        .frame(width: 32, height: 42)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                if value.translation.width < -35 {
                                    withAnimation(.easeOut(duration: 0.18)) { revealedTrackID = track.id }
                                } else if value.translation.width > 35, revealedTrackID == track.id {
                                    withAnimation(.easeOut(duration: 0.18)) { revealedTrackID = nil }
                                }
                            }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .foregroundStyle(specialMode ? Color.black : Color.white)
    }
}


private struct BackgroundSettingsView: View {
    @AppStorage("mishAlbumBlurEnabled")
    private var blurEnabled = true

    @AppStorage("mishAlbumBlurRadius")
    private var blurRadius = 55.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Album Artwork") {
                    Toggle("Blurred Background", isOn: $blurEnabled)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Blur Radius")
                            Spacer()
                            Text("\(Int(blurRadius))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: $blurRadius,
                            in: 0...100,
                            step: 1
                        )
                        .disabled(!blurEnabled)

                        HStack {
                            Text("Sharp")
                            Spacer()
                            Text("Dreamy")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Reset to Default") {
                        blurEnabled = true
                        blurRadius = 55
                    }
                }
            }
            .navigationTitle("Background")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
