import PencilKit
import UIKit

@MainActor final class TemplateHostView: UIView, UIPencilInteractionDelegate {
    private struct BackgroundKey: Equatable {
        let fillHex: String?
        let panelFills: [PanelFill]
    }

    let canvas = DrawingCanvasView()
    let session: EditorSession
    private(set) var displayScale: CGFloat = 0
    private(set) var isApplyingDrawing = false
    private(set) var appliedDrawingData: Data?
    private let templateView = UIImageView()
    private var renderedBackground: BackgroundKey?
    private var appliedRevision = -1

    init(session: EditorSession) {
        self.session = session
        super.init(frame: .zero)
        backgroundColor = .white
        templateView.contentMode = .scaleToFill
        templateView.isUserInteractionEnabled = false
        addSubview(templateView)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = false
        // PKCanvasView is a scroll view; keep insets and offset fixed so the artwork never
        // slides out of view when the canvas is resized (rotation, keyboard, split view).
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.overrideUserInterfaceStyle = .light
        canvas.tool = session.pencilTool(displayScale: 1)
        canvas.accessibilityLabel = "\(session.car.name) paint canvas"
        addSubview(canvas)
        let pencil = UIPencilInteraction()
        pencil.delegate = self
        addInteraction(pencil)
        refreshArtwork()
    }

    required init?(coder: NSCoder) { nil }

    func refreshArtwork() {
        let key = BackgroundKey(fillHex: session.fillHex, panelFills: session.panelFills)
        guard key != renderedBackground else { return }
        templateView.image = try? WrapRenderer.background(car: session.car, fillHex: key.fillHex, panelFills: key.panelFills)
        renderedBackground = key
    }

    /// The bucket tool takes taps instead of strokes.
    func setDrawingEnabled(_ enabled: Bool) {
        canvas.drawingGestureRecognizer.isEnabled = enabled
        canvas.isUserInteractionEnabled = enabled
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let fit = CanvasGeometry.fitRect(template: session.car.templateSize, in: bounds.size)
        guard fit.width > 0 else { return }
        templateView.frame = fit
        canvas.frame = fit
        canvas.contentInset = .zero
        canvas.contentSize = fit.size
        canvas.contentOffset = .zero
        let scale = fit.width / session.car.templateSize.width
        if scale != displayScale || appliedRevision != session.drawingRevision {
            isApplyingDrawing = true
            canvas.drawing = CanvasGeometry.drawing(session.drawing, scaledBy: scale)
            appliedDrawingData = canvas.drawing.dataRepresentation()
            isApplyingDrawing = false
            displayScale = scale
            appliedRevision = session.drawingRevision
        }
    }

    // MARK: Apple Pencil double-tap and squeeze

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        handlePencilAction()
    }

    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        handlePencilAction()
    }

    /// Honors the system setting; the palette and other actions are left to the system.
    private func handlePencilAction() {
        let action = UIPencilInteraction.preferredTapAction
        guard action == .switchEraser || action == .switchPrevious else { return }
        session.toggleEraser()
    }
}
