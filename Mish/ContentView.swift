import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit

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


 // MARK: - Mish Aero Glass

extension Color {
    static let aeroSilver = Color(hex: 0xE9EDF2)
    static let aeroEdge = Color.white.opacity(0.62)
    static let aeroShadow = Color.black.opacity(0.24)
}

private struct MishGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var intensity: Double = 1

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )

        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .background {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14 * intensity),
                            Color.white.opacity(0.035 * intensity),
                            Color.black.opacity(0.10 * intensity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.65 * intensity),
                            .white.opacity(0.12 * intensity),
                            .white.opacity(0.28 * intensity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .overlay(alignment: .top) {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15 * intensity),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(0.20 * intensity),
                radius: 12,
                x: 0,
                y: 6
            )
    }
}

private extension View {
    func mishGlass(
        cornerRadius: CGFloat = 20,
        intensity: Double = 1
    ) -> some View {
        modifier(
            MishGlassModifier(
                cornerRadius: cornerRadius,
                intensity: intensity
            )
        )
    }
}

/// Glossy, tactile controls inspired by classic media hardware.
private struct MishGlossyButtonStyle: ButtonStyle {
    var circular = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(
                    cornerRadius: circular ? 100 : 15,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: configuration.isPressed
                            ? [
                                Color(hex: 0xAEB3BC),
                                Color(hex: 0xE0E3E9)
                            ]
                            : [
                                Color.white,
                                Color(hex: 0xDDE1E8),
                                Color(hex: 0xAEB5C0)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: circular ? 100 : 15,
                    style: .continuous
                )
                .strokeBorder(
                    Color.white.opacity(0.9),
                    lineWidth: 1
                )
            }
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.08 : 0.28),
                radius: configuration.isPressed ? 2 : 5,
                x: 0,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(
                .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}


func formatTime(_ t: TimeInterval) -> String {
    let s = Int(t.isFinite ? max(0, t) : 0)
    return String(format: "%d:%02d", s / 60, s % 60)
}


enum MishTab { case library, playing, queue, lyrics, keypad, about }



private struct AlbumArtBackground: View {
    let artwork: UIImage?
    let blurRadius: Double
    let blurEnabled: Bool
    let theme: MishBaseTheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch theme {
                case .smoked:
                    LinearGradient(
                        colors: [
                            Color(white: 0.17),
                            Color(white: 0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                case .amoled:
                    Color.black

                case .clear:
                    LinearGradient(
                        colors: [
                            Color.mishGreen.opacity(0.3),
                            Color.blue.opacity(0.2),
                            Color.purple.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(.ultraThinMaterial)
                }

                if theme != .amoled, let artwork {
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
                            Color.black.opacity(
                                theme == .clear ? 0.28 : 0.48
                            )
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
    @AppStorage("mishSpecialArtistModesEnabled")
    private var specialArtistModesEnabled = true
    @State private var showPlaylists = false
    @State private var gabrielUnlocked = false
    @AppStorage("mishAlbumBlurEnabled")
    private var albumBlurEnabled = true
    @AppStorage("mishAlbumBlurRadius")
    private var albumBlurRadius = 55.0
    @StateObject private var lyricsModel = LyricsModel()
    @EnvironmentObject private var settings: MishSettings
    @State private var showAppearanceSettings = false
    

@State private var showBackgroundSettings = false

    private var specialMode: Bool {
    specialArtistModesEnabled && player.isUnderscoresMode
}

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

    private var isBeautySleepTrack: Bool {
    guard specialArtistModesEnabled,
          let track = player.currentTrack else {
        return false
    }

    return track.title.trimmingCharacters(
        in: .whitespacesAndNewlines
    ).localizedCaseInsensitiveCompare("Beauty Sleep") == .orderedSame
    && track.artist.trimmingCharacters(
        in: .whitespacesAndNewlines
    ).localizedCaseInsensitiveCompare("Jane Remover") == .orderedSame
}

    private var importTypes: [UTType] {
        importFolder
            ? [.folder]
            : [.audio, UTType(filenameExtension: "flac")].compactMap { $0 }
    }

    var body: some View {
        ZStack {
            if isBeautySleepTrack {
                BeautySleepVideoBackground()
                    .ignoresSafeArea()
        
                Color.black.opacity(0.20)
                    .ignoresSafeArea()
        
            } else if specialMode {
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
        
            } else if specialArtistModesEnabled && player.isJaneRemoverMode {
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
                    blurEnabled: albumBlurEnabled,
                    theme: settings.baseTheme
                )
                .id(player.currentTrack?.url)
            }

                
                
            VStack(spacing: 0) {
                topBar

                if gabrielUnlocked {
                    ThankYouBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                
                ZStack {
                    if tab == .keypad {
                        KeypadView(
                            unlocked: $gabrielUnlocked,
                            tint: specialMode ? .black : .white
                        )
                        .transition(.opacity)
                
                    } else if player.tracks.isEmpty {
                        emptyState
                            .transition(.opacity)
                
                    } else {
                        Group {
                            switch tab {
                            case .playing:
                                NowPlayingView(onShowLyrics: {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        tab = .lyrics
                                    }
                                })
                                .environmentObject(lyricsModel)
                
                            case .library:
                                libraryList
                
                            case .queue:
                                queueList
                
                            case .lyrics:
                                LyricsView()
                                    .environmentObject(lyricsModel)
                
                            case .keypad:
                                EmptyView()

                            case .about:
                                AboutView()
                            }
                        }
                        .id(tab)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing)
                                    .combined(with: .opacity),
                                removal: .move(edge: .leading)
                                    .combined(with: .opacity)
                            )
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(
                    .spring(response: 0.34, dampingFraction: 0.88),
                    value: tab
                )
                bottomNav
            }
            .foregroundStyle(specialMode ? Color.black : Color.white)
        }
        .preferredColorScheme(specialMode ? .light : .dark)
        .animation(.easeInOut(duration: 0.22), value: specialMode)

        // Music file/folder importer
        .sheet(isPresented: $showImporter) {
            DocumentPicker(
                types: importTypes,
                allowsMultiple: !importFolder,
                asCopy: !importFolder,
                onPick: { urls in
                    showImporter = false
                    if importFolder {
                        player.addRoots(urls)
                    } else {
                        player.importCopies(urls)
                    }
                },
                onCancel: { showImporter = false }
            )
            .ignoresSafeArea()
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
        .sheet(isPresented: $showAppearanceSettings) {
            AppearanceSettingsView()
                .environmentObject(settings)
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
                    showAppearanceSettings = true
                } label: {
                    Label("Appearance", systemImage: "paintpalette")
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
                showBackgroundSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Background Settings")
                    }
                    .foregroundColor(specialMode ? .black : .white)
                    .padding(.horizontal, 12)
                }

    // MARK: Bottom nav
    
    private var bottomNav: some View {
        HStack(spacing: 2) {
            navItem("Library", icon: "music.note.list", for: .library)
            navItem("Playing", icon: "music.note", for: .playing)
            navItem("Queue", icon: "list.bullet", for: .queue)
            navItem("Keypad", icon: "circle.grid.3x3.fill", for: .keypad)
            navItem("Lyrics", icon: "text.quote", for: .lyrics)
            navItem("About", icon: "info.circle", for: .about)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .mishGlass(cornerRadius: 24)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 5)
    }
    

    private func navItem(
        _ title: String,
        icon: String,
        for target: MishTab
    ) -> some View {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    tab = target
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: tab == target ? .semibold : .regular))
            
                    Text(title)
                        .font(.system(size: 9, weight: tab == target ? .semibold : .medium))
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(
                    tab == target
                        ? (specialMode ? Color.black : Color.white)
                        : (specialMode
                            ? Color.black.opacity(0.55)
                            : Color.white.opacity(0.58))
                )
                .background {
                    if tab == target {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(.white.opacity(specialMode ? 0.14 : 0.16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                            }
                    }
                }
            }
            .buttonStyle(.plain)
        }

    // MARK: Library / Queue lists
    private var libraryList: some View {
    CoverFlowLibraryView(
        tracks: player.tracks,
        onSelect: { track in
            if let index = player.tracks.firstIndex(of: track) {
                player.play(index: index)
            }
        },
        onRemove: player.removeFromLibrary
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
    @EnvironmentObject private var settings: MishSettings
    @State private var scrubValue: Double = 0
    @State private var frozenSpectrum: [Float]? = nil
    @State private var vinylRotation: Double = 0
    
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
        GeometryReader { geometry in
            let panelWidth: CGFloat = geometry.size.width < 380 ? 34 : 46
    
            HStack(spacing: 10) {
                MishVisualizerView(spectrum: player.spectrum)
                    .frame(width: panelWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Music visualizer")
    
                ScrollView(showsIndicators: false) {
                    VStack(
                        spacing: settings.layout == .minimal ? 12 : 18
                    ) {
                        switch settings.layout {
                        case .classic:
                            if !specialMode {
                                artwork
                            }
    
                            trackInfo
    
                        case .vinyl:
                            if !specialMode {
                                vinylArtwork
                            }
    
                            trackInfo
    
                        case .minimal:
                            minimalHeader
    
                        seekBar
                        controls
                        lyricsPreview
                        upNext
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(mainText)
        .animation(.easeInOut(duration: 0.3), value: specialMode)
        .animation(.easeInOut(duration: 0.3), value: settings.layout)
        .animation(.easeInOut(duration: 0.3), value: settings.baseTheme)
    }

    
    private var vinylDisc: some View {
        ZStack {
            Circle()
    .fill(
        RadialGradient(
            colors: [
                Color(white: 0.25),
                Color.black,
                Color(white: 0.12),
                Color.black
            ],
            center: .center,
            startRadius: 8,
            endRadius: 170
                )
            )
            // Vinyl grooves
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .stroke(
                        Color.white.opacity(0.06),
                        lineWidth: 1
                    )
                    .padding(CGFloat(index + 1) * 9)
            }
    
            if let image = player.currentTrack?.artwork {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 155, height: 155)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    }
            } else {
                Circle()
                    .fill(Color.mishGreen.opacity(0.75))
                    .frame(width: 155, height: 155)
                    .overlay {
                        Text("mish")
                            .font(.custom("delagothicone-regular", size: 30))
                            .foregroundStyle(.black)
                    }
            }
    
            Circle()
                .fill(Color.black)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 3, height: 3)
                }
        }
        .frame(width: 290, height: 290)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

 private var vinylArtwork: some View {
      TimelineView(.animation(paused: !player.isPlaying)) { context in
          let seconds = context.date.timeIntervalSinceReferenceDate
          let angle = seconds.truncatingRemainder(dividingBy: 4) / 4 * 360
          vinylDisc.rotationEffect(.degrees(angle))
      }
      .frame(width: 290, height: 290)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
  }
    
    private var minimalHeader: some View {
        HStack(spacing: 14) {
            Group {
                if let image = player.currentTrack?.artwork {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(Color.mishGreen)
                        }
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    
            VStack(alignment: .leading, spacing: 5) {
                Text(player.currentTrack?.title ?? "Nothing playing")
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(2)
    
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryText)
                    .lineLimit(2)
    
                HStack(spacing: 5) {
                    Circle()
                        .fill(player.isPlaying ? Color.mishGreen : secondaryText)
                        .frame(width: 6, height: 6)
    
                    Text(player.isPlaying ? "PLAYING" : "PAUSED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(secondaryText)
                }
            }
    
            Spacer(minLength: 0)
    
            Button {
                liked.toggle()
            } label: {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        liked ? Color.mishGreen : mainText.opacity(0.8)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
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
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.65),
                                .white.opacity(0.08),
                                .white.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.14),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            }
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
        
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.42),
                            .white.opacity(0.08),
                            .white.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
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
            Button {
                player.togglePlay()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: 0x242831))
                    .frame(width: 58, height: 58)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(MishGlossyButtonStyle())
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

struct NavContainer<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
                .navigationViewStyle(.stack)
        }
    }
}


private struct BackgroundSettingsView: View {
    @AppStorage("mishAlbumBlurEnabled")
    private var blurEnabled = true

    @AppStorage("mishAlbumBlurRadius")
    private var blurRadius = 55.0
    
    @AppStorage("mishSpecialArtistModesEnabled")
    private var specialArtistModesEnabled = true

    var body: some View {
        NavContainer {
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
                
                Section("Visual Effects") {
                    Toggle(
                        "Artist-specific backgrounds",
                        isOn: $specialArtistModesEnabled
                    )
                
                    Text(
                        "Controls the special Underscores and Jane Remover backgrounds."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
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


private struct BeautySleepVideoBackground: UIViewRepresentable {
    final class VideoView: UIView {
        override class var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> VideoView {
        let view = VideoView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspectFill

        guard let url = Bundle.main.url(
            forResource: "beautysleep_cropped",
            withExtension: "mp4"
        ) else {
            print(
                "Mish: beautysleep_cropped.mp4 not found in app bundle"
            )
            return view
        }

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none

        context.coordinator.player = player
        context.coordinator.looper = AVPlayerLooper(
            player: player,
            templateItem: item
        )

        view.playerLayer.player = player
        player.play()

        return view
    }

    func updateUIView(
        _ uiView: VideoView,
        context: Context
    ) {
        // The video loops independently of music playback.
    }

    static func dismantleUIView(
        _ uiView: VideoView,
        coordinator: Coordinator
    ) {
        coordinator.player?.pause()
        uiView.playerLayer.player = nil
        coordinator.looper = nil
        coordinator.player = nil
    }
}


private struct MishAlbumGroup: Identifiable {
    let id: String
    let title: String
    let artist: String
    let artwork: UIImage?
    let tracks: [Track]
}

private struct CoverFlowLibraryView: View {
    let tracks: [Track]
    let onSelect: (Track) -> Void
    let onRemove: (Track) -> Void

    @State private var selectedAlbumID: String?

    private var albums: [MishAlbumGroup] {
        var result: [MishAlbumGroup] = []
        var indexes: [String: Int] = [:]

        // Preserve the order albums first appear in the library.
        for track in tracks {
            let albumName = track.album.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let artistName = track.artist.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let title = albumName.isEmpty ? "Unknown Album" : albumName
            let artist = artistName.isEmpty ? "Unknown Artist" : artistName

            // Separate albums by artist as well as album title.
            let key = "\(artist)\u{1F}\(title)"

            if let index = indexes[key] {
                let existing = result[index]

                result[index] = MishAlbumGroup(
                    id: existing.id,
                    title: existing.title,
                    artist: existing.artist,
                    artwork: existing.artwork ?? track.artwork,
                    tracks: existing.tracks + [track]
                )
            } else {
                indexes[key] = result.count

                result.append(
                    MishAlbumGroup(
                        id: key,
                        title: title,
                        artist: artist,
                        artwork: track.artwork,
                        tracks: [track]
                    )
                )
            }
        }

        return result
    }

    private var selectedIndex: Int {
        albums.firstIndex {
            $0.id == selectedAlbumID
        } ?? 0
    }

    private var selectedAlbum: MishAlbumGroup? {
        guard !albums.isEmpty else { return nil }
        return albums[selectedIndex]
    }

    private var visibleIndices: [Int] {
        albums.indices.filter {
            abs($0 - selectedIndex) <= 2
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if let selectedAlbum {
                Text("ALBUMS")
                    .font(.caption.weight(.semibold))
                    .tracking(3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                // Cover Flow carousel
                GeometryReader { geometry in
                    ZStack {
                        ForEach(visibleIndices, id: \.self) { index in
                            let album = albums[index]
                            let distance = index - selectedIndex
                            let isSelected = distance == 0

                            albumCover(album)
                                .frame(width: 180, height: 180)
                                .scaleEffect(isSelected ? 1.0 : 0.76)
                                .rotation3DEffect(
                                    .degrees(Double(distance) * -48),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.55
                                )
                                .offset(
                                    x: CGFloat(distance) * 112,
                                    y: CGFloat(abs(distance)) * 12
                                )
                                .opacity(
                                    abs(distance) > 1 ? 0.48 : 1.0
                                )
                                .zIndex(Double(3 - abs(distance)))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(
                                        .spring(
                                            response: 0.38,
                                            dampingFraction: 0.82
                                        )
                                    ) {
                                        selectedAlbumID = album.id
                                    }
                                }
                        }
                    }
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                guard albums.count > 1 else { return }

                                withAnimation(
                                    .spring(
                                        response: 0.38,
                                        dampingFraction: 0.82
                                    )
                                ) {
                                    if value.translation.width < -35 {
                                        let next = min(
                                            selectedIndex + 1,
                                            albums.count - 1
                                        )
                                        selectedAlbumID = albums[next].id
                                    } else if value.translation.width > 35 {
                                        let previous = max(
                                            selectedIndex - 1,
                                            0
                                        )
                                        selectedAlbumID = albums[previous].id
                                    }
                                }
                            }
                    )
                    .animation(
                        .spring(
                            response: 0.38,
                            dampingFraction: 0.82
                        ),
                        value: selectedAlbumID
                    )
                }
                .frame(height: 205)

                VStack(spacing: 4) {
                    Text(selectedAlbum.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(selectedAlbum.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(
                        "\(selectedAlbum.tracks.count) "
                        + (selectedAlbum.tracks.count == 1
                           ? "SONG" : "SONGS")
                    )
                    .font(.caption2)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Reuse Mish's existing song list and row behavior.
                TrackList(
                    tracks: selectedAlbum.tracks,
                    onSelect: onSelect,
                    onRemove: onRemove
                )
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)

                    Text("No albums yet")
                        .font(.headline)

                    Text("Add some music to start your collection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func albumCover(_ album: MishAlbumGroup) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.14))

            if let artwork = album.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 44, weight: .light))

                    Text(album.title)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .foregroundStyle(.white.opacity(0.75))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    Color.white.opacity(0.12),
                    lineWidth: 1
                )
        }
        .shadow(
            color: .black.opacity(0.35),
            radius: 12,
            x: 0,
            y: 7
        )
    }
}

