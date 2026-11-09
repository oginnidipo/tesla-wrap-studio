import PencilKit
import Testing
import UIKit
@testable import Tesla_Car_Wrap

/// Pins the asset contract every `Car` case must satisfy: four decodable images whose
/// pixel sizes exactly equal `templateSize`, plus a working PanelMap. Adding a 13th body
/// style fails here instead of showing a blank canvas at runtime.
@MainActor struct CarAssetTests {
    @Test(arguments: Car.allCases)
    func everyCarHasCompleteAlignedArtwork(car: Car) throws {
        let template = try #require(UIImage(named: car.template))
        let mask = try #require(UIImage(named: car.maskImage).flatMap { $0.cgImage })
        let overlay = try #require(UIImage(named: car.overlayImage))
        #expect(template.size == car.templateSize,
                "\(car.rawValue) template \(template.size) != templateSize \(car.templateSize)")
        #expect(mask.width == Int(car.templateSize.width) && mask.height == Int(car.templateSize.height),
                "\(car.rawValue) mask \(mask.width)x\(mask.height) != \(car.templateSize)")
        #expect(overlay.size == car.templateSize,
                "\(car.rawValue) overlay \(overlay.size) != \(car.templateSize)")
        #expect(PanelMap.forCar(car)?.panelCount ?? 0 > 0,
                "\(car.rawValue) mask yields no usable body panels")
    }

    /// Golden-image pin: the export layering (white -> template -> fills -> strokes ->
    /// stickers -> overlay) must stay stable. Deterministic design, deterministic pixels.
    @Test(arguments: [Car.m3, Car.ct])
    func goldenExportStaysStable(car: Car) throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = StickerLibrary(documentsURL: directory)
        let stickerFile = try library.importPhoto(try UIKitTestSupport.redSquarePNG())
        // Start the sticker on a guaranteed-paintable panel: the template centre is often glass.
        let map = try #require(PanelMap.forCar(car))
        let home = try #require(map.stickerHome)
        // A second, distinct paintable panel for the stroke: pick one far from the sticker home.
        let strokePoint = map.panelPixels
            .compactMap { region -> CGPoint? in
                guard let first = region.first else { return nil }
                let px = CGPoint(x: CGFloat(Int(first) % map.width) + 0.5,
                                 y: CGFloat(Int(first) / map.width) + 0.5)
                return px.distance(to: home.center) > 300 ? px : nil
            }
            .first ?? home.center
        var sticker = CanvasSticker(id: UUID(), x: home.center.x, y: home.center.y,
                                    side: CanvasGeometry.stickerSide(260, magnification: 1),
                                    fileName: stickerFile)
        sticker.rotation = 0.4
        // Hood/hood-equivalent pixel from the panel map itself: the fill must be beneath the stroke.
        let design = WrapDesign(drawing: TestArtwork.drawing(from: strokePoint, to: CGPoint(x: strokePoint.x + 180, y: strokePoint.y + 120)),
                                stickers: [sticker], fillHex: "269BFF")
        let rendered = try WrapRenderer.render(car: car, design: design, library: library)

        // 1) The sticker must be visible at its centre: red sticker pixels beat the blue fill.
        let pixels = try TestArtwork.pixels(rendered)
        let width = Int(rendered.size.width)
        let centre = TestArtwork.pixel(pixels, width: width, x: Int(home.center.x), y: Int(home.center.y))
        #expect(centre[0] > 150 && centre[2] < 120,
                "sticker pixels missing at \(home.center) — a layer is drawn on top of the sticker")

        // 2) The stroke must survive masking and sit on top of the blue fill.
        let strokePixel = TestArtwork.pixel(pixels, width: width, x: Int(strokePoint.x), y: Int(strokePoint.y))
        let isWhite = strokePixel[0] == 255 && strokePixel[1] == 255 && strokePixel[2] == 255
        let isBlue = strokePixel[2] > 180 && strokePixel[0] < 120
        #expect(!isWhite && !isBlue,
                "stroke missing at \(strokePoint) — mask or layering broke (got \(strokePixel))")

        // 3) PNG stays inside Tesla's file-size ceiling after the encoding ladder.
        let encoded = try WrapRenderer.encodePNG(rendered)
        #expect(encoded.data.count <= WrapRenderer.maximumFileSize)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private enum UIKitTestSupport {
    @MainActor static func redSquarePNG() throws -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: format).image { _ in
            UIColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1).setFill(); UIBezierPath(rect: CGRect(x: 0, y: 0, width: 200, height: 200)).fill()
        }
        guard let png = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        return png
    }
}

import Testing
import UIKit
@testable import Tesla_Car_Wrap

