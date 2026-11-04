import PencilKit
import SwiftUI

@MainActor enum WrapRenderer {
    static let maximumFileSize = 1_000_000

    static func background(car: Car, fillHex: String?) throws -> UIImage {
        guard let template = UIImage(named: car.template),
              let mask = UIImage(named: car.maskImage)?.cgImage else { throw StudioError.missingArtwork }
        let rect = CGRect(origin: .zero, size: car.templateSize)
        return renderer(size: car.templateSize).image { context in
            UIColor.white.setFill()
            context.fill(rect)
            template.draw(in: rect)
            if let fillHex {
                context.cgContext.saveGState()
                clipToPaintableBody(context.cgContext, rect: rect, mask: mask)
                UIColor(StudioStyle.color(hex: fillHex)).setFill()
                context.fill(rect)
                context.cgContext.restoreGState()
            }
        }
    }

    static func render(car: Car, drawing: PKDrawing, stickers: [CanvasSticker], fillHex: String?,
                       library: StickerLibrary) throws -> UIImage {
        let background = try background(car: car, fillHex: fillHex)
        guard let mask = UIImage(named: car.maskImage)?.cgImage,
              let overlay = UIImage(named: car.overlayImage) else { throw StudioError.missingArtwork }
        let rect = CGRect(origin: .zero, size: car.templateSize)
        let strokes = drawing.image(from: rect, scale: 1)
        return renderer(size: car.templateSize).image { context in
            background.draw(in: rect)
            context.cgContext.saveGState()
            clipToPaintableBody(context.cgContext, rect: rect, mask: mask)
            strokes.draw(in: rect)
            for sticker in stickers {
                guard let image = library.image(named: sticker.fileName) else { continue }
                let fitted = CanvasGeometry.fitRect(template: image.size, in: CGSize(width: sticker.side, height: sticker.side))
                image.draw(in: fitted.offsetBy(dx: sticker.x - sticker.side / 2, dy: sticker.y - sticker.side / 2))
            }
            context.cgContext.restoreGState()
            overlay.draw(in: rect)
        }
    }

    static func export(session: EditorSession) throws -> ExportedWrap {
        let image = try render(car: session.car, drawing: session.drawing, stickers: session.stickers,
                               fillHex: session.fillHex, library: session.stickerLibrary)
        let encoded = try encodePNG(image)
        let directory = URL.temporaryDirectory.appending(path: "WrapExports/\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = Date().formatted(.dateTime.year(.twoDigits).month(.twoDigits).day(.twoDigits)
            .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).locale(Locale(identifier: "en_US_POSIX")))
            .filter { $0.isASCII && $0.isNumber }
        let fileURL = directory.appending(path: "\(session.car.rawValue)-\(timestamp).png")
        try encoded.data.write(to: fileURL, options: .atomic)
        return ExportedWrap(image: encoded.image, pngData: encoded.data, fileURL: fileURL)
    }

    /// Keep a PNG, preserve the template's aspect ratio, and refuse files over Tesla's limit.
    /// Photo-heavy designs can be downsampled, but neither dimension goes below 512 pixels.
    static func encodePNG(_ image: UIImage) throws -> (image: UIImage, data: Data) {
        let minimumScale = max(512 / image.size.width, 512 / image.size.height)
        let scales = Array(Set([1, 0.875, 0.75, 0.625, 0.5, minimumScale]))
            .filter { $0 <= 1 && $0 >= minimumScale }.sorted(by: >)
        for scale in scales {
            let candidate: UIImage
            if scale == 1 { candidate = image }
            else {
                let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
                candidate = renderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            }
            guard let png = candidate.pngData() else { throw StudioError.pngEncoding }
            if png.count <= maximumFileSize { return (candidate, png) }
        }
        throw StudioError.oversizedExport
    }

    private static func renderer(size: CGSize) -> UIGraphicsImageRenderer {
        // Pixel-exact PNG composition needs UIKit's raster renderer rather than a SwiftUI screenshot.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
    }

    private static func clipToPaintableBody(_ context: CGContext, rect: CGRect, mask: CGImage) {
        // Quartz interprets image-mask rows in the opposite direction from UIKit images.
        // Establish the clip in Quartz coordinates, then restore the UIKit drawing transform.
        context.translateBy(x: 0, y: rect.height)
        context.scaleBy(x: 1, y: -1)
        context.clip(to: rect, mask: mask)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -rect.height)
    }
}
