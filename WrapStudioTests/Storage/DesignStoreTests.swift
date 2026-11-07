import Foundation
import PencilKit
import Testing
@testable import Tesla_Car_Wrap

@MainActor struct DesignStoreTests {
    @Test func createsUniquelyNamedDesignsNewestFirst() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let first = try store.create(car: .m3, date: Date(timeIntervalSince1970: 100))
        let second = try store.create(car: .m3, date: Date(timeIntervalSince1970: 200))
        let truck = try store.create(car: .ct, name: "  Night   Rider ", date: Date(timeIntervalSince1970: 300))
        #expect(first.name == "Model 3 Wrap")
        #expect(second.name == "Model 3 Wrap 2")
        #expect(truck.name == "Night Rider")
        #expect(store.records().map(\.id) == [truck.id, second.id, first.id])
        #expect(try store.loadDesign(first.id).hasArtwork == false)
    }

    @Test func savingUpdatesModificationDateAndOrder() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let older = try store.create(car: .my, date: Date(timeIntervalSince1970: 100))
        _ = try store.create(car: .my, date: Date(timeIntervalSince1970: 200))
        let saved = try store.save(WrapDesign(fillHex: "F14B35"), for: older, at: Date(timeIntervalSince1970: 300))
        #expect(saved.modifiedAt == Date(timeIntervalSince1970: 300))
        #expect(store.records().first?.id == older.id)
        #expect(try store.loadDesign(older.id).fillHex == "F14B35")
        #expect(try store.record(older.id) == saved)
    }

    @Test func renamesWithoutCollidingAndIgnoresBlankNames() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let a = try store.create(car: .m3, name: "Stealth")
        let b = try store.create(car: .m3, name: "Sunset")
        #expect(try store.rename(b.id, to: "stealth").name == "stealth 2")
        #expect(try store.rename(a.id, to: "   ").name == "Stealth")
        #expect(try store.rename(a.id, to: "Stealth").name == "Stealth")
    }

    @Test func duplicatesArtworkByteForByteAndDeletesCleanly() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        let original = try store.create(car: .ct, name: "Camo", design: WrapDesign(drawing: TestArtwork.drawing(), fillHex: "5AAB88"))
        try store.saveThumbnail(Data([1, 2, 3]), for: original.id)
        let copy = try store.duplicate(original.id)
        #expect(copy.name == "Camo copy")
        #expect(copy.car == .ct)
        #expect(try Data(contentsOf: store.designURL(for: copy.id)) == Data(contentsOf: store.designURL(for: original.id)))
        #expect(try Data(contentsOf: store.thumbnailURL(for: copy.id)) == Data([1, 2, 3]))
        try store.delete(original.id)
        #expect(store.records().map(\.id) == [copy.id])
        #expect(!FileManager.default.fileExists(atPath: store.folder(for: original.id).path))
        #expect(throws: StudioError.self) { try store.record(original.id) }
    }

    @Test func thumbnailsOlderThanTheDesignAreStale() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        var record = try store.create(car: .m3)
        #expect(store.thumbnailIsCurrent(for: record) == false)
        try store.saveThumbnail(Data([0]), for: record.id)
        #expect(store.thumbnailIsCurrent(for: record))
        record = try store.save(WrapDesign(fillHex: "FFFFFF"), for: record, at: .now.addingTimeInterval(60))
        #expect(store.thumbnailIsCurrent(for: record) == false)
    }

    @Test func importsVersionOneAutosavesOnceAndKeepsOriginals() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        try FileManager.default.createDirectory(at: store.legacyAutosaveDirectory, withIntermediateDirectories: true)
        let painted = try JSONEncoder().encode(WrapDesign(drawing: TestArtwork.drawing(), fillHex: "F14B35"))
        let empty = try JSONEncoder().encode(WrapDesign())
        let m3URL = store.legacyAutosaveDirectory.appending(path: "m3.wrap.json")
        try painted.write(to: m3URL)
        try empty.write(to: store.legacyAutosaveDirectory.appending(path: "my.wrap.json"))

        let imported = try store.importLegacyAutosaves()
        #expect(imported.map(\.car) == [.m3])
        #expect(imported.first?.name == "Model 3 Wrap")
        #expect(try Data(contentsOf: store.designURL(for: imported[0].id)) == painted)
        #expect(try Data(contentsOf: m3URL) == painted)
        #expect(try store.loadDesign(imported[0].id).fillHex == "F14B35")
        #expect(try store.importLegacyAutosaves().isEmpty)
        #expect(store.records().count == 1)
    }

    @Test func importsUnreadableAutosaveSoTheEditorCanReportIt() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        try FileManager.default.createDirectory(at: store.legacyAutosaveDirectory, withIntermediateDirectories: true)
        let broken = Data("broken draft".utf8)
        try broken.write(to: store.legacyAutosaveDirectory.appending(path: "ct.wrap.json"))
        let record = try #require(try store.importLegacyAutosaves().first)
        let session = EditorSession(record: record, store: store)
        #expect(session.errorMessage != nil)
        #expect(session.saveState == .unavailable)
        session.setFill("F14B35")
        session.close()
        #expect(try Data(contentsOf: store.designURL(for: record.id)) == broken)
    }

    @Test func migratesPrototypeDraftToTemplateCoordinates() throws {
        let (store, cleanup) = try TestArtwork.store()
        defer { cleanup() }
        try FileManager.default.createDirectory(at: store.legacyAutosaveDirectory, withIntermediateDirectories: true)
        let original = TestArtwork.drawing().dataRepresentation()
        let drawingURL = store.legacyAutosaveDirectory.appending(path: "Cybertruck.wrapdata")
        try original.write(to: drawingURL)
        let stickers = [CanvasSticker(id: UUID(), x: 200, y: 350, side: 100, fileName: "old.png")]
        try JSONEncoder().encode(stickers).write(to: store.legacyAutosaveDirectory.appending(path: "Cybertruck.stickers"))

        let record = try #require(try store.importLegacyAutosaves().first)
        #expect(record.car == .ct)
        #expect(record.needsCanvasMigration)
        let session = EditorSession(record: record, store: store)
        session.migrateLegacyIfNeeded(in: CGSize(width: 400, height: 700))
        session.persistNow()
        #expect(abs(session.stickers[0].x - 512) < 0.01)
        #expect(abs(session.stickers[0].y - 384) < 0.01)
        #expect(session.stickers[0].side == 256)
        #expect(try Data(contentsOf: drawingURL) == original)
        #expect(try store.record(record.id).needsCanvasMigration == false)
        #expect(try store.loadDesign(record.id).stickers == session.stickers)
    }
}
