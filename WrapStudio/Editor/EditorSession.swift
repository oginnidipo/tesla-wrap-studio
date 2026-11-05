import Combine
import PencilKit
import SwiftUI

/// ObservableObject keeps the editor available on the original iPadOS 16 devices.
@MainActor final class EditorSession: ObservableObject {
    let car: Car
    let stickerLibrary: StickerLibrary
    @Published private(set) var drawing = PKDrawing()
    @Published private(set) var stickers: [CanvasSticker] = []
    @Published private(set) var fillHex: String?
    @Published private(set) var drawingRevision = 0
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var saveStatus = "All changes saved"
    @Published var selectedStickerID: UUID?
    @Published var tool: PaintTool = .pen
    @Published var inkColor: Color = .init(red: 0.94, green: 0.29, blue: 0.20)
    @Published var inkWidth: CGFloat = 10
    @Published var errorMessage: String?

    private let repository: DesignRepository
    private var undoHistory: [WrapDesign] = []
    private var redoHistory: [WrapDesign] = []
    private var editStart: WrapDesign?
    private var saveTask: Task<Void, Never>?
    private var needsLegacyMigration = false
    private var canPersist = true
    private var hasUnsavedChanges = false

    init(car: Car, repository: DesignRepository = DesignRepository()) {
        self.car = car
        self.repository = repository
        stickerLibrary = StickerLibrary(documentsURL: repository.documentsURL)
        do {
            let loaded = try repository.load(car: car)
            drawing = try PKDrawing(data: loaded.design.drawingData)
            stickers = loaded.design.stickers
            fillHex = loaded.design.fillHex
            needsLegacyMigration = loaded.isLegacy
        } catch {
            canPersist = false
            saveStatus = "Draft could not be loaded"
            errorMessage = "Your saved draft could not be opened. Its original file has been kept. New edits will not overwrite it. \(error.localizedDescription)"
        }
    }

    var hasArtwork: Bool { !drawing.strokes.isEmpty || !stickers.isEmpty || fillHex != nil }
    var snapshot: WrapDesign { WrapDesign(drawing: drawing, stickers: stickers, fillHex: fillHex) }
    func pencilTool(displayScale: CGFloat) -> any PKTool {
        if tool == .eraser { return PKEraserTool(.bitmap) }
        return PKInkingTool(tool == .marker ? .marker : .pen, color: UIColor(inkColor), width: inkWidth * max(displayScale, 0.01))
    }

    func beginEdit() {
        if editStart == nil { editStart = snapshot }
    }

    func updateDrawing(_ newDrawing: PKDrawing) {
        drawing = newDrawing
        scheduleSave()
    }

    func finishEdit() {
        if let previous = editStart, previous != snapshot {
            undoHistory.append(previous)
            if undoHistory.count > 40 { undoHistory.removeFirst() }
            redoHistory.removeAll()
        }
        editStart = nil
        updateHistoryStatus()
        scheduleSave()
    }

    func setFill(_ hex: String?) {
        guard hex != fillHex else { return }
        beginEdit()
        fillHex = hex
        finishEdit()
    }

    func addSticker(named name: String) {
        beginEdit()
        let sticker = CanvasSticker(id: UUID(), x: car.templateSize.width / 2,
                                    y: car.templateSize.height / 2, side: 260, fileName: name)
        stickers.append(sticker)
        selectedStickerID = sticker.id
        finishEdit()
    }

    func moveSticker(_ id: UUID, by offset: CGSize) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        beginEdit()
        stickers[index].x = CanvasGeometry.clampedCenter(stickers[index].x + offset.width, limit: car.templateSize.width)
        stickers[index].y = CanvasGeometry.clampedCenter(stickers[index].y + offset.height, limit: car.templateSize.height)
        finishEdit()
    }

    func resizeSticker(_ id: UUID, magnification: CGFloat) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        beginEdit()
        stickers[index].side = CanvasGeometry.stickerSide(stickers[index].side, magnification: magnification)
        finishEdit()
    }

    func deleteSticker(_ id: UUID) {
        beginEdit()
        stickers.removeAll { $0.id == id }
        selectedStickerID = nil
        finishEdit()
    }

    func clear() {
        beginEdit()
        drawing = PKDrawing()
        stickers = []
        fillHex = nil
        selectedStickerID = nil
        drawingRevision += 1
        finishEdit()
    }

    func undo() {
        finishPendingEdit()
        guard let previous = undoHistory.popLast() else { return }
        redoHistory.append(snapshot)
        restore(previous)
    }

    func redo() {
        finishPendingEdit()
        guard let next = redoHistory.popLast() else { return }
        undoHistory.append(snapshot)
        restore(next)
    }

    func migrateLegacyIfNeeded(in size: CGSize) {
        guard needsLegacyMigration else { return }
        let rect = CanvasGeometry.fitRect(template: car.templateSize, in: size)
        guard rect.width > 0 else { return }
        let scale = car.templateSize.width / rect.width
        drawing = CanvasGeometry.drawing(drawing, scaledBy: scale)
        stickers = stickers.map { sticker in
            var migrated = sticker
            migrated.x = (sticker.x - rect.minX) * scale
            migrated.y = (sticker.y - rect.minY) * scale
            migrated.side *= scale
            return migrated
        }
        needsLegacyMigration = false
        drawingRevision += 1
        scheduleSave()
    }

    func persistNow() {
        saveTask?.cancel()
        guard canPersist, !needsLegacyMigration, hasUnsavedChanges else { return }
        do {
            try repository.save(snapshot, car: car)
            hasUnsavedChanges = false
            saveStatus = "All changes saved"
        } catch {
            saveStatus = "Save failed"
            errorMessage = "Your changes could not be saved. \(error.localizedDescription)"
        }
    }

    private func scheduleSave() {
        guard canPersist else { return }
        hasUnsavedChanges = true
        saveStatus = "Saving…"
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            self?.persistNow()
        }
    }

    private func finishPendingEdit() {
        if editStart != nil { finishEdit() }
    }

    private func restore(_ design: WrapDesign) {
        guard let restored = try? PKDrawing(data: design.drawingData) else { return }
        drawing = restored
        stickers = design.stickers
        fillHex = design.fillHex
        selectedStickerID = nil
        drawingRevision += 1
        updateHistoryStatus()
        scheduleSave()
    }

    private func updateHistoryStatus() {
        canUndo = !undoHistory.isEmpty
        canRedo = !redoHistory.isEmpty
    }
}
