import PencilKit
import Testing
import UIKit
@testable import Tesla_Car_Wrap

@MainActor struct WrapRendererTests {
    @Test(arguments: Car.allCases)
    func fillOnlyExportHasCorrectSizeAndRealPNG(car: Car) throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: car, store: store)
        session.setFill("F14B35")
        let wrap = try WrapRenderer.export(session: session)
        defer { try? FileManager.default.removeItem(at: wrap.fileURL.deletingLastPathComponent()) }
        #expect(wrap.image.size == car.templateSize)
        #expect(wrap.pngData.count <= WrapRenderer.maximumFileSize)
        #expect(Array(wrap.pngData.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
        #expect(try Data(contentsOf: wrap.fileURL) == wrap.pngData)
        #expect(wrap.fileURL.lastPathComponent == "\(car.name) Wrap.png")
        #expect(wrap.fileURL.lastPathComponent.count <= WrapRenderer.maximumFileNameLength)
    }

    @Test func fileNamesFollowTeslasRules() {
        #expect(WrapRenderer.fileName(for: "Midnight Racer!", car: .m3) == "Midnight Racer.png")
        #expect(WrapRenderer.fileName(for: "Café   Noir_2-b", car: .m3) == "Cafe Noir_2-b.png")
        let long = WrapRenderer.fileName(for: "An extremely long design name that keeps going", car: .m3)
        #expect(long.count <= 30)
        #expect(long.hasSuffix(".png"))
        #expect(!long.contains(" .png"))
        let fallback = WrapRenderer.fileName(for: "🔥🔥", car: .ct, date: Date(timeIntervalSince1970: 0))
        #expect(fallback.hasPrefix("ct-"))
        #expect(fallback.count <= 30)
        for name in [long, fallback, "Midnight Racer.png"] {
            let stem = name.dropLast(4)
            #expect(stem.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || " _-".contains($0)) })
        }
    }

    @Test func panelFillColoursOnlyItsPanel() throws {
        let image = try WrapRenderer.background(car: .m3, fillHex: nil, panelFills: [PanelFill(x: 512, y: 260, hex: "F14B35")])
        let pixels = try TestArtwork.pixels(image)
        #expect(TestArtwork.isCoral(TestArtwork.pixel(pixels, width: 1024, x: 512, y: 260)))
        #expect(!TestArtwork.isCoral(TestArtwork.pixel(pixels, width: 1024, x: 140, y: 480)))
        // Panel fills sit on top of the body fill.
        let layered = try TestArtwork.pixels(WrapRenderer.background(car: .m3, fillHex: "558BC7",
                                                                     panelFills: [PanelFill(x: 512, y: 260, hex: "F14B35")]))
        #expect(TestArtwork.isCoral(TestArtwork.pixel(layered, width: 1024, x: 512, y: 260)))
        let door = TestArtwork.pixel(layered, width: 1024, x: 140, y: 480)
        #expect(door[2] > 150 && door[0] < 120, "Body fill still covers the other panels")
    }

    @Test func stickerOnlyExportChangesArtworkAndKeepsTrimClean() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = StickerLibrary(documentsURL: directory)
        let imageData = try #require(TestArtwork.image(size: CGSize(width: 1024, height: 1024)).pngData())
        let name = try library.importPhoto(imageData)
        let baseline = try WrapRenderer.render(car: .m3, drawing: PKDrawing(), stickers: [], fillHex: nil, library: library)
        let sticker = CanvasSticker(id: UUID(), x: 512, y: 512, side: 1024, fileName: name)
        let output = try WrapRenderer.render(car: .m3, drawing: PKDrawing(), stickers: [sticker], fillHex: nil, library: library)
        let before = try TestArtwork.pixels(baseline)
        let after = try TestArtwork.pixels(output)
        #expect(before != after)
        // Opaque corners and trim must not be covered by a full-canvas sticker.
        #expect(Array(before.prefix(4)) == Array(after.prefix(4)))
        let center = (512 * 1024 + 512) * 4
        #expect(Array(before[center..<(center + 4)]) == Array(after[center..<(center + 4)]))
    }

    @Test func rotatedAndFlippedStickersRenderDifferently() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = StickerLibrary(documentsURL: directory)
        // A wide image: rotating it a quarter turn changes which pixels it covers.
        let name = try library.add(TestArtwork.image(size: CGSize(width: 400, height: 100)), prefix: "st")
        func render(rotation: Double, flipped: Bool = false) throws -> [UInt8] {
            let sticker = CanvasSticker(id: UUID(), x: 512, y: 260, side: 300, fileName: name, rotation: rotation, isFlipped: flipped)
            return try TestArtwork.pixels(WrapRenderer.render(car: .m3, drawing: PKDrawing(), stickers: [sticker],
                                                              fillHex: nil, library: library))
        }
        func isRed(_ pixels: [UInt8]) -> Bool {
            let rgba = TestArtwork.pixel(pixels, width: 1024, x: 450, y: 270)
            return rgba[0] > 200 && rgba[1] < 60 && rgba[2] < 60
        }
        // Level, the 300 × 75 sticker spans x 362–662; turned, it spans x 474–550.
        let level = try render(rotation: 0)
        let turned = try render(rotation: .pi / 2)
        #expect(isRed(level))
        #expect(!isRed(turned))
        #expect(try render(rotation: 0, flipped: true) == level, "A symmetric image looks the same flipped")
    }

    @Test func thumbnailIsSmallPNG() throws {
        let png = try WrapRenderer.thumbnail(car: .ct, design: WrapDesign(fillHex: "5AAB88"),
                                             library: StickerLibrary(documentsURL: TestArtwork.temporaryDirectory()))
        let image = try #require(UIImage(data: png))
        #expect(image.size == CGSize(width: 480, height: 360))
    }

    @Test func importedStickerPreservesItsAspectRatio() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = StickerLibrary(documentsURL: directory)
        let data = try #require(TestArtwork.image().pngData())
        let name = try library.importPhoto(data)
        let image = try #require(library.image(named: name))
        #expect(image.size.width / image.size.height == 2)
        #expect(library.image(named: "../outside.png") == nil)
        #expect(library.names() == [name])
        try library.remove(named: name)
        #expect(library.names().isEmpty)
        #expect(library.image(named: name) == nil)
    }

    @Test func photoHeavyPNGIsDownsampledWithinTheLimit() throws {
        var state: UInt32 = 42
        var bytes = [UInt8](repeating: 255, count: 1024 * 1024 * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            for channel in 0..<3 {
                state = state &* 1_664_525 &+ 1_013_904_223
                bytes[index + channel] = UInt8(truncatingIfNeeded: state >> 24)
            }
        }
        let context = try #require(CGContext(data: &bytes, width: 1024, height: 1024, bitsPerComponent: 8,
                                             bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = UIImage(cgImage: try #require(context.makeImage()))
        let original = try #require(image.pngData())
        try #require(original.count > WrapRenderer.maximumFileSize)
        let encoded = try WrapRenderer.encodePNG(image)
        #expect(encoded.data.count <= WrapRenderer.maximumFileSize)
        #expect(encoded.image.size.width >= 512)
        #expect(encoded.image.size.height >= 512)
        #expect(encoded.image.size.width < 1024)
    }

    @Test(arguments: Car.allCases)
    func fillFollowsTheUnflippedMask(car: Car) throws {
        let image = try WrapRenderer.background(car: car, fillHex: "F14B35")
        let pixels = try TestArtwork.pixels(image)
        let mask = try #require(UIImage(named: car.maskImage)?.cgImage)
        let maskPixels = try TestArtwork.pixels(UIImage(cgImage: mask))
        let width = Int(car.templateSize.width)
        let height = Int(car.templateSize.height)
        var mismatches = 0
        for y in stride(from: 16, to: height, by: 32) {
            for x in stride(from: 16, to: width, by: 32) {
                let value = maskPixels[(y * width + x) * 4]
                guard value < 5 || value > 250 else { continue }
                let expectedFill = value > 250
                if TestArtwork.isCoral(TestArtwork.pixel(pixels, width: width, x: x, y: y)) != expectedFill { mismatches += 1 }
            }
        }
        #expect(mismatches == 0, "Body fill must match the original mask orientation")
    }
}
