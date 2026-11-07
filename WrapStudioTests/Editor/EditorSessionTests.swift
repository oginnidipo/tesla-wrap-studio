import PencilKit
import Testing
@testable import Tesla_Car_Wrap

@MainActor struct EditorSessionTests {
    /// Points inside Model 3 (2017–2023) panels, in template pixels.
    private let hood = CGPoint(x: 512, y: 260)
    private let leftFrontDoor = CGPoint(x: 140, y: 480)

    @Test func undoRedoCoversPaintFillsAndStickers() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .m3, store: store)
        session.setFill("F14B35")
        session.addSticker(named: "example.png")
        session.beginEdit()
        session.updateDrawing(TestArtwork.drawing())
        session.finishEdit()
        session.selectColor("558BC7")
        #expect(session.fillPanel(at: hood))
        session.clear()
        #expect(session.hasArtwork == false)
        session.undo()
        #expect(session.panelFills.count == 1)
        #expect(session.drawing.strokes.count == 1)
        session.undo()
        #expect(session.panelFills.isEmpty)
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
    }

    @Test func bucketFillsOnePanelAndTogglesItOff() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .m3, store: store)
        session.selectColor("5AAB88")
        #expect(session.fillPanel(at: hood))
        #expect(session.panelFills == [PanelFill(x: hood.x, y: hood.y, hex: "5AAB88")])
        session.selectColor("9675C7")
        #expect(session.fillPanel(at: hood))
        #expect(session.panelFills.map(\.hex) == ["9675C7"], "Refilling a panel replaces its colour")
        #expect(session.fillPanel(at: hood))
        #expect(session.panelFills.isEmpty, "Tapping with the same colour clears it")
        #expect(session.fillPanel(at: CGPoint(x: 512, y: 560)) == false, "The glass roof is not paintable")
        #expect(session.notice != nil)
    }

    @Test func mirroredBucketFillsBothSides() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .m3, store: store)
        session.isMirroring = true
        session.selectColor("F6D968")
        #expect(session.fillPanel(at: leftFrontDoor))
        #expect(session.panelFills.count == 2)
        let map = try #require(PanelMap.forCar(.m3))
        let panels = Set(session.panelFills.compactMap { map.panel(at: $0.point) })
        #expect(panels.count == 2)
        #expect(session.panelFills.allSatisfy { map.panel(at: $0.point, tolerance: 0) != nil },
                "Stored points lie inside their panels")
        session.undo()
        #expect(session.panelFills.isEmpty)
    }

    @Test func paintWholeBodyReplacesPanelColours() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .my, store: store)
        session.selectColor("F14B35")
        session.fillPanel(at: CGPoint(x: 512, y: 250))
        session.selectColor("0B0B0D")
        session.fillBody()
        #expect(session.fillHex == "0B0B0D")
        #expect(session.panelFills.isEmpty)
        session.clearFills()
        #expect(session.hasFills == false)
        session.undo()
        #expect(session.fillHex == "0B0B0D")
    }

    @Test func mirroredStrokesLandOnTheOtherSide() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .m3, store: store)
        session.beginEdit()
        session.updateDrawing(TestArtwork.drawing(from: CGPoint(x: 100, y: 200), to: CGPoint(x: 300, y: 400)))
        session.mirrorStrokes(from: 0)
        session.finishEdit()
        #expect(session.drawing.strokes.count == 2)
        let original = session.drawing.strokes[0].renderBounds
        let mirrored = session.drawing.strokes[1].renderBounds
        #expect(abs(mirrored.midX - (1026 - original.midX)) < 1)
        #expect(abs(mirrored.midY - original.midY) < 1)
        session.undo()
        #expect(session.drawing.strokes.isEmpty, "A stroke and its mirror are one history step")
    }

    @Test func cybertruckMirrorsTopToBottom() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .ct, store: store)
        session.updateDrawing(TestArtwork.drawing(from: CGPoint(x: 400, y: 100), to: CGPoint(x: 600, y: 140)))
        session.mirrorStrokes(from: 0)
        let original = session.drawing.strokes[0].renderBounds
        let mirrored = session.drawing.strokes[1].renderBounds
        #expect(abs(mirrored.midY - (767 - original.midY)) < 1)
        #expect(abs(mirrored.midX - original.midX) < 1)
    }

    @Test func stickersStartOnABodyPanelAndTransformAsOneStep() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .ct, store: store)
        session.addSticker(named: "example.png")
        let sticker = try #require(session.stickers.first)
        let map = try #require(PanelMap.forCar(.ct))
        #expect(map.panel(at: CGPoint(x: sticker.x, y: sticker.y), tolerance: 0) != nil)
        #expect(session.selectedStickerID == sticker.id)

        session.transformSticker(sticker.id, translation: CGSize(width: -5000, height: 5000), magnification: 1.5, rotation: .pi / 4)
        #expect(session.stickers[0].x == 0)
        #expect(session.stickers[0].y == 768)
        #expect(session.stickers[0].side == sticker.side * 1.5)
        #expect(abs(session.stickers[0].rotation - .pi / 4) < 1e-9)
        session.undo()
        #expect(session.stickers[0] == sticker)
    }

    @Test func stickerFlipDuplicateFrontAndMirrorCopy() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .m3, store: store)
        session.addSticker(named: "a.png")
        session.addSticker(named: "b.png")
        let first = session.stickers[0]
        session.rotateSticker(first.id, by: 0.3)
        session.flipSticker(first.id)
        #expect(session.stickers[0].isFlipped)
        #expect(abs(session.stickers[0].rotation + 0.3) < 1e-9)

        session.bringStickerToFront(first.id)
        #expect(session.stickers.last?.id == first.id)

        session.duplicateSticker(first.id)
        #expect(session.stickers.count == 3)
        #expect(session.stickers.last?.fileName == "a.png")
        #expect(session.selectedStickerID == session.stickers.last?.id)

        let source = try #require(session.stickers.first { $0.id == first.id })
        session.mirrorCopySticker(first.id)
        let mirror = try #require(session.stickers.last)
        #expect(abs(mirror.x - (1026 - source.x)) < 0.001)
        #expect(mirror.y == source.y)
        #expect(mirror.isFlipped == !source.isFlipped)
        #expect(abs(mirror.rotation + source.rotation) < 1e-9)

        session.deleteSticker(mirror.id)
        #expect(session.stickers.count == 3)
        #expect(session.selectedStickerID == nil)
    }

    @Test func designPersistsAndRenames() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .myRefresh, store: store)
        var reported: [DesignRecord] = []
        session.onRecordChange = { reported.append($0) }
        session.beginEdit()
        session.updateDrawing(TestArtwork.drawing())
        session.finishEdit()
        session.selectColor("558BC7")
        session.fillPanel(at: CGPoint(x: 512, y: 250))
        session.rename(to: "Ocean Drive")
        session.close()
        #expect(session.saveState == .saved)
        #expect(reported.last?.name == "Ocean Drive")
        #expect(FileManager.default.fileExists(atPath: store.thumbnailURL(for: session.record.id).path))

        let restored = EditorSession(record: try store.record(session.record.id), store: store)
        #expect(restored.record.name == "Ocean Drive")
        #expect(restored.drawing.bounds == session.drawing.bounds)
        #expect(restored.panelFills == session.panelFills)
        #expect(restored.saveState == .saved)
    }

    @Test func eraserToggleReturnsToThePreviousTool() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let session = try EditorSession.new(car: .m3, store: store)
        session.tool = .marker
        session.toggleEraser()
        #expect(session.tool == .eraser)
        session.toggleEraser()
        #expect(session.tool == .marker)
        session.toggleEraser()
        session.selectColor("FFB547")
        #expect(session.tool == .marker, "Picking a colour while erasing goes back to painting")
    }
}
