import ImageIO
import UIKit

struct StickerLibrary {
    let documentsURL: URL

    init(documentsURL: URL = URL.documentsDirectory) {
        self.documentsURL = documentsURL
    }

    var directory: URL { documentsURL.appending(path: "Stickers", directoryHint: .isDirectory) }

    func image(named name: String) -> UIImage? {
        guard name == URL(filePath: name).lastPathComponent else { return nil }
        return UIImage(contentsOfFile: directory.appending(path: name).path)
    }

    func names() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.lowercased().hasSuffix(".png") }.sorted().reversed()
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
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "st-\(UUID().uuidString).png"
        try png.write(to: directory.appending(path: name), options: .atomic)
        return name
    }
}
