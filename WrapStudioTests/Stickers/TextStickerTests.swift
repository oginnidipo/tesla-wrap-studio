import Testing
import UIKit
@testable import Tesla_Car_Wrap

@MainActor struct TextStickerTests {
    @Test(arguments: TextStickerStyle.allCases)
    func rendersLetteringOnATransparentBackground(style: TextStickerStyle) throws {
        let image = try TextStickerRenderer.image(text: "42", style: style, colorHex: "F14B35", outlined: true)
        #expect(image.size.width > 50 && image.size.height > 50)
        let pixels = try TestArtwork.pixels(image)
        #expect(pixels[3] == 0, "Corners stay transparent")
        #expect(pixels.enumerated().contains { $0.offset % 4 == 3 && $0.element == 255 }, "Glyphs are opaque")
    }

    @Test func outlineUsesAContrastingColour() throws {
        let image = try TextStickerRenderer.image(text: "I", style: .mono, colorHex: "0B0B0D", outlined: true)
        let pixels = try TestArtwork.pixels(image)
        let hasWhiteOutline = stride(from: 0, to: pixels.count, by: 4).contains {
            pixels[$0 + 3] == 255 && pixels[$0] > 240 && pixels[$0 + 1] > 240 && pixels[$0 + 2] > 240
        }
        #expect(hasWhiteOutline)
        let plain = try TestArtwork.pixels(TextStickerRenderer.image(text: "I", style: .mono, colorHex: "0B0B0D", outlined: false))
        #expect(!stride(from: 0, to: plain.count, by: 4).contains { plain[$0 + 3] == 255 && plain[$0] > 240 })
    }

    @Test func longTextIsCappedAtTemplateWidthAndBlankTextIsRefused() throws {
        let image = try TextStickerRenderer.image(text: "THE QUICK BROWN FOX JUMPS", style: .sport, colorHex: "FFFFFF", outlined: true)
        #expect(image.size.width <= TextStickerRenderer.maximumWidth)
        #expect(throws: StudioError.self) {
            try TextStickerRenderer.image(text: "  \n ", style: .bold, colorHex: "FFFFFF", outlined: false)
        }
    }

    @Test func emojiFallsBackToTextDrawing() throws {
        let image = try TextStickerRenderer.image(text: "GO 🔥", style: .bold, colorHex: "F14B35", outlined: false)
        #expect(image.size.width > 100)
    }
}
