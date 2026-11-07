import Combine
import PencilKit
import SwiftUI

/// The state of one open design: artwork, tools, a single undo history for every kind of
/// edit, and debounced autosave. ObservableObject keeps the editor available on iPadOS 16.
@MainActor final class EditorSession: ObservableObject {
    enum SaveState: Equatable {
        case saved, saving, failed, unavailable

        var title: String {
            switch self {
            case .saved: "All changes saved"
            case .saving: "Saving…"
            case .failed: "Save failed"
            case .unavailable: "Draft could not be loaded"
            }
        }
        var symbol: String {
            switch self {
            case .saved: "checkmark.circle"
            case .saving: "arrow.triangle.2.circlepath"
            case .failed, .unavailable: "exclamationmark.triangle"
            }
        }
    }

    static let widthRange: ClosedRange<CGFloat> = 2...80
    static let defaultStickerSide: CGFloat = 260
    private static let historyLimit = 60
    private static let recentColorsKey = "recentColors"

    let stickerLibrary: StickerLibrary
    @Published private(set) var record: DesignRecord
    @Published private(set) var drawing = PKDrawing()
    @Published private(set) var stickers: [CanvasSticker] = []
    @Published private(set) var fillHex: String?
    @Published private(set) var panelFills: [PanelFill] = []
    @Published private(set) var drawingRevision = 0
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var saveState = SaveState.saved
    @Published private(set) var recentColors: [String]
    @Published var selectedStickerID: UUID?
    @Published var tool: PaintTool = .pen {
        didSet { if oldValue != .eraser, oldValue != tool { toolBeforeEraser = oldValue == .fill ? .pen : oldValue } }
    }
    @Published var colorHex = StudioStyle.defaultInkHex
    @Published var inkWidth: CGFloat = 14
    @Published var isMirroring = false
    @Published var errorMessage: String?
    /// A short, self-dismissing message about the last action.
    @Published var notice: String?

    /// Called after the design is saved or renamed, and when a new thumbnail is written.
    var onRecordChange: ((DesignRecord) -> Void)?
    var onThumbnailChange: ((UUID, Data) -> Void)?

    var car: Car { record.car }

    private let store: DesignStore
    private var undoHistory: [WrapDesign] = []
    private var redoHistory: [WrapDesign] = []
    private var editStart: WrapDesign?
    private var saveTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var needsLegacyMigration = false
    private var canPersist = true
    private var hasUnsavedChanges = false
    private var thumbnailIsStale = false
    private var toolBeforeEraser = PaintTool.pen

    init(record: DesignRecord, store: DesignStore = DesignStore()) {
        self.record = record
        self.store = store
        stickerLibrary = StickerLibrary(documentsURL: store.documentsURL)
        recentColors = UserDefaults.standard.stringArray(forKey: Self.recentColorsKey) ?? []
        do {
            let design = try store.loadDesign(record.id)
            drawing = try PKDrawing(data: design.drawingData)
            stickers = design.stickers
            fillHex = design.fillHex
            panelFills = design.panelFills
            needsLegacyMigration = record.needsCanvasMigration
            thumbnailIsStale = !store.thumbnailIsCurrent(for: record)
        } catch {
            canPersist = false
            saveState = .unavailable
            errorMessage = "This design could not be opened. Its original file has been kept and new edits will not overwrite it. \(error.localizedDescription)"
        }
    }

    /// Creates a new, empty design for `car` and opens it.
    static func new(car: Car, store: DesignStore = DesignStore()) throws -> EditorSession {
        EditorSession(record: try store.create(car: car), store: store)
    }

    var hasArtwork: Bool { !drawing.strokes.isEmpty || !stickers.isEmpty || fillHex != nil || !panelFills.isEmpty }
    var hasFills: Bool { fillHex != nil || !panelFills.isEmpty }
    var snapshot: WrapDesign { WrapDesign(drawing: drawing, stickers: stickers, fillHex: fillHex, panelFills: panelFills) }
    var selectedSticker: CanvasSticker? { stickers.first { $0.id == selectedStickerID } }

    func pencilTool(displayScale: CGFloat) -> any PKTool {
        let width = inkWidth * max(displayScale, 0.01)
        switch tool {
        case .eraser:
            if #available(iOS 16.4, *) { return PKEraserTool(.bitmap, width: max(width, 4)) }
            return PKEraserTool(.bitmap)
        case .marker:
            return PKInkingTool(.marker, color: StudioStyle.uiColor(hex: colorHex), width: width)
        case .pen, .fill:
            return PKInkingTool(.pen, color: StudioStyle.uiColor(hex: colorHex), width: width)
        }
    }

    // MARK: Tools and colour

    func selectColor(_ hex: String, remember: Bool = false) {
        colorHex = hex
        if tool == .eraser { tool = toolBeforeEraser }
        guard remember, !StudioStyle.palette.contains(hex) else { return }
        recentColors = Array(([hex] + recentColors.filter { $0 != hex }).prefix(6))
        UserDefaults.standard.set(recentColors, forKey: Self.recentColorsKey)
    }

    /// Apple Pencil double-tap and the eraser shortcut.
    func toggleEraser() {
        tool = tool == .eraser ? toolBeforeEraser : .eraser
    }

    func showNotice(_ message: String) {
        notice = message
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2.2)) } catch { return }
            self?.notice = nil
        }
    }

    // MARK: Edits

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
            if undoHistory.count > Self.historyLimit { undoHistory.removeFirst() }
            redoHistory.removeAll()
        }
        editStart = nil
        updateHistoryStatus()
        scheduleSave()
    }

    /// Adds mirrored copies of the strokes from `index` onwards (the strokes of one gesture).
    func mirrorStrokes(from index: Int) {
        guard index >= 0, index < drawing.strokes.count else { return }
        let mirror = car.mirrorAxis.transform
        var updated = drawing
        updated.strokes.append(contentsOf: drawing.strokes[index...].map { stroke in
            var copy = stroke
            copy.transform = stroke.transform.concatenating(mirror)
            return copy
        })
        drawing = updated
        drawingRevision += 1
        scheduleSave()
    }

    /// Body colour beneath everything else. `nil` shows the bare template.
    func setFill(_ hex: String?) {
        guard hex != fillHex else { return }
        beginEdit()
        fillHex = hex
        finishEdit()
    }

    /// Paints every panel in the current colour, replacing individual panel colours.
    func fillBody() {
        guard fillHex != colorHex || !panelFills.isEmpty else { return }
        beginEdit()
        fillHex = colorHex
        panelFills = []
        finishEdit()
    }

    func clearFills() {
        guard hasFills else { return }
        beginEdit()
        fillHex = nil
        panelFills = []
        finishEdit()
    }

    /// Bucket tool: colours the panel under `point` (template pixels), and its mirror image
    /// when mirroring. Tapping a panel that already has the current colour clears it.
    @discardableResult
    func fillPanel(at point: CGPoint) -> Bool {
        guard let map = PanelMap.forCar(car), let panel = map.panel(at: point) else {
            showNotice("Tap inside a body panel to fill it.")
            return false
        }
        var targets = [(panel: panel, point: map.anchor(for: panel, near: point))]
        if isMirroring {
            let mirrored = car.mirrorAxis.mirror(point)
            if let other = map.panel(at: mirrored, tolerance: 12), other != panel {
                targets.append((other, map.anchor(for: other, near: mirrored)))
            }
        }
        let current = map.resolvedColors(for: panelFills)
        let clearing = targets.allSatisfy { current[$0.panel] == colorHex }
        let targetPanels = Set(targets.map(\.panel))
        beginEdit()
        // Also drops fills that no longer resolve to any panel.
        panelFills.removeAll { fill in map.panel(at: fill.point).map { targetPanels.contains($0) } ?? true }
        if !clearing {
            panelFills += targets.map { PanelFill(x: $0.point.x, y: $0.point.y, hex: colorHex) }
        }
        finishEdit()
        return true
    }

    // MARK: Stickers

    /// New stickers start on the largest body panel (the template's centre is often glass),
    /// sized to fit within it.
    func addSticker(named name: String, side: CGFloat = EditorSession.defaultStickerSide) {
        var center = CGPoint(x: car.templateSize.width / 2, y: car.templateSize.height / 2)
        var fitted = side
        if let home = PanelMap.forCar(car)?.stickerHome {
            center = home.center
            fitted = min(side, max(home.size.width, home.size.height) * 0.9)
        }
        beginEdit()
        let sticker = CanvasSticker(id: UUID(), x: center.x, y: center.y,
                                    side: CanvasGeometry.stickerSide(fitted, magnification: 1), fileName: name)
        stickers.append(sticker)
        selectedStickerID = sticker.id
        finishEdit()
    }

    func moveSticker(_ id: UUID, by offset: CGSize) {
        transformSticker(id, translation: offset)
    }

    func resizeSticker(_ id: UUID, magnification: CGFloat) {
        transformSticker(id, magnification: magnification)
    }

    func rotateSticker(_ id: UUID, by angle: Double) {
        transformSticker(id, rotation: angle)
    }

    /// One history entry for a combined drag, pinch and twist.
    func transformSticker(_ id: UUID, translation: CGSize = .zero, magnification: CGFloat = 1, rotation: Double = 0) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        beginEdit()
        stickers[index].x = CanvasGeometry.clampedCenter(stickers[index].x + translation.width, limit: car.templateSize.width)
        stickers[index].y = CanvasGeometry.clampedCenter(stickers[index].y + translation.height, limit: car.templateSize.height)
        stickers[index].side = CanvasGeometry.stickerSide(stickers[index].side, magnification: magnification)
        stickers[index].rotation = CanvasGeometry.normalizedAngle(stickers[index].rotation + rotation)
        finishEdit()
    }

    func flipSticker(_ id: UUID) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        beginEdit()
        stickers[index].isFlipped.toggle()
        stickers[index].rotation = CanvasGeometry.normalizedAngle(-stickers[index].rotation)
        finishEdit()
    }

    /// Places a mirror image on the other side of the vehicle and selects it.
    func mirrorCopySticker(_ id: UUID) {
        guard let original = stickers.first(where: { $0.id == id }) else { return }
        let axis = car.mirrorAxis
        let position = axis.mirror(CGPoint(x: original.x, y: original.y))
        let copy = CanvasSticker(id: UUID(),
                                 x: CanvasGeometry.clampedCenter(position.x, limit: car.templateSize.width),
                                 y: CanvasGeometry.clampedCenter(position.y, limit: car.templateSize.height),
                                 side: original.side, fileName: original.fileName,
                                 rotation: CanvasGeometry.normalizedAngle(axis.mirroredRotation(original.rotation)),
                                 isFlipped: !original.isFlipped)
        beginEdit()
        stickers.append(copy)
        selectedStickerID = copy.id
        finishEdit()
    }

    func duplicateSticker(_ id: UUID) {
        guard var copy = stickers.first(where: { $0.id == id }) else { return }
        copy = CanvasSticker(id: UUID(),
                             x: CanvasGeometry.clampedCenter(copy.x + 40, limit: car.templateSize.width),
                             y: CanvasGeometry.clampedCenter(copy.y + 40, limit: car.templateSize.height),
                             side: copy.side, fileName: copy.fileName, rotation: copy.rotation, isFlipped: copy.isFlipped)
        beginEdit()
        stickers.append(copy)
        selectedStickerID = copy.id
        finishEdit()
    }

    func bringStickerToFront(_ id: UUID) {
        guard let index = stickers.firstIndex(where: { $0.id == id }), index != stickers.count - 1 else { return }
        beginEdit()
        stickers.append(stickers.remove(at: index))
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
        panelFills = []
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

    // MARK: Design

    func rename(to name: String) {
        do {
            record = try store.rename(record.id, to: name)
            onRecordChange?(record)
        } catch {
            errorMessage = "This design could not be renamed. \(error.localizedDescription)"
        }
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
        record.needsCanvasMigration = false
        drawingRevision += 1
        scheduleSave()
    }

    func persistNow() {
        saveTask?.cancel()
        guard canPersist, !needsLegacyMigration, hasUnsavedChanges else { return }
        do {
            record = try store.save(snapshot, for: record)
            hasUnsavedChanges = false
            saveState = .saved
            onRecordChange?(record)
        } catch {
            saveState = .failed
            errorMessage = "Your changes could not be saved. \(error.localizedDescription)"
        }
    }

    /// Saves and refreshes the gallery thumbnail. Called when leaving the editor or the app.
    func close() {
        persistNow()
        guard canPersist, !needsLegacyMigration, thumbnailIsStale else { return }
        do {
            let png = try WrapRenderer.thumbnail(car: car, design: snapshot, library: stickerLibrary)
            try store.saveThumbnail(png, for: record.id)
            thumbnailIsStale = false
            onThumbnailChange?(record.id, png)
        } catch {
            // The gallery falls back to rendering the design itself.
        }
    }

    private func scheduleSave() {
        guard canPersist else { return }
        hasUnsavedChanges = true
        thumbnailIsStale = true
        saveState = .saving
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
        panelFills = design.panelFills
        if let selectedStickerID, !stickers.contains(where: { $0.id == selectedStickerID }) { self.selectedStickerID = nil }
        drawingRevision += 1
        updateHistoryStatus()
        scheduleSave()
    }

    private func updateHistoryStatus() {
        canUndo = !undoHistory.isEmpty
        canRedo = !redoHistory.isEmpty
    }
}
