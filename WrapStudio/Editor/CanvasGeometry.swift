import CoreGraphics
import PencilKit

enum CanvasGeometry {
    static func fitRect(template: CGSize, in size: CGSize) -> CGRect {
        guard template.width > 0, template.height > 0, size.width > 0, size.height > 0 else { return .zero }
        let scale = min(size.width / template.width, size.height / template.height)
        let fitted = CGSize(width: template.width * scale, height: template.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }

    /// PKCanvasView drawings use its local origin; the surrounding letterbox is never part of a stroke.
    static func drawing(_ drawing: PKDrawing, scaledBy scale: CGFloat) -> PKDrawing {
        drawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
    }

    static func clampedCenter(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(value, 0), limit)
    }

    static func stickerSide(_ original: CGFloat, magnification: CGFloat) -> CGFloat {
        min(1024, max(40, original * magnification))
    }

    /// An equivalent angle in (-π, π].
    static func normalizedAngle(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if value <= -.pi { value += 2 * .pi }
        if value > .pi { value -= 2 * .pi }
        return value
    }
}
