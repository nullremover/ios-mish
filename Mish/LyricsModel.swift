
import Foundation
import Combine

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: TimeInterval
    let text: String
}

@MainActor
final class LyricsModel: ObservableObject {
    @Published private(set) var lyrics: String?
    @Published private(set) var syncedLines: [LyricLine] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var currentKey: String?
    private var requestID = UUID()

    func clear() {
        requestID = UUID()
        currentKey = nil
        lyrics = nil
        syncedLines = []
        errorMessage = nil
        isLoading = false
    }

    func load(artist: String, title: String) async {
        let artist = artist.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let title = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !artist.isEmpty, !title.isEmpty,
              artist != "Unknown Artist",
              title != "Unknown Title" else {
            clear()
            errorMessage = "Track information is missing."
            return
        }

        let key = "\(artist.lowercased())|\(title.lowercased())"
        if currentKey == key { return }

        currentKey = key
        let id = UUID()
        requestID = id
        lyrics = nil
        syncedLines = []
        errorMessage = nil
        isLoading = true

        defer {
            if requestID == id {
                isLoading = false
            }
        }

        do {
            var components = URLComponents(
                string: "https://lrclib.net/api/get"
            )!

            components.queryItems = [
                URLQueryItem(name: "artist_name", value: artist),
                URLQueryItem(name: "track_name", value: title)
            ]

            guard let url = components.url else {
                errorMessage = "Couldn't create the lyrics request."
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue(
                "Mish iOS Music Player",
                forHTTPHeaderField: "User-Agent"
            )

            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard requestID == id else { return }

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                errorMessage = "Lyrics weren't found for this song."
                return
            }

            let result = try JSONDecoder().decode(
                LyricsResponse.self,
                from: data
            )

            let timedLines = Self.parseLRC(
                result.syncedLyrics ?? ""
            )

            syncedLines = timedLines
            lyrics = result.plainLyrics
                ?? timedLines.map(\.text).joined(separator: "\n")

            if lyrics?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty == true {
                lyrics = nil
            }

            if timedLines.isEmpty {
                errorMessage = lyrics == nil
                    ? "No lyrics available for this song."
                    : "Lyrics found, but synced timing isn't available."
            }
        } catch {
            guard requestID == id else { return }
            errorMessage = "Couldn't load lyrics. Check your connection."
        }
    }

    private static func parseLRC(_ input: String) -> [LyricLine] {
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d+))?\]\s*(.*)"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return []
        }

        var lines: [LyricLine] = []

        for rawLine in input.components(separatedBy: .newlines) {
            let range = NSRange(
                rawLine.startIndex..<rawLine.endIndex,
                in: rawLine
            )

            for match in regex.matches(
                in: rawLine,
                range: range
            ) {
                guard let minutesRange = Range(
                    match.range(at: 1), in: rawLine
                ),
                let secondsRange = Range(
                    match.range(at: 2), in: rawLine
                ),
                let minutes = Double(rawLine[minutesRange]),
                let seconds = Double(rawLine[secondsRange]),
                let textRange = Range(
                    match.range(at: 4), in: rawLine
                ) else {
                    continue
                }

                var fraction = 0.0
                if let fractionRange = Range(
                    match.range(at: 3), in: rawLine
                ) {
                    let digits = String(rawLine[fractionRange])
                    fraction = (Double("0." + digits) ?? 0)
                }

                let timestamp = minutes * 60 + seconds + fraction

                lines.append(
                    LyricLine(
                        id: lines.count,
                        time: timestamp,
                        text: String(rawLine[textRange])
                    )
                )
            }
        }

        return lines.sorted { $0.time < $1.time }
    }
}

private struct LyricsResponse: Decodable {
    let plainLyrics: String?
    let syncedLyrics: String?
}
