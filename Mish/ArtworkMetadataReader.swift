
import Foundation
import UIKit

enum ArtworkMetadataReader {
    /// Searches common external cover-art filenames beside an audio file.
    static func folderArtwork(for audioURL: URL) -> UIImage? {
        let directory = audioURL.deletingLastPathComponent()

        let names = [
            "cover.jpg", "cover.jpeg", "cover.png",
            "folder.jpg", "folder.jpeg", "folder.png",
            "front.jpg", "front.jpeg", "front.png",
            "album.jpg", "album.jpeg", "album.png",
            "artwork.jpg", "artwork.jpeg", "artwork.png"
        ]

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let lookup = Dictionary(
            files.map { ($0.lastPathComponent.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for name in names {
            if let url = lookup[name],
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        return nil
    }
}
