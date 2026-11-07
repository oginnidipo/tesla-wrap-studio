import ImageIO
import UIKit

/// Photo and text stickers, stored as PNGs in `Documents/Stickers` and shared by all designs.
struct StickerLibrary {
    let documentsURL: URL

    init(documentsURL: URL = URL.documentsDirectory) {
        self.documentsURL = documentsURL
    }

    var directory: URL { documentsURL.appending(path: "Stickers", directoryHint: .isDirectory) }

    // NSCache is thread-safe. Decoding a sticker on every SwiftUI update during a drag
    // would otherwise hit the disk once per frame.
    nonisolated(unsafe) private static let cache = NSCache<NSString, UIImage>()

    func image(named name: String) -> UIImage? {
        guard name == URL(filePath: name).lastPathComponent else { return nil }
        let path = directory.appending(path: name).path
        if let cached = Self.cache.object(forKey: path as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        Self.cache.setObject(image, forKey: path as NSString)
        return image
    }

    /// Newest first.
    func names() -> [String] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey],
                                                                  options: .skipsHiddenFiles)) ?? []
        var entries: [(name: String, created: Date)] = []
        for url in urls where url.pathExtension.lowercased() == "png" {
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            entries.append((url.lastPathComponent, created))
        }
        entries.sort { lhs, rhs in lhs.created == rhs.created ? lhs.name > rhs.name : lhs.created > rhs.created }
        return entries.map(\.name)
    }

    func importPhoto(_ data: Data) throws -> String {
        // Decode directly to a thumbnail instead of expanding a full-resolution camera photo.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 700,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary),
              let png = UIImage(cgImage: thumbnail).pngData() else { throw StudioError.unreadableImage }
        return try store(png, prefix: "st")
    }

    func add(_ image: UIImage, prefix: String) throws -> String {
        guard let png = image.pngData() else { throw StudioError.pngEncoding }
        return try store(png, prefix: prefix)
    }

    func remove(named name: String) throws {
        guard name == URL(filePath: name).lastPathComponent else { return }
        let url = directory.appending(path: name)
        Self.cache.removeObject(forKey: url.path as NSString)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private func store(_ png: Data, prefix: String) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(prefix)-\(UUID().uuidString).png"
        try png.write(to: directory.appending(path: name), options: .atomic)
        return name
    }
}
