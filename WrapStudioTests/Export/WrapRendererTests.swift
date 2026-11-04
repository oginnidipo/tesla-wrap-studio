import PencilKit
import Testing
import UIKit
@testable import Tesla_Car_Wrap

@MainActor struct WrapRendererTests {
    @Test(arguments: Car.allCases)
    func fillOnlyExportHasCorrectSizeAndRealPNG(car: Car) throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = EditorSession(car: car, repository: DesignRepository(documentsURL: directory))
        session.setFill("F14B35")
        let wrap = try WrapRenderer.export(session: session)
        defer { try? FileManager.default.removeItem(at: wrap.fileURL.deletingLastPathComponent()) }
        #expect(wrap.image.size == car.templateSize)
        #expect(wrap.pngData.count <= WrapRenderer.maximumFileSize)
        #expect(Array(wrap.pngData.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
        #expect(try Data(contentsOf: wrap.fileURL) == wrap.pngData)
        #expect(wrap.fileURL.lastPathComponent.count <= 30)
        #expect(wrap.fileURL.pathExtension == "png")
        session.persistNow()
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

    @Test func importedStickerPreservesItsAspectRatio() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = StickerLibrary(documentsURL: directory)
        let data = try #require(TestArtwork.image().pngData())
        let name = try library.importPhoto(data)
        let image = try #require(library.image(named: name))
        #expect(image.size.width / image.size.height == 2)
        #expect(library.image(named: "../outside.png") == nil)
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
        let bytes = try #require(mask.dataProvider?.data) as Data
        let width = Int(car.templateSize.width)
        let height = Int(car.templateSize.height)
        var mismatches = 0
        for y in stride(from: 16, to: height, by: 32) {
            for x in stride(from: 16, to: width, by: 32) {
                let value = bytes[y * mask.bytesPerRow + x]
                guard value < 5 || value > 250 else { continue }
                let expectedFill = value > 250
                let offset = (y * width + x) * 4
                let isCoral = pixels[offset] > 220 && pixels[offset + 1] < 100 && pixels[offset + 2] < 100
                if isCoral != expectedFill { mismatches += 1 }
            }
        }
        #expect(mismatches == 0, "Body fill must match the original mask orientation")
    }
}
