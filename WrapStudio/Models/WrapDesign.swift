import Foundation
import PencilKit

/// A colour applied to one body panel. The panel is identified by a point inside it, in
/// template pixels, so saved designs never depend on how panels happen to be numbered.
struct PanelFill: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var hex: String

    var point: CGPoint { CGPoint(x: x, y: y) }
}

struct WrapDesign: Codable, Equatable {
    /// 1: paint, stickers, body fill. 2: adds panel fills and sticker rotation/flip.
    static let currentVersion = 2

    var version = WrapDesign.currentVersion
    var drawingData: Data
    var stickers: [CanvasSticker] = []
    var fillHex: String?
    var panelFills: [PanelFill] = []

    init(drawing: PKDrawing = PKDrawing(), stickers: [CanvasSticker] = [], fillHex: String? = nil,
         panelFills: [PanelFill] = []) {
        drawingData = drawing.dataRepresentation()
        self.stickers = stickers
        self.fillHex = fillHex
        self.panelFills = panelFills
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        drawingData = try container.decode(Data.self, forKey: .drawingData)
        stickers = try container.decodeIfPresent([CanvasSticker].self, forKey: .stickers) ?? []
        fillHex = try container.decodeIfPresent(String.self, forKey: .fillHex)
        panelFills = try container.decodeIfPresent([PanelFill].self, forKey: .panelFills) ?? []
    }

    var hasArtwork: Bool {
        !stickers.isEmpty || fillHex != nil || !panelFills.isEmpty
            || !((try? PKDrawing(data: drawingData))?.strokes.isEmpty ?? true)
    }
}
