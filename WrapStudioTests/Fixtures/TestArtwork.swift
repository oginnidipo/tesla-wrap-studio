import PencilKit
import UIKit

enum TestArtwork {
    @MainActor static func drawing() -> PKDrawing {
        let points = [CGPoint(x: 100, y: 200), CGPoint(x: 300, y: 400)].enumerated().map { index, point in
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

    @MainActor static func pixels(_ image: UIImage) throws -> [UInt8] {
        let cgImage = try requireImage(image)
        var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let context = CGContext(data: &bytes, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8,
                                bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return bytes
    }

    private static func requireImage(_ image: UIImage) throws -> CGImage {
        guard let cgImage = image.cgImage else { throw CocoaError(.fileReadCorruptFile) }
        return cgImage
    }
}
