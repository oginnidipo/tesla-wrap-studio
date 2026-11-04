import Foundation
import PencilKit

struct DesignRepository {
    let documentsURL: URL

    init(documentsURL: URL = URL.documentsDirectory) {
        self.documentsURL = documentsURL
    }

    var autosaveDirectory: URL {
        documentsURL.appending(path: "Wrap Studio Autosaves", directoryHint: .isDirectory)
    }

    func url(for car: Car) -> URL {
        autosaveDirectory.appending(path: "\(car.rawValue).wrap.json")
    }

    func load(car: Car) throws -> (design: WrapDesign, isLegacy: Bool) {
        if FileManager.default.fileExists(atPath: url(for: car).path) {
            let design = try JSONDecoder().decode(WrapDesign.self, from: Data(contentsOf: url(for: car)))
            guard design.version == 1 else { throw StudioError.unsupportedDesign }
            _ = try PKDrawing(data: design.drawingData)
            return (design, false)
        }

        // Keep the prototype's files untouched. It did not record canvas size, so migration
        // uses the first displayed canvas as its best available reference.
        let drawingURL = autosaveDirectory.appending(path: "\(car.legacyFileName).wrapdata")
        let stickersURL = autosaveDirectory.appending(path: "\(car.legacyFileName).stickers")
        let hasDrawing = FileManager.default.fileExists(atPath: drawingURL.path)
        let hasStickers = FileManager.default.fileExists(atPath: stickersURL.path)
        let drawing = hasDrawing ? try PKDrawing(data: Data(contentsOf: drawingURL)) : PKDrawing()
        let stickers = hasStickers
            ? try JSONDecoder().decode([CanvasSticker].self, from: Data(contentsOf: stickersURL)) : []
        return (WrapDesign(drawing: drawing, stickers: stickers), hasDrawing || hasStickers)
    }

    func save(_ design: WrapDesign, car: Car) throws {
        try FileManager.default.createDirectory(at: autosaveDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(design).write(to: url(for: car), options: .atomic)
    }
}
