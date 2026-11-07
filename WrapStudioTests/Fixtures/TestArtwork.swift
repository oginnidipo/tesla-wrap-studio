import PencilKit
import UIKit
@testable import Tesla_Car_Wrap

enum TestArtwork {
    @MainActor static func drawing(from start: CGPoint = CGPoint(x: 100, y: 200),
                                   to end: CGPoint = CGPoint(x: 300, y: 400)) -> PKDrawing {
        let points = [start, end].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 12, height: 12),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red),
                                           path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))])
    }

    @MainActor static func image(size: CGSize = CGSize(width: 120, height: 60)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func temporaryDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "WrapStudioTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A fresh store in its own temporary folder, removed by the returned cleanup.
    static func store() throws -> (store: DesignStore, cleanup: () -> Void) {
        let directory = try temporaryDirectory()
        return (DesignStore(documentsURL: directory), { try? FileManager.default.removeItem(at: directory) })
    }

    @MainActor static func pixels(_ image: UIImage) throws -> [UInt8] {
        let cgImage = try requireImage(image)
        var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let context = CGContext(data: &bytes, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8,
                                bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return bytes
    }

    /// RGBA of one pixel in an image of the given width.
    static func pixel(_ pixels: [UInt8], width: Int, x: Int, y: Int) -> [UInt8] {
        let offset = (y * width + x) * 4
        return Array(pixels[offset..<(offset + 4)])
    }

    static func isCoral(_ rgba: [UInt8]) -> Bool { rgba[0] > 220 && rgba[1] < 110 && rgba[2] < 100 }

    private static func requireImage(_ image: UIImage) throws -> CGImage {
        guard let cgImage = image.cgImage else { throw CocoaError(.fileReadCorruptFile) }
        return cgImage
    }
}
