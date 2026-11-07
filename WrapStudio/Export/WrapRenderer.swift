import PencilKit
import SwiftUI

@MainActor enum WrapRenderer {
    static let maximumFileSize = 1_000_000
    /// Tesla accepts up to 30 characters, including the extension.
    static let maximumFileNameLength = 30

    /// Template, body fill and panel fills: everything beneath the paint.
    static func background(car: Car, fillHex: String?, panelFills: [PanelFill] = []) throws -> UIImage {
        guard let template = UIImage(named: car.template),
              let mask = UIImage(named: car.maskImage)?.cgImage else { throw StudioError.missingArtwork }
        let panels: UIImage? = panelFills.isEmpty ? nil : PanelMap.forCar(car).flatMap { map in
            map.image(colors: map.resolvedColors(for: panelFills)).map { UIImage(cgImage: $0) }
        }
        let rect = CGRect(origin: .zero, size: car.templateSize)
        return renderer(size: car.templateSize).image { context in
            UIColor.white.setFill()
            context.fill(rect)
            template.draw(in: rect)
            if let fillHex {
                context.cgContext.saveGState()
                clipToPaintableBody(context.cgContext, rect: rect, mask: mask)
                StudioStyle.uiColor(hex: fillHex).setFill()
                context.fill(rect)
                context.cgContext.restoreGState()
            }
            panels?.draw(in: rect)
        }
    }

    static func render(car: Car, drawing: PKDrawing, stickers: [CanvasSticker], fillHex: String?,
                       panelFills: [PanelFill] = [], library: StickerLibrary) throws -> UIImage {
        let background = try background(car: car, fillHex: fillHex, panelFills: panelFills)
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
                draw(sticker, image: image, in: context.cgContext)
            }
            context.cgContext.restoreGState()
            overlay.draw(in: rect)
        }
    }

    static func render(car: Car, design: WrapDesign, library: StickerLibrary) throws -> UIImage {
        try render(car: car, drawing: PKDrawing(data: design.drawingData), stickers: design.stickers,
                   fillHex: design.fillHex, panelFills: design.panelFills, library: library)
    }

    /// A small PNG for the gallery.
    static func thumbnail(car: Car, design: WrapDesign, library: StickerLibrary, maximumPixels: CGFloat = 480) throws -> Data {
        let full = try render(car: car, design: design, library: library)
        let scale = maximumPixels / max(full.size.width, full.size.height)
        let size = CGSize(width: (full.size.width * scale).rounded(), height: (full.size.height * scale).rounded())
        let small = renderer(size: size).image { _ in full.draw(in: CGRect(origin: .zero, size: size)) }
        guard let png = small.pngData() else { throw StudioError.pngEncoding }
        return png
    }

    static func export(session: EditorSession) throws -> ExportedWrap {
        let image = try render(car: session.car, drawing: session.drawing, stickers: session.stickers,
                               fillHex: session.fillHex, panelFills: session.panelFills, library: session.stickerLibrary)
        let encoded = try encodePNG(image)
        let directory = URL.temporaryDirectory.appending(path: "WrapExports/\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: fileName(for: session.record.name, car: session.car))
        try encoded.data.write(to: fileURL, options: .atomic)
        return ExportedWrap(image: encoded.image, pngData: encoded.data, fileURL: fileURL)
    }

    /// The design's name is what Tesla shows in Paint Shop, so it becomes the file name,
    /// reduced to the characters Tesla accepts: letters, digits, spaces, `_` and `-`.
    static func fileName(for designName: String, car: Car, date: Date = .now) -> String {
        let folded = designName.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            let character = Character(scalar)
            if scalar.isASCII, character.isLetter || character.isNumber || character == "_" || character == "-" { return character }
            return " "
        }
        let words = String(allowed).split(separator: " ").joined(separator: " ")
        let stemLimit = maximumFileNameLength - ".png".count
        var stem = String(words.prefix(stemLimit)).trimmingCharacters(in: .whitespaces)
        if stem.isEmpty {
            let timestamp = date.formatted(.dateTime.year(.twoDigits).month(.twoDigits).day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).locale(Locale(identifier: "en_US_POSIX")))
                .filter { $0.isASCII && $0.isNumber }
            stem = "\(car.rawValue)-\(timestamp)"
        }
        return "\(stem).png"
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

    /// Draws a sticker centred on its position, flipped and then rotated.
    static func draw(_ sticker: CanvasSticker, image: UIImage, in context: CGContext) {
        let frame = CGSize(width: sticker.side, height: sticker.side)
        let fitted = CanvasGeometry.fitRect(template: image.size, in: frame)
        context.saveGState()
        context.translateBy(x: sticker.x, y: sticker.y)
        context.rotate(by: sticker.rotation)
        if sticker.isFlipped { context.scaleBy(x: -1, y: 1) }
        image.draw(in: fitted.offsetBy(dx: -sticker.side / 2, dy: -sticker.side / 2))
        context.restoreGState()
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
