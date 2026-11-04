import CoreGraphics
import Testing
@testable import Tesla_Car_Wrap

struct CanvasGeometryTests {
    @Test func letterboxingDoesNotTranslateStrokes() {
        let rect = CanvasGeometry.fitRect(template: CGSize(width: 1024, height: 768), in: CGSize(width: 400, height: 700))
        #expect(rect == CGRect(x: 0, y: 200, width: 400, height: 300))
    }

    @Test @MainActor func strokesRoundTripAcrossDisplaySizes() {
        let original = TestArtwork.drawing()
        for width in [CGFloat(320), 430, 820] {
            let displayed = CanvasGeometry.drawing(original, scaledBy: width / 1024)
            let restored = CanvasGeometry.drawing(displayed, scaledBy: 1024 / width)
            #expect(abs(restored.bounds.minX - original.bounds.minX) < 0.01)
            #expect(abs(restored.bounds.minY - original.bounds.minY) < 0.01)
            #expect(abs(restored.bounds.width - original.bounds.width) < 0.01)
        }
    }

    @Test func stickerResizeUsesTheGestureBaseline() {
        #expect(CanvasGeometry.stickerSide(200, magnification: 1.5) == 300)
        #expect(CanvasGeometry.stickerSide(200, magnification: 0.01) == 40)
        #expect(CanvasGeometry.stickerSide(200, magnification: 10) == 1024)
        #expect(CanvasGeometry.clampedCenter(-10, limit: 1024) == 0)
        #expect(CanvasGeometry.clampedCenter(2000, limit: 1024) == 1024)
    }
}
