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
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var spectrum: [Float] =
        Array(repeating: 0, count: MishSpectrumAnalyzer.bandCount)
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffleOn = false {
        didSet { rebuildOrder() }
    }

    // MARK: - Private state
    private var player: AVAudioPlayer?
    private let audioSampler = MishAudioSampler()
    private var order: [Int] = []          // playback order: indices into `tracks` (shuffled or not)
    private var orderPos = 0               // where we are inside `order`
    private var timer: Timer?
    private var roots: [URL] = []          // folders / files the library is built from
    private var bookmarkDatas: [Data] = [] // saved so the library survives app restarts
    private var accessed = Set<URL>()      // security-scoped URLs we've opened
    private var metadataTask: Task<Void, Never>?

    private let bookmarksKey = "mish.bookmarks"
    // AVAudioPlayer plays these natively on iOS (no .ogg, iOS can't decode it)
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"]

    // MARK: - Convenience for the views
    var currentTrack: Track? {
        guard let i = currentIndex, tracks.indices.contains(i) else { return nil }
        return tracks[i]
    }

    var duration: TimeInterval { player?.duration ?? currentTrack?.duration ?? 0 }

    /// The tracks in the order they will play.
    var queue: [Track] { order.compactMap { tracks.indices.contains($0) ? tracks[$0] : nil } }

    /// The next few tracks after the current one.
    var upNext: [Track] {
        guard !order.isEmpty else { return [] }
        var result: [Track] = []
        var pos = currentIndex == nil ? -1 : orderPos
        let wanted = min(3, order.count - (currentIndex == nil ? 0 : 1))
        guard wanted > 0 else { return [] }
        for _ in 0..<wanted {
            pos += 1
            if pos >= order.count {
                if repeatMode == .all { pos = 0 } else { break }
            }
            if tracks.indices.contains(order[pos]) { result.append(tracks[order[pos]]) }
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
                self.pause()                       // phone call, alarm, Siri...
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

    private func restoreLibrary() {
        // The app's own Documents folder (shows up in Files > On My iPhone > mish)
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
                found.append(root) // a single file
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
            .sorted { $0.path.lowercased() < $1.path.lowercased() }
            .map { Track(url: $0, title: $0.deletingPathExtension().lastPathComponent) }
        currentIndex = currentURL.flatMap { u in tracks.firstIndex { $0.url == u } }
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
    
                    if meta.title == nil {
                        meta.title = tags["TITLE"]
                    }
    
                    if meta.artist == nil {
                        meta.artist = tags["ARTIST"] ?? tags["ALBUMARTIST"]
                    }
    
                    if meta.album == nil {
                        meta.album = tags["ALBUM"]
                    }
                }
    
                if meta.artwork == nil {
                    meta.artwork = ArtworkMetadataReader.embeddedArtwork(for: track.url)
                }
    
                if meta.artwork == nil {
                    meta.artwork = ArtworkMetadataReader.folderArtwork(for: track.url)
                }

                if meta.artwork == nil {
                    meta.artwork = ArtworkMetadataReader.embeddedArtwork(for: track.url)
                }
                
                if meta.artwork == nil {
                    meta.artwork = ArtworkMetadataReader.folderArtwork(for: track.url)
                }
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

    private static func string(_ items: [AVMetadataItem], _ id: AVMetadataIdentifier) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first,
              let value = try? await item.load(.stringValue),
              !value.isEmpty else { return nil }
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
    private func rebuildOrder() {
        let all = Array(tracks.indices)
        if shuffleOn {
            // Every track once in random order, starting with the one that's playing
            var rest = all.filter { $0 != currentIndex }
            rest.shuffle()
            order = (currentIndex.map { [$0] } ?? []) + rest
            orderPos = 0
        } else {
            order = all
            orderPos = currentIndex ?? 0
        }
        objectWillChange.send()
    }

    // MARK: - Playback
    func play(index: Int) {
        guard tracks.indices.contains(index) else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: tracks[index].url)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            player = p
            currentIndex = index
            if let pos = order.firstIndex(of: index) { orderPos = pos }
            isPlaying = true
            currentTime = 0
            startTimer()
            updateNowPlaying()
        } catch {
            print("Could not play \(tracks[index].url.lastPathComponent): \(error)")
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
        guard !order.isEmpty else { return }
        var pos = orderPos + 1
        if pos >= order.count {
            guard repeatMode == .all else { stopAtEnd(); return }
            pos = 0
        }
        orderPos = pos
        play(index: order[pos])
    }

    func previous() {
        if (player?.currentTime ?? 0) > 3 { seek(to: 0); return } // like most players: restart first
        guard !order.isEmpty else { return }
        var pos = orderPos - 1
        if pos < 0 { pos = repeatMode == .all ? order.count - 1 : 0 }
        orderPos = pos
        play(index: order[pos])
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
        currentTime = 0
        timer?.invalidate()
        updateNowPlaying()
    }

    private func startTimer() {
    timer?.invalidate()

    timer = Timer.scheduledTimer(
        withTimeInterval: 0.1,
        repeats: true
    ) { [weak self] _ in
        guard let self = self,
              let player = self.player else { return }

        self.currentTime = player.currentTime

        guard self.isPlaying,
              let track = self.currentTrack else { return }

        let url = track.url
        let time = player.currentTime

        self.audioSampler.analyze(url: url, at: time) {
            [weak self] newSpectrum in

            guard let self = self,
                  self.isPlaying,
                  self.currentTrack?.url == url else {
                return
            }

            self.spectrum = newSpectrum
        }
    }
}

    // A track finished by itself
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            guard flag else { return }
            if self.repeatMode == .one, let i = self.currentIndex {
                self.play(index: i)
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
