import PencilKit
import UIKit

@MainActor final class TemplateHostView: UIView {
    let canvas = DrawingCanvasView()
    let session: EditorSession
    private(set) var displayScale: CGFloat = 0
    private(set) var isApplyingDrawing = false
    private(set) var appliedDrawingData: Data?
    private let templateView = UIImageView()
    private var renderedFill: String?
    private var hasRenderedBackground = false
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
        canvas.overrideUserInterfaceStyle = .light
        canvas.tool = session.pencilTool(displayScale: 1)
        canvas.accessibilityLabel = "\(session.car.name) paint canvas"
        addSubview(canvas)
        refreshArtwork()
    }

    required init?(coder: NSCoder) { nil }

    func refreshArtwork() {
        guard !hasRenderedBackground || renderedFill != session.fillHex else { return }
        templateView.image = try? WrapRenderer.background(car: session.car, fillHex: session.fillHex)
        renderedFill = session.fillHex
        hasRenderedBackground = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let fit = CanvasGeometry.fitRect(template: session.car.templateSize, in: bounds.size)
        guard fit.width > 0 else { return }
        templateView.frame = fit
        canvas.frame = fit
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
}
