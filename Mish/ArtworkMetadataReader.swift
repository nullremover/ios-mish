
import Foundation
import UIKit

enum ArtworkMetadataReader {

    // MARK: - Public entry point

    static func embeddedArtwork(for url: URL) -> UIImage? {
        switch url.pathExtension.lowercased() {
        case "flac":
            return flacArtwork(for: url)
        case "wav", "wave":
            return wavArtwork(for: url)
        default:
            return nil
        }
    }
    
    
    // MARK: - FLAC Vorbis Comments

    static func flacComments(for url: URL) -> [String: String] {
        guard url.pathExtension.lowercased() == "flac",
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count >= 8,
              data.prefix(4) == Data("fLaC".utf8) else {
            return [:]
        }

        var offset = 4

        while offset <= data.count - 4 {
            let header = data[offset]
            let isLast = (header & 0x80) != 0
            let type = header & 0x7F

            let length = (Int(data[offset + 1]) << 16)
                | (Int(data[offset + 2]) << 8)
                | Int(data[offset + 3])

            offset += 4

            guard length <= data.count - offset else {
                return [:]
            }

            let end = offset + length

            // FLAC metadata block type 4 = Vorbis Comment.
            if type == 4 {
                return parseVorbisComments(
                    data: data,
                    start: offset,
                    end: end
                )
            }

            offset = end
            if isLast { break }
        }

        return [:]
    }

    private static func parseVorbisComments(
        data: Data,
        start: Int,
        end: Int
    ) -> [String: String] {
        var cursor = start

        func readLE32() -> UInt32? {
            guard cursor >= start, cursor <= end - 4 else {
                return nil
            }

            let value = UInt32(data[cursor])
                | (UInt32(data[cursor + 1]) << 8)
                | (UInt32(data[cursor + 2]) << 16)
                | (UInt32(data[cursor + 3]) << 24)

            cursor += 4
            return value
        }

        // Vendor string.
        guard let vendorLength = readLE32(),
              vendorLength <= UInt32(max(0, end - cursor)) else {
            return [:]
        }
        cursor += Int(vendorLength)

        // Number of comments.
        guard let count = readLE32(), count <= 100_000 else {
            return [:]
        }

        var comments: [String: String] = [:]

        for _ in 0..<count {
            guard let commentLength = readLE32(),
                  commentLength > 0,
                  commentLength <= UInt32(max(0, end - cursor)) else {
                return comments
            }

            let commentEnd = cursor + Int(commentLength)
            let bytes = data.subdata(in: cursor..<commentEnd)
            cursor = commentEnd

            guard let comment = String(data: bytes, encoding: .utf8),
                  let separator = comment.firstIndex(of: "=") else {
                continue
            }

            let key = String(comment[..<separator])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            let value = String(comment[comment.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !key.isEmpty, !value.isEmpty, comments[key] == nil {
                comments[key] = value
            }
        }

        return comments
    }

    // MARK: - External cover images

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

    // MARK: - FLAC

    private static func flacArtwork(for url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count >= 8,
              data.prefix(4) == Data("fLaC".utf8) else {
            return nil
        }

        var offset = 4
        var fallback: UIImage?

        while offset + 4 <= data.count {
            let header = data[offset]
            let isLast = (header & 0x80) != 0
            let type = header & 0x7F

            let length = (Int(data[offset + 1]) << 16)
                | (Int(data[offset + 2]) << 8)
                | Int(data[offset + 3])

            offset += 4

            guard length <= data.count - offset else {
                return fallback
            }

            let end = offset + length

            if type == 6,
               let picture = parseFLACPicture(
                    data: data,
                    start: offset,
                    end: end
               ) {
                if picture.type == 3 {
                    return picture.image
                }

                if fallback == nil {
                    fallback = picture.image
                }
            }

            offset = end
            if isLast { break }
        }

        return fallback
    }

    private static func parseFLACPicture(
        data: Data,
        start: Int,
        end: Int
    ) -> (type: UInt32, image: UIImage)? {
        var cursor = start

        func readUInt32() -> UInt32? {
            guard cursor >= 0, cursor <= end - 4 else {
                return nil
            }

            let value = (UInt32(data[cursor]) << 24)
                | (UInt32(data[cursor + 1]) << 16)
                | (UInt32(data[cursor + 2]) << 8)
                | UInt32(data[cursor + 3])

            cursor += 4
            return value
        }

        guard let pictureType = readUInt32(),
              let mimeLength = readUInt32(),
              mimeLength <= UInt32(max(0, end - cursor)) else {
            return nil
        }

        cursor += Int(mimeLength)

        guard let descriptionLength = readUInt32(),
              descriptionLength <= UInt32(max(0, end - cursor)) else {
            return nil
        }

        cursor += Int(descriptionLength)

        // Width, height, color depth and palette size.
        guard cursor <= end - 16 else { return nil }
        cursor += 16

        guard let imageLength = readUInt32(),
              imageLength > 0,
              imageLength <= 16 * 1024 * 1024,
              imageLength <= UInt32(max(0, end - cursor)) else {
            return nil
        }

        let imageEnd = cursor + Int(imageLength)
        guard imageEnd <= end else { return nil }

        let imageData = data.subdata(in: cursor..<imageEnd)

        guard let image = UIImage(data: imageData) else {
            return nil
        }

        return (pictureType, image)
    }

    // MARK: - WAV containing an ID3 chunk

    private static func wavArtwork(for url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count >= 12,
              ascii(data, 0, 4) == "RIFF",
              ascii(data, 8, 4) == "WAVE" else {
            return nil
        }

        var offset = 12

        while offset <= data.count - 8 {
            let chunkID = ascii(data, offset, 4)
            guard let rawSize = littleEndianUInt32(data, offset + 4) else {
                return nil
            }

            // Prevent oversized or invalid chunks from causing out-of-bounds reads.
            guard rawSize <= UInt32(data.count - offset - 8) else {
                return nil
            }

            let chunkSize = Int(rawSize)
            let chunkStart = offset + 8
            let chunkEnd = chunkStart + chunkSize

            if chunkID == "id3 " || chunkID == "ID3 " {
                if let image = id3Artwork(
                    data: data,
                    start: chunkStart,
                    end: chunkEnd
                ) {
                    return image
                }
            }

            // RIFF chunks are aligned to two-byte boundaries.
            let next = chunkEnd + (chunkSize & 1)
            guard next > offset, next <= data.count else { break }
            offset = next
        }

        return nil
    }

    // MARK: - ID3 APIC picture frame

    private static func id3Artwork(
        data: Data,
        start: Int,
        end: Int
    ) -> UIImage? {
        guard start >= 0,
              end <= data.count,
              end - start >= 10,
              ascii(data, start, 3) == "ID3" else {
            return nil
        }

        let version = data[start + 3]

        // ID3v2.3 and ID3v2.4 frame layouts.
        guard version == 3 || version == 4 else {
            return nil
        }

        guard let tagSize = syncSafeUInt32(data, start + 6),
              tagSize <= UInt32(end - start - 10) else {
            return nil
        }

        let tagEnd = start + 10 + Int(tagSize)
        var offset = start + 10

        while offset <= tagEnd - 10 {
            let frameID = ascii(data, offset, 4)

            if frameID == "\0\0\0\0" { break }

            let frameSize: UInt32?
            if version == 4 {
                frameSize = syncSafeUInt32(data, offset + 4)
            } else {
                frameSize = bigEndianUInt32(data, offset + 4)
            }

            guard let frameSize,
                  frameSize > 0,
                  frameSize <= UInt32(tagEnd - offset - 10) else {
                break
            }

            let frameStart = offset + 10
            let frameEnd = frameStart + Int(frameSize)

            if frameID == "APIC",
               let image = parseAPIC(
                    data: data,
                    start: frameStart,
                    end: frameEnd
               ) {
                return image
            }

            offset = frameEnd
        }

        return nil
    }

    private static func parseAPIC(
        data: Data,
        start: Int,
        end: Int
    ) -> UIImage? {
        guard start >= 0, end <= data.count, start < end else {
            return nil
        }

        let encoding = data[start]
        var cursor = start + 1

        // Skip MIME type, which ends with a zero byte.
        while cursor < end && data[cursor] != 0 {
            cursor += 1
        }

        guard cursor < end else { return nil }
        cursor += 1

        // Picture type.
        guard cursor < end else { return nil }
        cursor += 1

        // Skip the description using its encoding's terminator.
        if encoding == 1 || encoding == 2 {
            var found = false

            while cursor + 1 < end {
                if data[cursor] == 0 && data[cursor + 1] == 0 {
                    cursor += 2
                    found = true
                    break
                }
                cursor += 2
            }

            guard found else { return nil }
        } else {
            while cursor < end && data[cursor] != 0 {
                cursor += 1
            }

            guard cursor < end else { return nil }
            cursor += 1
        }

        guard cursor < end else { return nil }

        let imageData = data.subdata(in: cursor..<end)
        return UIImage(data: imageData)
    }

    // MARK: - Binary helpers

    private static func ascii(
        _ data: Data,
        _ offset: Int,
        _ count: Int
    ) -> String {
        guard offset >= 0,
              count >= 0,
              offset <= data.count,
              count <= data.count - offset else {
            return ""
        }

        return String(
            data: data[offset..<(offset + count)],
            encoding: .ascii
        ) ?? ""
    }

    private static func littleEndianUInt32(
        _ data: Data,
        _ offset: Int
    ) -> UInt32? {
        guard offset >= 0, offset <= data.count - 4 else {
            return nil
        }

        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func bigEndianUInt32(
        _ data: Data,
        _ offset: Int
    ) -> UInt32? {
        guard offset >= 0, offset <= data.count - 4 else {
            return nil
        }

        return (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func syncSafeUInt32(
        _ data: Data,
        _ offset: Int
    ) -> UInt32? {
        guard offset >= 0, offset <= data.count - 4 else {
            return nil
        }

        let a = data[offset]
        let b = data[offset + 1]
        let c = data[offset + 2]
        let d = data[offset + 3]

        guard (a & 0x80) == 0,
              (b & 0x80) == 0,
              (c & 0x80) == 0,
              (d & 0x80) == 0 else {
            return nil
        }

        return (UInt32(a) << 21)
            | (UInt32(b) << 14)
            | (UInt32(c) << 7)
            | UInt32(d)
    }
}