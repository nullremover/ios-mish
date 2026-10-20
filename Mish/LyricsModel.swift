
import Foundation
import Combine

@MainActor
final class LyricsModel: ObservableObject {
    @Published private(set) var lyrics: String?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var currentKey: String?
    private var requestID = UUID()

    func clear() {
        requestID = UUID()
        currentKey = nil
        lyrics = nil
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

        if currentKey == key {
            return
        }

        currentKey = key
        let id = UUID()
        requestID = id

        lyrics = nil
        errorMessage = nil
        isLoading = true

        defer {
            if requestID == id {
                isLoading = false
            }
        }

        do {
            var url = URL(
                string: "https://api.lyrics.ovh/v1/"
            )!
            url.appendPathComponent(artist)
            url.appendPathComponent(title)

            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Accept"
            )

            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard requestID == id else { return }

            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                errorMessage = "Lyrics weren't found for this song."
                return
            }

            let result = try JSONDecoder().decode(
                LyricsResponse.self,
                from: data
            )

            
            let cleaned = Self.formatLyrics(result.lyrics)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleaned.isEmpty {
                errorMessage = "No lyrics available for this song."
            } else {
                lyrics = cleaned
            }
        } catch {
            guard requestID == id else { return }

            if (error as? URLError)?.code == .cancelled {
                return
            }

            errorMessage = "Couldn't load lyrics. Check your connection."
        }
    }
    
    
    private static func formatLyrics(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    
        let lines = normalized.components(separatedBy: "\n")
            .map {
                $0.trimmingCharacters(in: .whitespaces)
            }
    
        var formatted: [String] = []
        var previousLineWasEmpty = false
    
        for line in lines {
            let isEmpty = line.isEmpty
    
            // Keep verse breaks, but remove excessive blank lines.
            if isEmpty && previousLineWasEmpty {
                continue
            }
    
            formatted.append(line)
            previousLineWasEmpty = isEmpty
        }
    
        return formatted.joined(separator: "\n")
    }
}

private struct LyricsResponse: Decodable {
    let lyrics: String
}
