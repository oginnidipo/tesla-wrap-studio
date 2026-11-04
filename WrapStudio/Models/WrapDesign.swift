import Foundation
import PencilKit

struct WrapDesign: Codable, Equatable {
    var version = 1
    var drawingData: Data
    var stickers: [CanvasSticker] = []
    var fillHex: String?

    init(drawing: PKDrawing = PKDrawing(), stickers: [CanvasSticker] = [], fillHex: String? = nil) {
        drawingData = drawing.dataRepresentation()
        self.stickers = stickers
        self.fillHex = fillHex
    }
}
