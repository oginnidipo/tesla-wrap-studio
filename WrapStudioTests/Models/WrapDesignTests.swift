import Foundation
import PencilKit
import Testing
@testable import Tesla_Car_Wrap

@MainActor struct WrapDesignTests {
    @Test func readsVersionOneDraftsWithoutNewFields() throws {
        let drawing = TestArtwork.drawing().dataRepresentation().base64EncodedString()
        let id = UUID()
        let json = """
        {"version":1,"drawingData":"\(drawing)","fillHex":"F14B35",
         "stickers":[{"id":"\(id.uuidString)","x":10,"y":20,"side":100,"fileName":"st-a.png"}]}
        """
        let design = try JSONDecoder().decode(WrapDesign.self, from: Data(json.utf8))
        #expect(design.version == 1)
        #expect(design.panelFills.isEmpty)
        #expect(design.fillHex == "F14B35")
        #expect(design.stickers == [CanvasSticker(id: id, x: 10, y: 20, side: 100, fileName: "st-a.png")])
        #expect(design.stickers[0].rotation == 0)
        #expect(design.stickers[0].isFlipped == false)
        #expect(design.hasArtwork)
    }

    @Test func roundTripsPanelFillsAndStickerTransforms() throws {
        let sticker = CanvasSticker(id: UUID(), x: 1, y: 2, side: 300, fileName: "tx-a.png", rotation: 1.25, isFlipped: true)
        let design = WrapDesign(stickers: [sticker], panelFills: [PanelFill(x: 512, y: 260, hex: "558BC7")])
        let decoded = try JSONDecoder().decode(WrapDesign.self, from: JSONEncoder().encode(design))
        #expect(decoded == design)
        #expect(decoded.version == WrapDesign.currentVersion)
    }

    @Test func emptyDesignHasNoArtwork() {
        #expect(WrapDesign().hasArtwork == false)
        #expect(WrapDesign(panelFills: [PanelFill(x: 0, y: 0, hex: "FFFFFF")]).hasArtwork)
    }

    @Test func namesAreTrimmedCollapsedAndCapped() {
        #expect(DesignRecord.cleanedName("  Midnight \n  Racer  ") == "Midnight Racer")
        #expect(DesignRecord.cleanedName(String(repeating: "a", count: 80)).count == DesignRecord.maximumNameLength)
    }

    @Test func colorsRoundTripThroughHex() {
        for swatch in StudioStyle.swatches {
            #expect(StudioStyle.hex(from: StudioStyle.uiColor(hex: swatch.hex)) == swatch.hex)
        }
        #expect(StudioStyle.prefersLightContent(onHex: "0B0B0D"))
        #expect(StudioStyle.prefersLightContent(onHex: "FFFFFF") == false)
    }
}
