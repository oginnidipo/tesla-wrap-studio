import SwiftUI

struct PaintCanvas: View {
    @ObservedObject var session: EditorSession

    var body: some View {
        // GeometryReader is intentional: the PencilKit bridge and sticker gestures must
        // share the exact fitted template rectangle, including its letterbox offsets.
        GeometryReader { geometry in
            let rect = CanvasGeometry.fitRect(template: session.car.templateSize, in: geometry.size)
            let scale = rect.width / session.car.templateSize.width
            ZStack {
                TemplatePaintSurface(session: session, revision: session.drawingRevision,
                                     tool: session.pencilTool(displayScale: scale), fillHex: session.fillHex)
                ZStack {
                    ForEach(session.stickers) { sticker in
                        PlacedStickerView(session: session, sticker: sticker, scale: scale)
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .coordinateSpace(name: "wrapSurface")
                .position(x: rect.midX, y: rect.midY)

                // Same final layer as export: trim and windows stay clean, including stickers.
                Image(uiImage: UIImage(named: session.car.overlayImage) ?? UIImage()).resizable()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            .task(id: geometry.size) { session.migrateLegacyIfNeeded(in: geometry.size) }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.08)) }
    }
}
