import Testing
import PencilKit
@testable import Tesla_Car_Wrap

@MainActor struct EditorSessionTests {
    @Test func undoRedoIncludesFillStickersAndPaint() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = EditorSession(car: .m3, repository: DesignRepository(documentsURL: directory))
        session.setFill("F14B35")
        session.addSticker(named: "example.png")
        session.beginEdit()
        session.updateDrawing(TestArtwork.drawing())
        session.finishEdit()
        session.clear()
        #expect(session.hasArtwork == false)
        session.undo()
        #expect(session.drawing.strokes.count == 1)
        #expect(session.stickers.count == 1)
        #expect(session.fillHex == "F14B35")
        session.undo()
        #expect(session.drawing.strokes.isEmpty)
        session.undo()
        #expect(session.stickers.isEmpty)
        session.undo()
        #expect(session.hasArtwork == false)
        #expect(session.canUndo == false)
        session.redo()
        #expect(session.fillHex == "F14B35")
        session.setFill("558BC7")
        #expect(session.canRedo == false)
        session.persistNow()
    }

    @Test func stickerOnlyDesignCanBeExportedAndRestored() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = DesignRepository(documentsURL: directory)
        let session = EditorSession(car: .ct, repository: repository)
        session.addSticker(named: "example.png")
        let sticker = try #require(session.stickers.first)
        session.moveSticker(sticker.id, by: CGSize(width: -5000, height: 5000))
        session.resizeSticker(sticker.id, magnification: 1.5)
        #expect(session.hasArtwork)
        #expect(session.stickers[0].x == 0)
        #expect(session.stickers[0].y == 768)
        #expect(session.stickers[0].side == 390)
        session.persistNow()
        let restored = EditorSession(car: .ct, repository: repository)
        #expect(restored.stickers == session.stickers)
        #expect(restored.hasArtwork)
        let otherCar = EditorSession(car: .my, repository: repository)
        #expect(otherCar.hasArtwork == false)
    }

    @Test func drawingPersistsWithoutAnyDisplayGeometry() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = DesignRepository(documentsURL: directory)
        let session = EditorSession(car: .my, repository: repository)
        session.beginEdit()
        session.updateDrawing(TestArtwork.drawing())
        session.finishEdit()
        session.persistNow()
        let restored = EditorSession(car: .my, repository: repository)
        #expect(restored.drawing.bounds == session.drawing.bounds)
        #expect(restored.saveStatus == "All changes saved")
    }

    @Test func corruptDraftIsPreserved() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = DesignRepository(documentsURL: directory)
        try FileManager.default.createDirectory(at: repository.autosaveDirectory, withIntermediateDirectories: true)
        let original = Data("broken draft".utf8)
        try original.write(to: repository.url(for: .m3))
        let session = EditorSession(car: .m3, repository: repository)
        session.setFill("F14B35")
        session.persistNow()
        #expect(session.errorMessage != nil)
        #expect(try Data(contentsOf: repository.url(for: .m3)) == original)
    }
}
