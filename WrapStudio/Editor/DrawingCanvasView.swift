import PencilKit

final class DrawingCanvasView: PKCanvasView {
    // The editor owns one history for paint, fill, and stickers.
    override var undoManager: UndoManager? { nil }
}
