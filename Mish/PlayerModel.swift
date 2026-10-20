import AVFoundation
import MediaPlayer
import UIKit

enum RepeatMode { case off, all, one }

struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var title: String
    var artist: String = "Unknown Artist"
    var album: String = "Unknown Album"
    var duration: TimeInterval = 0
    var artwork: UIImage? = nil

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
}

private struct Meta {
    var url: URL
    var title: String?
    var artist: String?
    var album: String?
    var duration: TimeInterval
    var artwork: UIImage?
}

/// Everything about playback lives here; the SwiftUI views only watch it and call its methods.
final class PlayerModel: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - State the UI watches
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var currentIndex: Int? = nil
    @Published private(set) var isPlaying = false
    @Published private(set) var hasActivePlayback = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var playlists: [MishPlaylist] = []
    private let playlistsKey = "mish.playlists"
    @Published private(set) var spectrum: [Float] =
        Array(repeating: 0, count: MishSpectrumAnalyzer.bandCount)
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffleOn = false {
        didSet { rebuildOrder() }
    }

    /// Active for playing and paused tracks, but false after playback reaches its end.
    var isUnderscoresMode: Bool {
        guard hasActivePlayback, let artist = currentTrack?.artist else { return false }
        return artist.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("underscores") == .orderedSame
    }
    var isJaneRemoverMode: Bool {
    guard hasActivePlayback,
          let artist = currentTrack?.artist else {
        return false
    }
    return artist.trimmingCharacters(
        in: .whitespacesAndNewlines
    ).caseInsensitiveCompare("Jane Remover") == .orderedSame
}

    // MARK: - Private state
    private var player: AVAudioPlayer?
    private let audioSampler = MishAudioSampler()
    private var order: [Int] = []
    /// When non-nil, playback is restricted to this playlist's tracks.
    private var activePlaylistURLs: [String]? = nil
    private var orderPos = 0
    private var timer: Timer?
    private var roots: [URL] = []
    private var bookmarkDatas: [Data] = []
    private var accessed = Set<URL>()
    private var metadataTask: Task<Void, Never>?

    private let bookmarksKey = "mish.bookmarks"
    private let removedLibraryKey = "mish.removedLibraryURLs"

    private var removedLibraryURLs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: removedLibraryKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: removedLibraryKey) }
    }

    private var queueExcludedURLs = Set<String>()

    private func trackKey(_ url: URL) -> String {
        url.standardizedFileURL.absoluteString
    }

    // AVAudioPlayer plays these natively on iOS (no .ogg, iOS can't decode it)
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"]

    // MARK: - Convenience for the views
    var currentTrack: Track? {
        guard let i = currentIndex, tracks.indices.contains(i) else { return nil }
        return tracks[i]
    }

    var duration: TimeInterval { player?.duration ?? currentTrack?.duration ?? 0 }

    /// Tracks still included in the playback queue.
    var queue: [Track] {
        order.compactMap { index in
            guard tracks.indices.contains(index) else { return nil }
            let track = tracks[index]
            return queueExcludedURLs.contains(trackKey(track.url)) ? nil : track
        }
    }

    /// The next three eligible tracks.
    var upNext: [Track] {
        guard !order.isEmpty else { return [] }
        var result: [Track] = []
        var pos = currentIndex == nil ? -1 : orderPos
        var checked = 0
        while checked < order.count && result.count < 3 {
            pos += 1
            if pos >= order.count {
                guard repeatMode == .all else { break }
                pos = 0
            }
            checked += 1
            let index = order[pos]
            guard tracks.indices.contains(index) else { continue }
            if currentIndex == index { continue }
            let track = tracks[index]
            if !queueExcludedURLs.contains(trackKey(track.url)) { result.append(track) }
        }
        return result
    }

    // MARK: - Setup
    override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        restoreLibrary()
        restorePlaylists()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    /// Lock screen, Control Center, headphone buttons, CarPlay...
    private func configureRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.resume() }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.pause() }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.togglePlay() }
            return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.next() }
            return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.previous() }
            return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                let t = e.positionTime
                DispatchQueue.main.async { self?.seek(to: t) }
            }
            return .success
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        DispatchQueue.main.async {
            if type == .began {
                self.pause()
            } else if AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) {
                self.resume()
            }
        }
    }

    // MARK: - Library
    /// Folders or single files chosen in the file picker.
    func addRoots(_ urls: [URL]) {
        for url in urls {
            let started = url.startAccessingSecurityScopedResource()
            if let data = try? url.bookmarkData() { bookmarkDatas.append(data) }
            if started { url.stopAccessingSecurityScopedResource() }
            roots.append(url)
        }
        UserDefaults.standard.set(bookmarkDatas, forKey: bookmarksKey)
        scan()
    }

    /// Excludes a track from the queue without removing it from the library.
    func removeFromQueue(_ track: Track) {
        queueExcludedURLs.insert(trackKey(track.url))
        objectWillChange.send()
    }

    /// Removes a track from Mish's library, but never deletes its audio file.
    func removeFromLibrary(_ track: Track) {
        var removed = removedLibraryURLs
        removed.insert(trackKey(track.url))
        removedLibraryURLs = removed

        if currentTrack?.url == track.url {
            player?.stop()
            player = nil
            timer?.invalidate()
            timer = nil
            isPlaying = false
            hasActivePlayback = false
            currentTime = 0
            currentIndex = nil
            spectrum = Array(repeating: 0, count: MishSpectrumAnalyzer.bandCount)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
        scan()
    }

    private func restoreLibrary() {
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            roots.append(docs)
        }
        bookmarkDatas = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
        for data in bookmarkDatas {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                roots.append(url)
            }
        }
        scan()
    }

    private func scan() {
        var found: [URL] = []
        for root in roots {
            if !accessed.contains(root), root.startAccessingSecurityScopedResource() {
                accessed.insert(root)
            }
            if Self.audioExtensions.contains(root.pathExtension.lowercased()) {
                found.append(root)
            } else if let e = FileManager.default.enumerator(at: root,
                                                             includingPropertiesForKeys: [.isRegularFileKey],
                                                             options: [.skipsHiddenFiles]) {
                for case let url as URL in e where Self.audioExtensions.contains(url.pathExtension.lowercased()) {
                    found.append(url)
                }
            }
        }

        let currentURL = currentTrack?.url
        tracks = Array(Set(found))
            .filter { !removedLibraryURLs.contains(trackKey($0)) }
            .sorted { $0.path.lowercased() < $1.path.lowercased() }
            .map { Track(url: $0, title: $0.deletingPathExtension().lastPathComponent) }

        currentIndex = currentURL.flatMap { url in tracks.firstIndex { $0.url == url } }
        rebuildOrder()
        loadMetadata()
    }

    /// Reads title / artist / album / duration / cover art in the background and fills them in.
    private func loadMetadata() {
        metadataTask?.cancel()
        let snapshot = tracks
        metadataTask = Task.detached(priority: .utility) { [weak self] in
            var batch: [Meta] = []
            for track in snapshot {
                if Task.isCancelled { return }
                let asset = AVURLAsset(url: track.url)
                var meta = Meta(url: track.url, title: nil, artist: nil, album: nil, duration: 0, artwork: nil)
                if let d = try? await asset.load(.duration) { meta.duration = CMTimeGetSeconds(d) }
                if let items = try? await asset.load(.commonMetadata) {
                    meta.title = await Self.string(items, .commonIdentifierTitle)
                    meta.artist = await Self.string(items, .commonIdentifierArtist)
                    meta.album = await Self.string(items, .commonIdentifierAlbumName)
                    meta.artwork = await Self.artwork(items)
                }
                if track.url.pathExtension.lowercased() == "flac" {
                    let tags = ArtworkMetadataReader.flacComments(for: track.url)
                    if meta.title == nil { meta.title = tags["TITLE"] }
                    if meta.artist == nil { meta.artist = tags["ARTIST"] ?? tags["ALBUMARTIST"] }
                    if meta.album == nil { meta.album = tags["ALBUM"] }
                }
                if meta.artwork == nil { meta.artwork = ArtworkMetadataReader.embeddedArtwork(for: track.url) }
                if meta.artwork == nil { meta.artwork = ArtworkMetadataReader.folderArtwork(for: track.url) }
                batch.append(meta)
                if batch.count >= 25 {
                    let toApply = batch
                    batch.removeAll()
                    await MainActor.run { self?.apply(toApply) }
                }
            }
            if !batch.isEmpty {
                let toApply = batch
                await MainActor.run { self?.apply(toApply) }
            }
        }
    }
    
    
private func savePlaylists() {
    guard let data = try? JSONEncoder().encode(playlists) else {
        return
    }

    UserDefaults.standard.set(data, forKey: playlistsKey)
}

private func restorePlaylists() {
    guard let data = UserDefaults.standard.data(
        forKey: playlistsKey
    ),
    let saved = try? JSONDecoder().decode(
        [MishPlaylist].self,
        from: data
    ) else {
        return
    }

    playlists = saved
}

func createPlaylist(name: String) {
    let cleaned = name.trimmingCharacters(
        in: .whitespacesAndNewlines
    )

    guard !cleaned.isEmpty else { return }

    playlists.append(
        MishPlaylist(name: cleaned, trackPaths: [])
    )

    savePlaylists()
}

func renamePlaylist(id: UUID, name: String) {
    let cleaned = name.trimmingCharacters(
        in: .whitespacesAndNewlines
    )

    guard !cleaned.isEmpty,
          let index = playlists.firstIndex(where: {
              $0.id == id
          }) else {
        return
    }

    playlists[index].name = cleaned
    savePlaylists()
}

func deletePlaylist(id: UUID) {
    playlists.removeAll { $0.id == id }
    savePlaylists()
}

func addToPlaylist(id: UUID, track: Track) {
    guard let index = playlists.firstIndex(where: {
        $0.id == id
    }) else {
        return
    }

    playlists[index].add(track.url)
    savePlaylists()
}

    func removeFromPlaylist(id: UUID, at index: Int) {
        guard let playlistIndex = playlists.firstIndex(where: {
            $0.id == id
        }) else {
            return
        }
    
        playlists[playlistIndex].remove(at: index)
        savePlaylists()
    }
    
    func reorderPlaylist(
        id: UUID,
        from source: IndexSet,
        to destination: Int
    ) {
        guard let index = playlists.firstIndex(where: {
            $0.id == id
        }) else {
            return
        }
    
        playlists[index].move(
            from: source,
            to: destination
        )
    
        savePlaylists()
    }
    
    func tracks(in playlist: MishPlaylist) -> [Track?] {
        playlist.trackPaths.map { path in
            guard let url = URL(string: path) else {
                return nil
            }
    
            return tracks.first { $0.url == url }
        }
    }
    
    private static func string(_ items: [AVMetadataItem], _ id: AVMetadataIdentifier) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first,
              let value = try? await item.load(.stringValue), !value.isEmpty else { return nil }
        return value
    }

    private static func artwork(_ items: [AVMetadataItem]) async -> UIImage? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork).first,
              let data = try? await item.load(.dataValue) else { return nil }
        return UIImage(data: data)
    }

    private func apply(_ metas: [Meta]) {
        let currentURL = currentTrack?.url
        var touchedCurrent = false
        for m in metas {
            guard let i = tracks.firstIndex(where: { $0.url == m.url }) else { continue }
            if let t = m.title { tracks[i].title = t }
            if let a = m.artist { tracks[i].artist = a }
            if let al = m.album { tracks[i].album = al }
            if m.duration.isFinite, m.duration > 0 { tracks[i].duration = m.duration }
            if let art = m.artwork { tracks[i].artwork = art }
            if m.url == currentURL { touchedCurrent = true }
        }
        if touchedCurrent { updateNowPlaying() }
    }

    // MARK: - Order (shuffle)
    private func rebuildOrder(startingWith preferredFirst: Int? = nil) {
    let all: [Int]

    if let playlistURLs = activePlaylistURLs {
        all = playlistURLs.compactMap { path in
            tracks.firstIndex { trackKey($0.url) == path }
        }
    } else {
        all = Array(tracks.indices)
    }

    let anchor = preferredFirst.flatMap {
        all.contains($0) ? $0 : nil
    } ?? currentIndex.flatMap {
        all.contains($0) ? $0 : nil
    }

    if shuffleOn {
        var rest = all.filter { $0 != anchor }
        rest.shuffle()

        order = (anchor.map { [$0] } ?? []) + rest
        orderPos = 0
    } else {
        order = all
        orderPos = anchor.flatMap {
            all.firstIndex(of: $0)
        } ?? 0
    }

    objectWillChange.send()
}

    // MARK: - Playback
    func playPlaylist(id: UUID, startingAt path: String? = nil) {
    guard let playlist = playlists.first(where: {
        $0.id == id
    }) else {
        return
    }

    // Skip playlist entries that aren't available in the library.
    let availablePaths = playlist.trackPaths.filter { path in
        tracks.contains { trackKey($0.url) == path }
    }

    guard !availablePaths.isEmpty else {
        return
    }

    activePlaylistURLs = availablePaths

    let selectedPath = path.flatMap { requested in
        availablePaths.contains(requested) ? requested : nil
    } ?? availablePaths[0]

    guard let index = tracks.firstIndex(where: {
        trackKey($0.url) == selectedPath
    }) else {
        return
    }

    rebuildOrder(startingWith: index)
    startTrack(at: index)
}
    func play(index: Int) {
    guard tracks.indices.contains(index) else { return }

    // Selecting a track from the library exits playlist mode.
    activePlaylistURLs = nil
    rebuildOrder(startingWith: index)

    startTrack(at: index)
}

    private func startTrack(at index: Int) {
        guard tracks.indices.contains(index) else { return }
    
        queueExcludedURLs.remove(trackKey(tracks[index].url))
    
        do {
            let p = try AVAudioPlayer(contentsOf: tracks[index].url)
            p.delegate = self
            p.prepareToPlay()
    
            guard p.play() else {
                print("Could not start playback: \(tracks[index].url)")
                return
            }
    
            player = p
            currentIndex = index
    
            if let pos = order.firstIndex(of: index) {
                orderPos = pos
            }
    
            isPlaying = true
            hasActivePlayback = true
            currentTime = 0
    
            startTimer()
            updateNowPlaying()
        } catch {
            print(
                "Could not play \(tracks[index].url.lastPathComponent): \(error)"
            )
        }
    }
    
    func togglePlay() { isPlaying ? pause() : resume() }

    func resume() {
        guard player != nil else {
            if let i = currentIndex ?? order.first { play(index: i) }
            return
        }
        player?.play()
        isPlaying = true
        hasActivePlayback = true
        startTimer()
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        updateNowPlaying()
    }

    func next() {
        guard !order.isEmpty else {
            stopAtEnd()
            return
        }
        var pos = orderPos
        for _ in 0..<order.count {
            pos += 1
            if pos >= order.count {
                guard repeatMode == .all else {
                    stopAtEnd()
                    return
                }
                pos = 0
            }
            let index = order[pos]
            guard tracks.indices.contains(index) else { continue }
            let track = tracks[index]
            if !queueExcludedURLs.contains(trackKey(track.url)) {
                orderPos = pos
                startTrack(at: index)
                return
            }
        }
        stopAtEnd()
    }

    func previous() {
        if (player?.currentTime ?? 0) > 3 {
            seek(to: 0)
            return
        }
        guard !order.isEmpty else { return }
        var pos = orderPos
        for _ in 0..<order.count {
            pos -= 1
            if pos < 0 {
                if repeatMode == .all { pos = order.count - 1 } else { pos = 0 }
            }
            let index = order[pos]
            guard tracks.indices.contains(index) else { continue }
            let track = tracks[index]
            if !queueExcludedURLs.contains(trackKey(track.url)) {
                orderPos = pos
                startTrack(at: index)
                return
            }
            if pos == 0 && repeatMode != .all { break }
        }
    }

    func seek(to time: TimeInterval) {
        guard let p = player else { return }
        p.currentTime = max(0, min(time, p.duration))
        currentTime = p.currentTime
        updateNowPlaying()
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    private func stopAtEnd() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        hasActivePlayback = false
        currentTime = 0
        timer?.invalidate()
        updateNowPlaying()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
            guard self.isPlaying, let track = self.currentTrack else { return }
            let url = track.url
            let time = player.currentTime
            self.audioSampler.analyze(url: url, at: time) { [weak self] newSpectrum in
                guard let self = self, self.isPlaying, self.currentTrack?.url == url else { return }
                self.spectrum = newSpectrum
            }
        }
    }

    // A track finished by itself
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            guard flag else { return }
            if self.repeatMode == .one, let i = self.currentIndex {
                self.startTrack(at: i)
            } else {
                self.next()
            }
        }
    }

    // MARK: - Lock screen / Control Center info
    private func updateNowPlaying() {
        guard let t = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: t.title,
            MPMediaItemPropertyArtist: t.artist,
            MPMediaItemPropertyAlbumTitle: t.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let image = t.artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
