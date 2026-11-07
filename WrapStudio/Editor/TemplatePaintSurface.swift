import PencilKit
import SwiftUI

struct TemplatePaintSurface: UIViewRepresentable {
    let session: EditorSession
    let revision: Int
    let tool: any PKTool
    let isDrawingEnabled: Bool
    let fillHex: String?
    let panelFills: [PanelFill]

    func makeUIView(context: Context) -> TemplateHostView {
        let view = TemplateHostView(session: session)
        view.canvas.delegate = context.coordinator
        context.coordinator.host = view
        return view
    }

    func updateUIView(_ view: TemplateHostView, context: Context) {
        view.canvas.tool = tool
        view.setDrawingEnabled(isDrawingEnabled)
        view.refreshArtwork()
        view.setNeedsLayout()
    }

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    @MainActor final class Coordinator: NSObject, PKCanvasViewDelegate {
        let session: EditorSession
        weak var host: TemplateHostView?
        private var isUsingTool = false
        private var pendingCommit: Task<Void, Never>?
        /// First stroke index of the gesture(s) still waiting to be mirrored.
        private var mirrorFrom: Int?

        init(session: EditorSession) { self.session = session }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            pendingCommit?.cancel()
            isUsingTool = true
            session.selectedStickerID = nil
            if session.isMirroring, session.tool.drawsInk, mirrorFrom == nil {
                mirrorFrom = session.drawing.strokes.count
            }
            session.beginEdit()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            synchronizeDrawing(canvasView)
            if !isUsingTool { commitAfterDrawingSettles(canvasView) }
        }

        private func synchronizeDrawing(_ canvasView: PKCanvasView) {
            guard let host, !host.isApplyingDrawing, host.displayScale > 0,
                  canvasView.drawing.dataRepresentation() != host.appliedDrawingData else { return }
            session.beginEdit()
            session.updateDrawing(CanvasGeometry.drawing(canvasView.drawing, scaledBy: 1 / host.displayScale))
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isUsingTool = false
            synchronizeDrawing(canvasView)
            commitAfterDrawingSettles(canvasView)
        }

        private func commitAfterDrawingSettles(_ canvasView: PKCanvasView) {
            // PencilKit can deliver its final drawing-change callback after the tool-end
            // callback. Commit one history entry after those callbacks have settled.
            pendingCommit?.cancel()
            pendingCommit = Task { [weak self, weak canvasView] in
                do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
                guard let self, let canvasView else { return }
                self.synchronizeDrawing(canvasView)
                if let start = self.mirrorFrom {
                    self.mirrorFrom = nil
                    self.session.mirrorStrokes(from: start)
                }
                self.session.finishEdit()
            }
        }
    }
}
