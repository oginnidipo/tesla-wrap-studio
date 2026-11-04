import Testing
import PencilKit
@testable import Tesla_Car_Wrap

@MainActor struct DesignRepositoryTests {
    @Test func migratesLegacyDraftWithoutReplacingOriginals() throws {
        let directory = try TestArtwork.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = DesignRepository(documentsURL: directory)
        try FileManager.default.createDirectory(at: repository.autosaveDirectory, withIntermediateDirectories: true)
        let original = TestArtwork.drawing().dataRepresentation()
        let drawingURL = repository.autosaveDirectory.appending(path: "Cybertruck.wrapdata")
        try original.write(to: drawingURL)
        let stickers = [CanvasSticker(id: UUID(), x: 200, y: 350, side: 100, fileName: "old.png")]
        try JSONEncoder().encode(stickers).write(to: repository.autosaveDirectory.appending(path: "Cybertruck.stickers"))
        let session = EditorSession(car: .ct, repository: repository)
        session.migrateLegacyIfNeeded(in: CGSize(width: 400, height: 700))
        session.persistNow()
        #expect(abs(session.stickers[0].x - 512) < 0.01)
        #expect(abs(session.stickers[0].y - 384) < 0.01)
        #expect(session.stickers[0].side == 256)
        #expect(try Data(contentsOf: drawingURL) == original)
        let loaded = try repository.load(car: .ct)
        #expect(loaded.isLegacy == false)
        #expect(loaded.design.stickers == session.stickers)
    }
}
